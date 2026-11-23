"""Managed Xray Reality installation, separate from arbitrary existing Xray setups."""
import base64
import fcntl
import grp
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import pwd
import re
import secrets
import shutil
import socket
import subprocess
import tempfile
import time
from urllib.parse import urlencode, quote
import uuid

from manager import Manager, OperationError, atomic
from panel import subscriptions
from xray_download import DEFAULT_VERSION, download

API = '127.0.0.1:8311'


def domain(value):
    value = str(value).strip()
    if len(value) > 253 or not re.fullmatch(r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}', value):
        raise OperationError('Reality SNI 必须是有效域名')
    return value


def address(value):
    value = str(value).strip()
    try:
        ipaddress.ip_address(value)
    except ValueError:
        domain(value)
    return value


def stats_config():
    return {'api': {'tag': 'dashboard-stats', 'listen': API, 'services': ['StatsService']}, 'stats': {},
            'policy': {'system': {name: True for name in ('statsInboundUplink', 'statsInboundDownlink', 'statsOutboundUplink', 'statsOutboundDownlink')},
                       'levels': {'0': {name: True for name in ('statsUserUplink', 'statsUserDownlink', 'statsUserOnline')}}}}


class XrayManager(Manager):
    engine = 'xray'

    def __init__(self, settings):
        super().__init__(settings)
        self.work = Path(settings.get('xray_work_dir', '/usr/local/etc/xray'))
        self.binary = Path(settings.get('xray_binary', '/usr/local/bin/xray'))
        self.config_path = self.work / 'config.json'
        self.unit = Path(settings.get('xray_unit', '/etc/systemd/system/xray.service'))
        self.marker = self.data / 'xray-managed.json'
        self.backups = self.data / 'xray-backups'
        self.backups.mkdir(exist_ok=True, mode=0o700)
        self.vendor = Path(__file__).parent / 'vendor/xray-install'
        self.monitor = Path(settings.get('xray_monitor_config', '/var/lib/sb-dashboard/xray-runtime.json'))

    def service(self, action):
        return self.run(['systemctl', action, 'xray.service'])

    def installed(self):
        return self.marker.is_file() and self.binary.is_file() and self.config_path.is_file()

    def owned(self):
        if not self.installed():
            raise OperationError('未发现本项目部署的 Xray；已有外部实例请使用监控接入说明，不能直接接管')
        unit = self.run(['systemctl', 'show', '-p', 'ExecStart', '--value', 'xray.service'], capture=True)
        if str(self.binary) not in unit or str(self.config_path) not in unit:
            raise OperationError('Xray 服务启动路径不属于本项目，已拒绝修改')

    def files(self):
        return {'config.json': self.config_path.read_text()}

    def document(self):
        return json.loads(self.config_path.read_text())

    def status(self):
        installed = self.installed()
        state, version, problem, inbounds = 'not-installed', '', '', []
        if installed:
            try:
                self.service('is-active'); state = 'active'
            except OperationError:
                state = 'inactive'
            try:
                version = self.run([self.binary, 'version'], capture=True).splitlines()[0]
                inbounds = [{'tag': i.get('tag'), 'type': 'VLESS Reality Vision', 'port': i.get('port')} for i in self.document().get('inbounds', [])]
            except (OSError, ValueError, OperationError, IndexError):
                problem = 'Xray 配置或内核异常；可加载配置修复或恢复备份'
        elif any(p.exists() for p in (self.binary, self.work, self.unit)):
            problem = '检测到已有或未完成的外部 Xray 安装；为保留原配置，安装器不会覆盖。已有实例可按文档接入监控。'
        jobs = [json.loads(p.read_text()) for p in sorted(self.jobs.glob('*.json'), reverse=True)[:20]]
        server = json.loads(self.marker.read_text()).get('server', self.cfg.get('server', '')) if self.marker.exists() else self.cfg.get('server', '')
        return {'engine': 'xray', 'installed': installed, 'service': state, 'version': version,
                'protocols': {'reality': 'VLESS + Reality + Vision'}, 'inbounds': inbounds, 'jobs': jobs,
                'backups': self.backup_list(), 'server': server, 'configuration_error': problem}

    def config(self):
        self.owned()
        return {'revision': self.config_revision(), 'files': self.files(),
                'server': json.loads(self.marker.read_text())['server']}

    def config_revision(self):
        return self.revision({**self.files(), 'server': json.loads(self.marker.read_text())['server']})

    def request(self, op, payload):
        if op == 'subscriptions':
            self.owned()
            return subscriptions.bundle(self.subscription_dir(), self.cfg['subscription_dir'])
        if op == 'adopt':
            raise OperationError('Xray 仅管理本项目创建的实例；外部实例支持单独监控')
        return super().request(op, payload)

    def subscription_dir(self):
        return Path(self.cfg['subscription_dir']) / 'xray'

    def snapshot(self):
        name = time.strftime('%Y%m%d-%H%M%S') + '-' + secrets.token_hex(3)
        folder = self.backups / name
        folder.mkdir(mode=0o700)
        for source in (self.config_path, self.marker):
            shutil.copy2(source, folder / source.name)
        return name

    def restore_files(self, name):
        if not re.fullmatch(r'[0-9]{8}-[0-9]{6}-[0-9a-f]{6}', str(name)):
            raise OperationError('无效的备份编号')
        source = self.backups / name
        if not (source / 'config.json').is_file() or not (source / self.marker.name).is_file():
            raise OperationError('Xray 备份不存在')
        self.check(source / 'config.json')
        self.save_config(json.loads((source / 'config.json').read_text()))
        atomic(self.marker, (source / self.marker.name).read_text())
        self.service('restart')
        self.health()
        self.sync()

    def check(self, config, binary=None):
        self.run([binary or self.binary, 'run', '-test', '-config', config])

    def health(self):
        from panel.xray import Client
        self.service('is-active')
        client = Client({'id': 'managed', 'service': 'xray.service', 'api_address': API})
        try:
            deadline = time.monotonic() + 12
            while True:
                try:
                    client.counters(); client.runtime(); return
                except Exception:
                    if time.monotonic() >= deadline:
                        raise OperationError('Xray StatsService 未就绪，服务健康检查失败')
                    time.sleep(.3)
        finally:
            client.channel.close()

    def save_config(self, document):
        atomic(self.config_path, json.dumps(document, indent=2) + '\n', 0o640)
        os.chown(self.config_path, 0, grp.getgrnam('xray').gr_gid)

    def export_monitor(self):
        atomic(self.monitor, json.dumps(self.document()), 0o640)
        if self.cfg.get('group'):
            os.chown(self.monitor, 0, grp.getgrnam(self.cfg['group']).gr_gid)

    def sync(self):
        self.firewall()
        self.export_monitor()
        self.publish_subscriptions()

    def firewall(self, remove=False):
        args = ['python3', Path(__file__).parent / 'xray_firewall.py', '--config', self.config_path,
                '--state', self.data / 'xray-firewall.json']
        self.run(args + (['--remove'] if remove else []))

    def register_monitor(self):
        path = Path(self.cfg.get('settings_path', '/etc/sb-dashboard/settings.json'))
        settings = json.loads(path.read_text())
        xray = settings.setdefault('xray', {})
        instances = xray.setdefault('instances', [])
        # Existing monitoring profiles remain independent of the managed installation.
        instances[:] = [i for i in instances if i.get('id') != 'managed']
        instances.append({'id': 'managed', 'label': '本项目 Xray', 'service': 'xray.service',
                          'api_address': API, 'config_path': str(self.monitor)})
        atomic(path, json.dumps(settings, ensure_ascii=False), 0o640)
        if self.cfg.get('group'):
            os.chown(path, 0, grp.getgrnam(self.cfg['group']).gr_gid)
        self.run(['systemctl', 'try-restart', 'sb-dashboard.service'])

    def validate(self, doc):
        if not isinstance(doc, dict) or not isinstance(doc.get('inbounds'), list) or not doc['inbounds']:
            raise OperationError('至少保留一个 VLESS Reality 入站')
        seen, emails = set(), set()
        for node in doc['inbounds']:
            stream = node.get('streamSettings', {})
            if node.get('protocol') != 'vless' or stream.get('security') != 'reality' or stream.get('network', 'raw') not in ('raw', 'tcp'):
                raise OperationError('当前部署和订阅支持 VLESS Reality RAW/TCP；其他协议请另行配置监控')
            if node.get('listen') not in ('0.0.0.0', '::'):
                raise OperationError('受管节点监听地址必须为 0.0.0.0 或 ::')
            port = node.get('port')
            if type(port) is not int or not 100 <= port <= 65535 or port in seen:
                raise OperationError('节点端口无效或重复')
            seen.add(port)
            if port in (self.cfg.get('panel_port'), 8306, 8308, 8311):
                raise OperationError('节点端口与面板或内部服务冲突')
            if not re.fullmatch(r'[A-Za-z0-9_-]{1,40}', str(node.get('tag', ''))):
                raise OperationError('入站标签使用 1–40 位字母、数字、下划线或连字符')
            reality = stream.get('realitySettings', {})
            names = reality.get('serverNames')
            if not isinstance(names, list) or len(names) != 1:
                raise OperationError('每个入站需配置一个 Reality SNI')
            domain(names[0])
            if reality.get('target') != names[0] + ':443':
                raise OperationError('Reality target 必须与 SNI 相同并使用 443 端口')
            if not re.fullmatch(r'[A-Za-z0-9_-]{43}', str(reality.get('privateKey', ''))):
                raise OperationError('Reality 私钥格式无效')
            ids = reality.get('shortIds')
            if not isinstance(ids, list) or not ids or any(not isinstance(i, str) or not re.fullmatch(r'(?:[0-9a-f]{2}){1,8}', i) for i in ids):
                raise OperationError('Reality shortIds 需为 2–16 位偶数长度十六进制值')
            clients = node.get('settings', {}).get('clients')
            if not isinstance(clients, list) or not clients or node['settings'].get('decryption') != 'none':
                raise OperationError('VLESS 需保留用户且 decryption 为 none')
            for client in clients:
                try:
                    uuid.UUID(client['id'])
                except (KeyError, ValueError, TypeError, AttributeError):
                    raise OperationError('VLESS 用户 UUID 无效')
                email = client.get('email', '')
                if not isinstance(email, str) or not re.fullmatch(r'[A-Za-z0-9_.@+-]{1,100}', email) or email in emails:
                    raise OperationError('用户 email 必须有效且全局唯一，用于统计')
                emails.add(email)
                if client.get('flow') != 'xtls-rprx-vision' or client.get('level', 0) != 0:
                    raise OperationError('受管用户需使用 Vision 和 level 0')
        if len(seen) > 32 or len(emails) > 256:
            raise OperationError('受管入站或用户数量过多')
        doc.update(stats_config())
        return doc

    def check_ports(self, doc, old=None):
        previous = {i['port'] for i in (old or {}).get('inbounds', [])}
        for port in {i['port'] for i in doc['inbounds']} - previous:
            self.free_port(port)

    @staticmethod
    def free_port(port):
        try:
            with socket.socket() as sock:
                sock.bind(('0.0.0.0', port))
        except OSError:
            raise OperationError('TCP 端口已被占用：%d' % port)

    def keypair(self, binary, private=None):
        if private:
            # Derive through stdin; a Reality private key must not appear in ps/argv.
            try:
                raw = base64.urlsafe_b64decode(private + '=')
                if len(raw) != 32:
                    raise ValueError
                der = bytes.fromhex('302e020100300506032b656e04220420') + raw
                result = subprocess.run(['openssl', 'pkey', '-inform', 'DER', '-pubout', '-outform', 'DER'],
                    input=der, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=10, check=True)
                prefix = bytes.fromhex('302a300506032b656e032100')
                if not result.stdout.startswith(prefix) or len(result.stdout) != len(prefix) + 32:
                    raise ValueError
                return private, base64.urlsafe_b64encode(result.stdout[-32:]).decode().rstrip('=')
            except (ValueError, subprocess.SubprocessError, OSError):
                raise OperationError('无法派生 Reality 公钥')
        output = self.run([binary, 'x25519'], capture=True)
        private_key = re.search(r'Private(?:Key| key):\s*([A-Za-z0-9_-]{43})', output, re.I)
        public_key = re.search(r'(?:Password \(PublicKey\)|PublicKey|Public key|Password):\s*([A-Za-z0-9_-]{43})', output, re.I)
        if not private_key or not public_key:
            raise OperationError('无法生成 Reality 密钥对')
        return private_key.group(1), public_key.group(1)

    def download(self, version, destination):
        try:
            return download(version, {'x86_64': 'amd64', 'aarch64': 'arm64'}.get(os.uname().machine), destination)
        except (ValueError, OSError) as exc:
            raise OperationError('无法获取校验后的官方 Xray：' + str(exc))

    def unit_text(self):
        firewall = Path(__file__).parent / 'xray_firewall.py'
        return '\n'.join(['[Unit]', 'Description=Dashboard managed Xray Reality server',
            'After=network-online.target', 'Wants=network-online.target', '[Service]', 'User=xray', 'Group=xray',
            'UMask=0077', 'NoNewPrivileges=true', 'CapabilityBoundingSet=CAP_NET_BIND_SERVICE',
            'AmbientCapabilities=CAP_NET_BIND_SERVICE', 'ProtectSystem=strict', 'ProtectHome=true', 'PrivateTmp=true',
            'ReadWritePaths=' + str(self.data),
            'ExecStartPre=+/usr/bin/python3 %s --config %s --state %s' % (firewall, self.config_path, self.data / 'xray-firewall.json'),
            'ExecStart=%s run -config %s' % (self.binary, self.config_path), 'Restart=on-failure',
            'RestartSec=3', 'LimitNOFILE=1048576', '[Install]', 'WantedBy=multi-user.target', ''])

    def install(self, job, payload):
        if any(p.exists() for p in (self.binary, self.work, self.unit, self.marker, Path('/lib/systemd/system/xray.service'), Path('/etc/systemd/system/xray.service.d'))):
            raise OperationError('服务器已有 Xray 文件或服务，已拒绝覆盖；外部安装请单独接入监控')
        server = address(payload.get('server') or self.cfg.get('server', ''))
        port = payload.get('start_port', 443)
        if type(port) is not int:
            raise OperationError('节点端口无效')
        name = str(payload.get('name') or 'xray')
        sni = domain(payload.get('sni') or 'www.apple.com')
        if not re.fullmatch(r'[A-Za-z0-9_-]{1,40}', name):
            raise OperationError('节点名使用 1–40 位字母、数字、下划线或连字符')
        if not 100 <= port <= 65535 or port in (self.cfg.get('panel_port'), 8306, 8308, 8311):
            raise OperationError('节点端口无效或与面板、内部服务冲突')
        self.free_port(port)
        self.free_port(8311)
        settings_path = Path(self.cfg.get('settings_path', '/etc/sb-dashboard/settings.json'))
        previous_settings = settings_path.read_text()
        with tempfile.TemporaryDirectory(prefix='xray-install-', dir=self.data) as tmp:
            archive = Path(tmp) / 'release.zip'
            self.event(job, '下载固定版本 Xray 并校验官方 SHA256')
            binary = self.download(self.cfg.get('xray_install_version', DEFAULT_VERSION), archive)
            private, _ = self.keypair(binary)
            doc = self.validate({'log': {'loglevel': 'warning', 'access': 'none'},
                'inbounds': [{'tag': name, 'listen': '::', 'port': port, 'protocol': 'vless',
                    'settings': {'decryption': 'none', 'clients': [{'id': str(uuid.uuid4()), 'email': 'user@' + name, 'level': 0, 'flow': 'xtls-rprx-vision'}]},
                    'streamSettings': {'network': 'raw', 'security': 'reality', 'realitySettings': {
                        'show': False, 'target': sni + ':443', 'serverNames': [sni], 'privateKey': private, 'shortIds': [secrets.token_hex(8)]}}}],
                'outbounds': [{'tag': 'direct', 'protocol': 'freedom'}, {'tag': 'block', 'protocol': 'blackhole'}]})
            self.check_ports(doc)
            self.free_port(8311)
            candidate = Path(tmp) / 'config.json'
            atomic(candidate, json.dumps(doc))
            self.check(candidate, binary)
            metadata = json.loads((self.vendor / 'SOURCE.json').read_text())
            if hashlib.sha256((self.vendor / 'install-release.sh').read_bytes()).hexdigest() != metadata['sha256']:
                raise OperationError('官方安装脚本与固定来源校验不匹配')
            self.event(job, '准备独立 Xray 账户、配置与服务')
            self.run(['systemd-sysusers', self.vendor / 'xray-user.conf'])
            account = pwd.getpwnam('xray')
            if account.pw_uid == 0 or account.pw_gid == 0:
                raise OperationError('Xray 账户不能为 root')
            # The manager runs with umask 077; explicitly grant directory traversal
            # to the non-root service instead of relying on mkdir's masked mode.
            missing = []
            parent = self.work.parent
            while not parent.exists():
                missing.append(parent)
                parent = parent.parent
            for parent in reversed(missing):
                parent.mkdir()
                parent.chmod(0o755)
            self.work.mkdir(mode=0o750)
            self.work.chmod(0o750)
            os.chown(self.work, 0, grp.getgrnam('xray').gr_gid)
            try:
                self.save_config(doc)
                atomic(self.marker, json.dumps({'server': server, 'created': int(time.time())}))
                atomic(self.unit, self.unit_text(), 0o644)
                self.run(['systemctl', 'daemon-reload'])
                self.event(job, '使用项目内固定的官方脚本安装本地校验包')
                env = dict(os.environ, JSON_PATH=str(self.work), JSONS_PATH='', DAT_PATH='/usr/local/share/xray', TERM='dumb')
                self.run(['bash', self.vendor / 'install-release.sh', 'install', '--local', archive,
                          '--without-geodata', '--without-logfiles', '--no-update-service', '--manually-restart-later'], timeout=300, env=env)
                self.service('restart')
                self.health()
                self.sync()
                self.register_monitor()
            except Exception:
                # Only remove files created after the exclusive existing-install checks.
                try:
                    self.service('stop')
                    self.run(['systemctl', 'disable', 'xray.service'])
                except Exception:
                    pass
                try:
                    self.firewall(remove=True)
                except Exception:
                    pass
                for file in (self.config_path, self.marker, self.unit, self.binary):
                    file.unlink(missing_ok=True)
                self.work.rmdir()
                self.run(['systemctl', 'daemon-reload'])
                if settings_path.read_text() != previous_settings:
                    atomic(settings_path, previous_settings, 0o640)
                    if self.cfg.get('group'):
                        os.chown(settings_path, 0, grp.getgrnam(self.cfg['group']).gr_gid)
                    self.run(['systemctl', 'try-restart', 'sb-dashboard.service'])
                raise

    def apply(self, job, payload):
        if payload.get('revision') != self.config_revision():
            raise OperationError('配置已被其他操作修改，请重新加载')
        files = payload.get('files')
        if not isinstance(files, dict) or set(files) != {'config.json'} or not isinstance(files['config.json'], str):
            raise OperationError('Xray 使用一个受管 config.json')
        try:
            doc = self.validate(json.loads(files['config.json']))
        except ValueError:
            raise OperationError('Xray JSON 格式错误')
        host = address(payload.get('server') or json.loads(self.marker.read_text())['server'])
        self.check_ports(doc, self.document())
        with tempfile.TemporaryDirectory(prefix='xray-check-', dir=self.data) as tmp:
            candidate = Path(tmp) / 'config.json'
            atomic(candidate, json.dumps(doc))
            self.check(candidate)
        self.event(job, '候选配置通过，正在应用 Xray 配置')
        job['modified'] = True
        self.save_config(doc)
        marker = json.loads(self.marker.read_text()); marker['server'] = host
        atomic(self.marker, json.dumps(marker))
        self.service('restart')
        self.health()
        self.sync()

    def upgrade(self, job, payload):
        version = str(payload.get('version', '')).removeprefix('v')
        previous = self.data / ('xray-before-' + job['id'])
        with tempfile.TemporaryDirectory(prefix='xray-upgrade-', dir=self.data) as tmp:
            self.event(job, '下载 Xray 指定版本并校验 SHA256')
            candidate = self.download(version, Path(tmp) / 'release.zip')
            self.check(self.config_path, candidate)
            shutil.copy2(self.binary, previous)
            stage = self.binary.with_name('xray.dashboard-new')
            shutil.copy2(candidate, stage)
            os.chmod(stage, 0o755)
            os.replace(stage, self.binary)
            job['modified'] = True
            try:
                self.service('restart')
                self.health()
                self.sync()
            except Exception:
                shutil.copy2(previous, stage)
                os.replace(stage, self.binary)
                raise

    def execute(self, job, payload):
        job['state'] = 'running'
        self.save_job(job)
        backup = None
        try:
            with (self.data / 'operation.lock').open('w') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                op = job['operation']
                if op == 'install':
                    self.install(job, payload)
                else:
                    self.owned()
                    if op in ('apply', 'restore', 'upgrade'):
                        backup = self.snapshot(); job['backup'] = backup
                        self.event(job, '已备份 Xray 当前配置')
                    if op == 'apply': self.apply(job, payload)
                    elif op == 'restore':
                        job['modified'] = True
                        self.restore_files(payload.get('backup', ''))
                    elif op == 'upgrade': self.upgrade(job, payload)
                    elif op == 'backup': job['backup'] = self.snapshot()
                    elif op in ('start', 'stop', 'restart'):
                        self.service(op)
                        if op != 'stop': self.health()
                    elif op == 'export': self.sync()
                    elif op == 'subscription':
                        try: origin = subscriptions.validate_origin(payload.get('origin', ''))
                        except ValueError as exc: raise OperationError(str(exc))
                        self.publish_subscriptions(origin)
                self.event(job, '操作完成')
                job['state'] = 'succeeded'
        except Exception as exc:
            job['state'] = 'failed'
            job['error'] = str(exc) if isinstance(exc, OperationError) else 'Xray 操作失败：' + type(exc).__name__
            if backup and job.get('modified'):
                try:
                    self.restore_files(backup)
                    self.event(job, 'Xray 配置已恢复并通过健康检查')
                except Exception:
                    self.event(job, 'Xray 自动恢复未通过，请从备份恢复；面板仍可访问')
        finally:
            self.save_job(job)
            self.lock.release()

    def publish_subscriptions(self, origin=None):
        path = self.data / 'xray-subscription.json'
        metadata = json.loads(path.read_text()) if path.exists() else {}
        if origin is not None: metadata['origin'] = subscriptions.validate_origin(origin)
        metadata.setdefault('origin', self.cfg['public_url'])
        metadata.setdefault('token', secrets.token_urlsafe(32))
        atomic(path, json.dumps(metadata))
        doc = self.document()
        host = json.loads(self.marker.read_text())['server']
        nodes, outbound, urls = [], [], []
        for inbound in doc['inbounds']:
            reality = inbound['streamSettings']['realitySettings']
            _, public = self.keypair(self.binary, reality['privateKey'])
            sni, sid = reality['serverNames'][0], reality['shortIds'][0]
            for client in inbound['settings']['clients']:
                name = inbound['tag'] + '-' + client['email']
                uid, port = client['id'], inbound['port']
                nodes.append({'name': name, 'type': 'vless', 'server': host, 'port': port, 'uuid': uid,
                    'network': 'tcp', 'tls': True, 'udp': True, 'flow': 'xtls-rprx-vision', 'servername': sni,
                    'client-fingerprint': 'chrome', 'reality-opts': {'public-key': public, 'short-id': sid}})
                outbound.append({'type': 'vless', 'tag': name, 'server': host, 'server_port': port, 'uuid': uid,
                    'flow': 'xtls-rprx-vision', 'tls': {'enabled': True, 'server_name': sni,
                    'utls': {'enabled': True, 'fingerprint': 'chrome'}, 'reality': {'enabled': True, 'public_key': public, 'short_id': sid}}})
                query = urlencode({'encryption': 'none', 'security': 'reality', 'sni': sni, 'fp': 'chrome',
                                   'pbk': public, 'sid': sid, 'type': 'tcp', 'flow': 'xtls-rprx-vision'})
                urls.append('vless://' + uid + '@' + ('[' + host + ']' if ':' in host else host) + ':' + str(port) + '?' + query + '#' + quote(name))
        names = [n['name'] for n in nodes]
        proxies = 'proxies: ' + json.dumps(nodes, ensure_ascii=False) + '\n'
        clash = 'mixed-port: 7890\nmode: rule\n' + proxies + 'proxy-groups: ' + json.dumps([{'name': 'PROXY', 'type': 'select', 'proxies': names}]) + '\nrules: ["MATCH,PROXY"]\n'
        links = base64.b64encode(('\n'.join(urls) + '\n').encode()).decode() + '\n'
        outputs = {'clash': clash, 'clash2': clash, 'proxies': proxies, 'shadowrocket': links, 'v2rayn': links, 'throne': links,
                   'sing-box': json.dumps({'outbounds': outbound + [{'type': 'direct', 'tag': 'direct'}], 'route': {'final': outbound[0]['tag']}}, indent=2)}
        with tempfile.TemporaryDirectory(prefix='xray-export-', dir=self.data) as tmp:
            source = Path(tmp) / 'subscribe'; source.mkdir(mode=0o700)
            for name, text in outputs.items(): atomic(source / name, text)
            return subscriptions.publish(Path(tmp), self.subscription_dir(), metadata['origin'], metadata['token'], self.cfg.get('group'))
