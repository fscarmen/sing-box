#!/usr/bin/env python3
"""Privileged local operations. Only the panel group can reach the Unix socket.

No submitted command strings are executed. Jobs survive HTTP disconnects; their
stage log contains no script output, configs or credentials. Paths come only
from the root-owned settings file. Run with --settings /etc/sb-dashboard/manager.json.
"""
import argparse
import copy
import fcntl
import hashlib
import http.server
import ipaddress
import json
import os
import re
import secrets
import shlex
import shutil
import signal
import socket
import socketserver
import subprocess
import tarfile
import tempfile
import threading
import time
import urllib.request
from pathlib import Path

from panel import subscriptions, client_rules
from core_download import download as download_core

MAX_BODY = 2 * 1024 * 1024
MANAGED_API = '09_dashboard_api.json'
PROTOCOLS = dict(zip('bcdefghijklm', ('Reality', 'Hysteria2', 'TUIC', 'ShadowTLS', 'Shadowsocks',
                                  'Trojan', 'VMess WS', 'VLESS WS TLS', 'H2 Reality', 'gRPC Reality', 'AnyTLS', 'Naive')))


class OperationError(Exception):
    pass


def atomic(path, data, mode=0o600, gid=None):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.' + path.name + '.', dir=path.parent)
    tmp = Path(temporary)
    with os.fdopen(fd, 'w') as out:
        out.write(data)
        out.flush()
        os.fsync(out.fileno())
    os.chmod(tmp, mode)
    if gid is not None:
        os.chown(tmp, 0, gid)
    os.replace(tmp, path)


def jsonc(text):
    # Script metadata is stored in full-line // comments. Retain it when editing.
    return json.loads('\n'.join(line for line in text.splitlines() if not line.lstrip().startswith('//')))


def merge(a, b):
    for k, v in b.items():
        if k in a and isinstance(a[k], list) and isinstance(v, list):
            a[k].extend(copy.deepcopy(v))
        elif k in a and isinstance(a[k], dict) and isinstance(v, dict):
            merge(a[k], v)
        else:
            a[k] = copy.deepcopy(v)
    return a


class Manager:
    def __init__(self, settings):
        self.cfg = settings
        self.work = Path(settings.get('work_dir', '/etc/sing-box'))
        self.conf = self.work / 'conf'
        self.binary = self.work / 'sing-box'
        self.script = Path(settings['script'])
        self.data = Path(settings.get('data_dir', '/var/lib/sb-manager'))
        self.data.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.lock = threading.Lock()
        self.jobs = self.data / 'jobs'
        self.jobs.mkdir(exist_ok=True, mode=0o700)
        self.backups = self.data / 'backups'
        self.backups.mkdir(exist_ok=True, mode=0o700)
        # Interrupted jobs are never automatically repeated against a live host.
        for file in self.jobs.glob('*.json'):
            job = json.loads(file.read_text())
            if job['state'] in ('queued', 'running'):
                job.update(state='interrupted', error='任务服务曾重启；请先检查当前状态再重试')
                atomic(file, json.dumps(job, ensure_ascii=False))

    def run(self, args, timeout=60, capture=False, job=None, env=None):
        proc = subprocess.Popen([str(a) for a in args], stdin=subprocess.DEVNULL,
                                stdout=subprocess.PIPE if capture or job else subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL, start_new_session=True, env=env)
        reader = None
        if job:
            stages = {'dependencies': '检查并安装系统依赖', 'certificates': '准备节点证书',
                      'configuration': '生成协议配置', 'services': '安装并启动节点服务',
                      'firewall': '同步节点防火墙', 'subscriptions': '生成客户端配置与订阅'}
            def consume():
                for line in iter(proc.stdout.readline, b''):
                    value = line.decode(errors='replace').strip()
                    if value.startswith('SB_DASHBOARD_STAGE:'):
                        stage = value.split(':', 1)[1]
                        if stage in stages:
                            self.event(job, stages[stage])
                proc.stdout.close()
            reader = threading.Thread(target=consume, daemon=True)
            reader.start()
        try:
            if job:
                proc.wait(timeout=timeout)
                reader.join(timeout=5)
                out = b''
            else:
                out, _ = proc.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid, signal.SIGKILL)
            proc.wait()
            if reader:
                reader.join(timeout=5)
            raise OperationError('操作超时，已终止任务进程组，请检查当前状态')
        if proc.returncode:
            raise OperationError('步骤执行失败（退出码 %d）；敏感命令输出未写入日志' % proc.returncode)
        return (out or b'').decode(errors='replace')

    def service(self, action):
        return self.run(['systemctl', action, 'sing-box.service'])

    def owned(self):
        if not self.binary.is_file() or not self.conf.is_dir():
            raise OperationError('未发现本脚本的安装，请先安装；不接管其他部署器的配置')
        unit = self.run(['systemctl', 'show', '-p', 'ExecStart', '--value', 'sing-box.service'], capture=True)
        if str(self.binary) not in unit or str(self.conf) not in unit:
            raise OperationError('服务启动路径与本脚本不符，已拒绝修改')

    def files(self):
        return {p.name: p.read_text() for p in sorted(self.conf.glob('*.json')) if p.is_file() and not p.is_symlink()}

    @staticmethod
    def revision(files):
        return hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()

    def combined(self):
        result = {}
        for text in self.files().values():
            value = jsonc(text)
            if not isinstance(value, dict):
                raise ValueError('configuration must be an object')
            merge(result, value)
        return result

    def snapshot(self):
        if not self.conf.exists():
            return None
        name = time.strftime('%Y%m%d-%H%M%S') + '-' + secrets.token_hex(3)
        path = self.backups / name
        path.mkdir(mode=0o700)
        # Binaries, cache databases and logs are not configuration backups.
        for entry in ('conf', 'cert', 'subscribe', 'nginx.conf', 'list', 'language', 'firewall'):
            source = self.work / entry
            if source.is_symlink():
                raise OperationError('配置含符号链接，停止自动备份')
            if source.is_dir():
                shutil.copytree(source, path / entry, symlinks=True)
            elif source.is_file():
                shutil.copy2(source, path / entry)
        return name

    def backup_list(self):
        return [p.name for p in sorted(self.backups.iterdir(), reverse=True) if p.is_dir()]

    def export_monitor(self):
        atomic(self.cfg['monitor_config'], json.dumps(self.combined(), ensure_ascii=False), 0o640)
        if self.cfg.get('group'):
            import grp
            os.chown(self.cfg['monitor_config'], 0, grp.getgrnam(self.cfg['group']).gr_gid)

    def check(self, directory):
        self.run([self.binary, 'check', '-C', directory])

    def health(self):
        self.service('is-active')
        import grpc
        from panel import proto as pb
        channel = grpc.insecure_channel(self.cfg['api_address'])
        stream = None
        try:
            grpc.channel_ready_future(channel).result(timeout=10)
            subscribe = channel.unary_stream(pb.SUBSCRIBE, request_serializer=pb.SubscribeConnectionsRequest.SerializeToString,
                                             response_deserializer=pb.ConnectionEvents.FromString)
            stream = subscribe(pb.SubscribeConnectionsRequest(interval=1_000_000_000),
                               metadata=[('authorization', 'Bearer ' + self.cfg['api_secret'])], timeout=10)
            next(stream)
        except Exception:
            raise OperationError('sing-box 原生 API 认证或采集检查失败')
        finally:
            if stream is not None:
                stream.cancel()
            channel.close()

    def api_file(self):
        host, port = self.cfg['api_address'].rsplit(':', 1)
        if not ipaddress.ip_address(host).is_loopback:
            raise OperationError('管理 API 只允许监听回环地址')
        return json.dumps({'services': [{'type': 'api', 'tag': 'fork-dashboard-api', 'listen': host,
                           'listen_port': int(port), 'secret': self.cfg['api_secret'], 'dashboard': False}]}, indent=2) + '\n'

    def sync(self):
        self.run(['bash', self.script, '--dashboard-sync'], timeout=180)
        self.publish_subscriptions()
        # The shell's textual export is not a health check.
        self.export_monitor()

    def publish_subscriptions(self, origin=None):
        directory = self.cfg.get('subscription_dir')
        if not directory:
            return {}
        path = self.data / 'subscription.json'
        config = json.loads(path.read_text()) if path.exists() else {}
        if origin is not None:
            config['origin'] = subscriptions.validate_origin(origin)
        config.setdefault('origin', self.cfg['public_url'])
        config.setdefault('token', secrets.token_urlsafe(32))
        # Keep the token stable through exports, restarts, upgrades and restores.
        atomic(path, json.dumps(config))
        return subscriptions.publish(self.work, directory, config['origin'], config['token'], self.cfg.get('group'))

    def restore_files(self, name):
        if not re.fullmatch(r'[0-9]{8}-[0-9]{6}-[0-9a-f]{6}', str(name)):
            raise OperationError('无效的备份编号')
        path = self.backups / name
        if not (path / 'conf').is_dir():
            raise OperationError('备份不存在')
        self.check(path / 'conf')
        # Restore only files owned by the installer; retain the binary and ledger.
        for entry in ('conf', 'cert', 'subscribe', 'nginx.conf', 'list', 'language'):
            source, target = path / entry, self.work / entry
            if target.is_dir():
                shutil.rmtree(target)
            elif target.exists():
                target.unlink()
            if source.is_dir():
                shutil.copytree(source, target)
            elif source.is_file():
                shutil.copy2(source, target)
        self.check(self.conf)
        self.service('restart')
        # Retain the live firewall bookkeeping until sync removes the rules from
        # the configuration being replaced; restoring its old list would orphan them.
        self.sync()
        if (self.conf / MANAGED_API).exists():
            self.health()
        else:
            self.service('is-active')

    def status(self):
        installed = self.binary.is_file() and self.conf.is_dir()
        state = 'not-installed'
        version = ''
        problem = ''
        if installed:
            try:
                self.service('is-active')
                state = 'active'
            except OperationError:
                state = 'inactive'
            try:
                version = self.run([self.binary, 'version'], capture=True).splitlines()[0]
            except (OperationError, OSError, IndexError):
                problem = '无法读取内核版本；仍可编辑配置或恢复备份'
        job_list = [json.loads(p.read_text()) for p in sorted(self.jobs.glob('*.json'), reverse=True)[:20]]
        try:
            config = self.combined() if installed else {}
        except (OSError, ValueError, TypeError):
            config = {}
            problem = '当前配置无法解析，请加载配置修复或恢复历史备份'
        return {'installed': installed, 'service': state, 'version': version, 'protocols': PROTOCOLS,
                'inbounds': [{'tag': i.get('tag'), 'type': i.get('type'), 'port': i.get('listen_port')} for i in config.get('inbounds', [])],
                'jobs': job_list, 'backups': self.backup_list(), 'server': self.cfg.get('server', ''), 'configuration_error': problem}

    def config(self):
        self.owned()
        files = self.files()
        return {'revision': self.revision(files), 'files': {k: v for k, v in files.items() if k != MANAGED_API}}

    def request(self, op, payload):
        if op == 'rules':
            return self.rules_view()
        if op == 'status':
            return self.status()
        if op == 'config':
            return self.config()
        if op == 'subscriptions':
            self.owned()
            if self.cfg.get('subscription_dir') and subscriptions.read_manifest(self.cfg['subscription_dir']):
                return subscriptions.bundle(self.cfg['subscription_dir'])
            allowed = ('v2rayn', 'clash', 'clash2', 'sing-box', 'shadowrocket', 'throne', 'proxies')
            manifest = subscriptions.read_manifest(self.cfg['subscription_dir']) if self.cfg.get('subscription_dir') else {}
            directory = Path(self.cfg['subscription_dir']) / 'current' if manifest else self.work / 'subscribe'
            return {'files': {n: (directory / n).read_text() for n in allowed if (directory / n).is_file()},
                    'origin': manifest.get('origin', self.cfg.get('public_url', '')), 'links': subscriptions.links(manifest)}
        if op not in ('install', 'apply', 'adopt', 'start', 'stop', 'restart', 'backup', 'restore', 'export', 'upgrade', 'subscription', 'rules-save'):
            raise OperationError('未知操作')
        if not self.lock.acquire(blocking=False):
            raise OperationError('已有任务执行中，请等待完成')
        job = {'id': str(time.time_ns()), 'operation': op, 'state': 'queued', 'created': int(time.time()),
               'engine': getattr(self, 'engine', 'singbox'),
               'actor': str(payload.pop('_actor', 'admin'))[:64], 'events': [], 'error': ''}
        self.save_job(job)
        thread = threading.Thread(target=self.execute, args=(job, payload), daemon=False)
        thread.start()
        return {'job': job}

    def save_job(self, job):
        atomic(self.jobs / (job['id'] + '.json'), json.dumps(job, ensure_ascii=False))

    def event(self, job, message):
        job['events'].append({'at': int(time.time()), 'message': message})
        self.save_job(job)

    def execute(self, job, payload):
        backup = None
        op = job['operation']
        job['state'] = 'running'
        self.save_job(job)
        try:
            # Also serialize with other manager instances using this data directory.
            with (self.data / 'operation.lock').open('w') as lockfile:
                fcntl.flock(lockfile, fcntl.LOCK_EX | fcntl.LOCK_NB)
                if op == 'rules-save':
                    self.save_rules(job, payload)
                elif op == 'install':
                    self.install(job, payload)
                else:
                    self.owned()
                    if op not in ('backup', 'start', 'stop', 'restart', 'subscription'):
                        backup = self.snapshot()
                        job['backup'] = backup
                        self.event(job, '已备份当前配置')
                    if op == 'apply':
                        self.apply(job, payload)
                    elif op == 'adopt':
                        with tempfile.TemporaryDirectory(prefix='sb-adopt-', dir=self.work) as tmp:
                            for name, text in self.files().items():
                                atomic(Path(tmp) / name, text)
                            atomic(Path(tmp) / MANAGED_API, self.api_file())
                            self.check(tmp)
                        job['modified'] = True
                        atomic(self.conf / MANAGED_API, self.api_file())
                        self.check(self.conf)
                        self.service('restart')
                        self.export_monitor()
                        self.publish_subscriptions()
                        self.health()
                    elif op == 'subscription':
                        try:
                            origin = subscriptions.validate_origin(payload.get('origin', ''))
                        except ValueError as exc:
                            raise OperationError(str(exc))
                        self.publish_subscriptions(origin)
                    elif op in ('start', 'stop', 'restart'):
                        self.service(op)
                        if op != 'stop':
                            self.health()
                    elif op == 'backup':
                        job['backup'] = self.snapshot()
                    elif op == 'restore':
                        job['modified'] = True
                        self.restore_files(payload.get('backup', ''))
                    elif op == 'export':
                        job['modified'] = True
                        self.sync()
                    elif op == 'upgrade':
                        self.upgrade(job, payload)
                self.event(job, '操作完成')
                job['state'] = 'succeeded'
        except Exception as exc:
            job['state'] = 'failed'
            job['error'] = str(exc) if isinstance(exc, OperationError) else '内部错误：' + type(exc).__name__
            if backup and job.get('modified'):
                try:
                    self.event(job, '操作失败，正在恢复配置')
                    self.restore_files(backup)
                    self.event(job, '配置已恢复并通过健康检查')
                except Exception:
                    self.event(job, '自动恢复未通过，请在备份页面恢复；面板仍可访问')
        finally:
            self.save_job(job)
            self.lock.release()

    def rules_view(self):
        directory = self.cfg.get('subscription_dir')
        if not directory:
            raise OperationError('请先更新面板安装器，启用独立订阅网关')
        policy = client_rules.load(directory)
        clients = []
        for engine, folder in (('singbox', Path(directory)), ('xray', Path(directory) / 'xray')):
            current = (folder / 'current').resolve()
            try:
                manifest = json.loads((current / 'manifest.json').read_text())
            except (OSError, ValueError):
                manifest = {}
            for name in ('clash', 'clash2', 'sing-box', 'shadowrocket.conf', 'rules-v2rayn.json'):
                if name not in subscriptions.available_formats(manifest):
                    continue
                item = {'engine': engine, 'format': name, 'url': subscriptions.links(manifest)[name]}
                try:
                    raw = (current / name).read_text() if name in subscriptions.NODE_FORMATS else client_rules.render(name, '', client_rules.EMPTY)
                    rendered = subscriptions.content(current, manifest, name, policy)
                    item.update(base=client_rules.rules_only(name, raw), effective=client_rules.rules_only(name, rendered))
                except (ValueError, TypeError, KeyError, OSError, client_rules.yaml.YAMLError):
                    item['error'] = '此格式的基础配置无法解析，请检查或重新生成订阅'
                clients.append(item)
        return {'policy': policy, 'revision': client_rules.revision(policy), 'clients': clients,
                'capabilities': client_rules.CAPABILITIES,
                'scope': '展示服务器当前下发的配置，无法读取手机或电脑上的本地覆写。自定义规则优先于基础规则，列表从上到下匹配。'}

    def save_rules(self, job, payload):
        directory = self.cfg.get('subscription_dir')
        if not directory:
            raise OperationError('未配置独立订阅网关')
        previous = client_rules.load(directory)
        if payload.get('revision') != client_rules.revision(previous):
            raise OperationError('规则已被其他操作修改，请刷新后重试')
        try:
            policy = client_rules.validate(payload.get('policy'))
            # Check both engines before the one atomic global policy swap.
            for folder in (Path(directory), Path(directory) / 'xray'):
                current = (folder / 'current').resolve()
                try:
                    manifest = json.loads((current / 'manifest.json').read_text())
                except FileNotFoundError:
                    continue
                for name in subscriptions.available_formats(manifest):
                    subscriptions.content(current, manifest, name, policy)
        except (ValueError, TypeError, KeyError, OSError, client_rules.yaml.YAMLError):
            # Parser exceptions can include lines with proxy credentials.
            raise OperationError('规则或客户端基础配置校验失败；请检查规则与订阅预览，原规则保持不变')
        backup = self.data / 'client-rule-backups' / (job['id'] + '.json')
        atomic(backup, json.dumps(previous, ensure_ascii=False))
        target = Path(directory)
        target.mkdir(parents=True, exist_ok=True, mode=0o750)
        target.chmod(0o750)
        gid = None
        if self.cfg.get('group'):
            import grp
            gid = grp.getgrnam(self.cfg['group']).gr_gid
            os.chown(target, 0, gid)
        atomic(target / client_rules.RULE_FILE, json.dumps(policy, ensure_ascii=False), 0o640, gid=gid)
        job['rules_revision'] = client_rules.revision(policy)
        self.event(job, '统一规则已发布；客户端更新对应配置后生效')

    def install(self, job, payload):
        if (self.binary.exists() or self.conf.exists() or Path('/etc/sing-box/config.json').exists()
                or Path('/etc/systemd/system/sing-box.service').exists()
                or Path('/lib/systemd/system/sing-box.service').exists()):
            raise OperationError('服务器已有 sing-box 配置，请使用接管或配置编辑')
        options = install_options(payload, self.cfg.get('server', ''))
        for offset, code in enumerate(options['CHOOSE_PROTOCOLS']):
            port = options['START_PORT'] + offset
            if port in (self.cfg.get('panel_port'), int(self.cfg['api_address'].rsplit(':', 1)[1]),
                        8308 if self.cfg.get('subscription_dir') else None, 8311):
                raise OperationError('节点端口与面板或内部服务冲突')
            for kind in ((socket.SOCK_DGRAM,) if code in 'cd' else (socket.SOCK_STREAM, socket.SOCK_DGRAM) if code == 'm' else (socket.SOCK_STREAM,)):
                try:
                    with socket.socket(socket.AF_INET, kind) as sock:
                        sock.bind(('0.0.0.0', port))
                except OSError:
                    raise OperationError('节点端口已被其他服务占用：%d' % port)
        self.event(job, '开始安装选定协议；首次安装可能需要数分钟')
        with tempfile.TemporaryDirectory(prefix='sb-install-', dir=self.data) as tmp:
            path = Path(tmp) / 'install.conf'
            atomic(path, '\n'.join(k + '=' + shlex.quote(str(v)) for k, v in options.items()) + '\n')
            core_version = self.cfg.get('install_version', '1.14.3')
            core_binary = Path(tmp) / 'sing-box'
            self.event(job, '下载默认内核并校验官方 SHA256')
            self.download_binary(core_version, core_binary)
            environment = dict(os.environ, SB_DASHBOARD_CORE_VERSION=core_version, SB_DASHBOARD_CORE_BINARY=str(core_binary), SB_DASHBOARD_PROGRESS='1')
            self.run(['bash', self.script, '-f', path], timeout=1200, job=job, env=environment)
        self.owned()
        self.event(job, '配置监控 API 并验证服务')
        atomic(self.conf / MANAGED_API, self.api_file())
        self.check(self.conf)
        self.service('restart')
        self.export_monitor()
        self.publish_subscriptions()
        self.health()
        settings_path = self.cfg.get('settings_path')
        if settings_path and Path(settings_path).exists():
            settings = json.loads(Path(settings_path).read_text())
            if settings.get('singbox', {}).get('enabled') is False:
                settings['singbox']['enabled'] = True
                atomic(settings_path, json.dumps(settings), 0o640)
                if self.cfg.get('group'):
                    import grp
                    os.chown(settings_path, 0, grp.getgrnam(self.cfg['group']).gr_gid)
                self.run(['systemctl', 'try-restart', 'sb-dashboard.service'])

    def apply(self, job, payload):
        current = self.files()
        if payload.get('revision') != self.revision(current):
            raise OperationError('配置已被其他操作修改，请重新加载后编辑')
        files = payload.get('files')
        if not isinstance(files, dict) or not files:
            raise OperationError('配置文件不能为空')
        if len(files) > 64:
            raise OperationError('配置文件过多')
        with tempfile.TemporaryDirectory(prefix='sb-candidate-', dir=self.work) as tmp:
            for name, text in files.items():
                if not re.fullmatch(r'[0-9]{2}_[A-Za-z0-9_.-]+\.json', name) or name == MANAGED_API:
                    raise OperationError('无效或受保护的配置文件名')
                if not isinstance(text, str):
                    raise OperationError('配置内容必须是文本')
                try:
                    value = jsonc(text)
                except ValueError:
                    raise OperationError('配置 JSON 格式错误：' + name)
                if not isinstance(value, dict):
                    raise OperationError('配置顶层必须是对象')
                for inbound in value.get('inbounds', []):
                    port = inbound.get('listen_port')
                    if type(port) is not int or not 1 <= port <= 65535:
                        raise OperationError('入站监听端口无效')
                    if port in (self.cfg.get('panel_port'), int(self.cfg['api_address'].rsplit(':', 1)[1]),
                                8308 if self.cfg.get('subscription_dir') else None, 8311):
                        raise OperationError('节点端口与面板或内部服务冲突')
                # The upstream export parser expects one key per line without a
                # space after ':'. Keep // metadata while normalizing JSON layout.
                comments = '\n'.join(line for line in text.splitlines() if line.lstrip().startswith('//'))
                normalized = (comments + '\n' if comments else '') + json.dumps(value, indent=4, ensure_ascii=False, separators=(',', ':')) + '\n'
                atomic(Path(tmp) / name, normalized)
            atomic(Path(tmp) / MANAGED_API, self.api_file())
            self.check(tmp)
            self.event(job, '候选配置检查通过，正在应用')
            job['modified'] = True
            for path in self.conf.glob('*.json'):
                if path.name not in files and path.name != MANAGED_API:
                    path.unlink()
            for path in Path(tmp).glob('*.json'):
                atomic(self.conf / path.name, path.read_text())
        self.run(['systemctl', 'reload-or-restart', 'sing-box.service'])
        self.sync()
        self.health()

    def upgrade(self, job, payload):
        version = str(payload.get('version', '')).lstrip('v')
        if not re.fullmatch(r'1\.[0-9]+\.[0-9]+(?:-(?:alpha|beta|rc)\.[0-9]+)?', version):
            raise OperationError('请输入明确的 sing-box 版本，例如 1.14.3')
        self.event(job, '下载指定版本并校验官方 SHA256')
        candidate = self.work / 'sing-box.dashboard-new'
        self.download_binary(version, candidate)
        previous = self.data / ('sing-box-before-' + job['id'])
        try:
            with tempfile.TemporaryDirectory(prefix='sb-upgrade-', dir=self.work) as tmp:
                for name, text in self.files().items():
                    atomic(Path(tmp) / name, text)
                atomic(Path(tmp) / MANAGED_API, self.api_file())
                self.run([candidate, 'check', '-C', tmp])
            shutil.copy2(self.binary, previous)
            os.replace(candidate, self.binary)
            job['modified'] = True
            atomic(self.conf / MANAGED_API, self.api_file())
            self.service('restart')
            self.health()
            self.export_monitor()
        except Exception:
            if previous.exists():
                shutil.copy2(previous, candidate)
                os.replace(candidate, self.binary)
                self.service('restart')
            raise

    def download_binary(self, version, destination):
        arch = {'x86_64': 'amd64', 'aarch64': 'arm64'}.get(os.uname().machine)
        try:
            download_core(version, arch, destination)
        except (OSError, ValueError) as exc:
            raise OperationError('无法获取经过校验的内核，请检查 GitHub 访问后重试：' + str(exc))


def install_options(payload, server):
    chosen = payload.get('protocols', ['b', 'c'])
    if not isinstance(chosen, list) or not chosen or any(p not in PROTOCOLS for p in chosen):
        raise OperationError('请选择有效协议')
    chosen = list(dict.fromkeys(chosen))
    port = payload.get('start_port', 443)
    if type(port) is not int or not 100 <= port <= 65520 - len(chosen):
        raise OperationError('起始端口范围无效')
    address = str(payload.get('server') or server).strip()
    if not address or len(address) > 253 or not re.fullmatch(r'[A-Za-z0-9.:-]+', address):
        raise OperationError('请输入有效服务器 IP 或域名')
    name = str(payload.get('name') or 'sing-box')
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,40}', name):
        raise OperationError('节点名使用 1–40 位字母、数字、下划线或连字符')
    opts = {'LANGUAGE': 'C', 'CHOOSE_PROTOCOLS': ''.join(chosen), 'START_PORT': port,
            'SERVER_IP': address, 'NODE_NAME_CONFIRM': name, 'SUBSCRIBE': 'false', 'ARGO': 'false'}
    if 'h' in chosen or 'i' in chosen:
        for code, field in [('h', 'VMESS_HOST_DOMAIN'), ('i', 'VLESS_HOST_DOMAIN')]:
            if code in chosen:
                host = str(payload.get(field.lower(), ''))
                if not re.fullmatch(r'[A-Za-z0-9.-]+\.[A-Za-z0-9.-]+', host):
                    raise OperationError('WebSocket 协议需要填写对应域名')
                opts[field] = host
        opts['CDN'] = 'skk.moe'
    return opts


class UnixServer(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True


def serve(settings):
    manager = Manager(settings)
    from xray_manager import XrayManager
    xray_manager = XrayManager(settings)
    xray_manager.lock = manager.lock
    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_POST(self):
            status = 200
            try:
                size = int(self.headers.get('Content-Length', 0))
                if size <= 0 or size > MAX_BODY:
                    raise OperationError('请求大小无效')
                body = json.loads(self.rfile.read(size))
                payload = body.get('payload', {})
                if not isinstance(payload, dict):
                    raise OperationError('参数必须是对象')
                engine = payload.pop('engine', 'singbox')
                if engine not in ('singbox', 'xray'):
                    raise OperationError('未知内核')
                if body['operation'] in ('rules', 'rules-save'):
                    engine = 'singbox'  # Shared policy, one lock, independent of installed cores.
                result = (xray_manager if engine == 'xray' else manager).request(body['operation'], payload)
            except (OperationError, ValueError, KeyError) as exc:
                status, result = 400, {'error': str(exc) if isinstance(exc, OperationError) else '无效请求'}
            except Exception:
                status, result = 500, {'error': '任务服务内部错误'}
            raw = json.dumps(result, ensure_ascii=False).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)
    sock = Path(settings['socket'])
    sock.parent.mkdir(parents=True, exist_ok=True)
    import grp
    group = grp.getgrnam(settings['group']).gr_gid
    os.chown(sock.parent, 0, group)
    sock.parent.chmod(0o750)
    if sock.exists():
        sock.unlink()
    with UnixServer(str(sock), Handler) as server:
        os.chown(sock, 0, group)
        sock.chmod(0o660)
        server.serve_forever()


if __name__ == '__main__':
    # Xray imports the shared job primitives from manager; keep one module identity.
    import sys
    sys.modules.setdefault('manager', sys.modules[__name__])
    parser = argparse.ArgumentParser()
    parser.add_argument('--settings', default='/etc/sb-dashboard/manager.json')
    args = parser.parse_args()
    config = json.loads(Path(args.settings).read_text())
    serve(config)
