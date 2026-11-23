"""Read-only Xray native node statistics, separate from sing-box connection events.

Never synthesises per-connection bytes or attributes a user's aggregate bytes to
an IP. Counters are read without reset; persistent baselines prevent replays.
Inbound, user (email) and outbound counters keep separate ledgers; only inbound
bytes feed the instance totals, so the same traffic is never added twice.
"""
from concurrent.futures import ThreadPoolExecutor
from collections import deque
import ipaddress
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import threading
import time

import grpc

from . import xray_proto as pb
from .probes import probe


def validate_instance(instance):
    if not re.fullmatch(r'[a-zA-Z0-9_-]{1,40}', instance['id']):
        raise ValueError('Invalid Xray instance ID')
    host, port = instance['api_address'].rsplit(':', 1)
    if not ipaddress.ip_address(host.strip('[]')).is_loopback or not 0 < int(port) < 65536:
        raise ValueError('Xray API must use a loopback address')
    if not re.fullmatch(r'[a-zA-Z0-9@_.-]+\.service', instance['service']):
        raise ValueError('Invalid Xray service')


def generation(instance):
    r = subprocess.run(['/usr/bin/systemctl', 'show', '--value', '-p', 'MainPID', instance['service']],
                       capture_output=True, text=True, timeout=3)
    pid = r.stdout.strip()
    if r.returncode or not pid.isdigit() or int(pid) <= 0:
        raise RuntimeError('Xray service unavailable')
    start = Path('/proc/' + pid + '/stat').read_text().rsplit(')', 1)[1].split()[19]
    return Path('/proc/sys/kernel/random/boot_id').read_text().strip() + ':' + pid + ':' + start


class Client:
    def __init__(self, instance):
        validate_instance(instance)
        self.instance = instance
        self.node_only = False
        self.channel = grpc.insecure_channel(instance['api_address'])
        self.query_rpc = self.channel.unary_unary(pb.QUERY, request_serializer=pb.QueryStatsRequest.SerializeToString,
                                                  response_deserializer=pb.QueryStatsResponse.FromString)
        self.online_rpc = self.channel.unary_unary(pb.ONLINE, request_serializer=pb.GetStatsRequest.SerializeToString,
                                                   response_deserializer=pb.GetStatsOnlineIpListResponse.FromString)
        self.users_rpc = self.channel.unary_unary(pb.USERS, request_serializer=pb.GetUsersStatsRequest.SerializeToString,
                                                  response_deserializer=pb.GetUsersStatsResponse.FromString)
        self.sys_rpc = self.channel.unary_unary(pb.SYS, request_serializer=pb.SysStatsRequest.SerializeToString,
                                                response_deserializer=pb.SysStatsResponse.FromString)
        # None until probed; False on cores older than v26.10 (per-user calls are used instead).
        self.users_api = None

    def counters(self):
        """Inbound, user and outbound traffic counters in one read-only query."""
        reply = self.query_rpc(pb.QueryStatsRequest(pattern='inbound>>>' if self.node_only else '>>>traffic>>>', reset=False), timeout=4)
        return {s.name: max(0, s.value) for s in reply.stat}

    def online_users(self):
        """{email: {ip: last_seen}} for users with online addresses, or None when the core lacks GetUsersStats."""
        if self.users_api is False:
            return None
        try:
            reply = self.users_rpc(pb.GetUsersStatsRequest(include_traffic=False, reset=False), timeout=3)
        except grpc.RpcError as exc:
            if exc.code() == grpc.StatusCode.UNIMPLEMENTED:
                self.users_api = False
                return None
            raise
        self.users_api = True
        return {u.email: {e.ip: e.last_seen for e in u.ips} for u in reply.users}

    def runtime(self):
        reply = self.sys_rpc(pb.SysStatsRequest(), timeout=2)
        return {'uptime': reply.Uptime, 'goroutines': reply.NumGoroutine, 'memory': reply.Sys, 'heap': reply.Alloc,
                'gc': reply.NumGC}

    def online(self, email):
        try:
            reply = self.online_rpc(pb.GetStatsRequest(name='user>>>' + email + '>>>online', reset=False), timeout=2)
            return dict(reply.ips)
        except grpc.RpcError as exc:
            if exc.code() in (grpc.StatusCode.NOT_FOUND, grpc.StatusCode.UNIMPLEMENTED):
                return None
            raise


NODE_PROTOCOLS = ('vmess', 'vless', 'trojan', 'shadowsocks', 'socks', 'http')


def public_endpoints(instance):
    """(protocol, port) of node inbounds listening on a public address; loopback ones sit behind Nginx."""
    config = json.loads(Path(instance['config_path']).read_text())
    found = set()
    for inbound in config.get('inbounds', []):
        listen, port = str(inbound.get('listen') or '0.0.0.0'), inbound.get('port')
        if inbound.get('protocol') not in NODE_PROTOCOLS or not str(port).isdigit() or listen.startswith(('/', '@')):
            continue
        try:
            if ipaddress.ip_address(listen.strip('[]')).is_loopback:
                continue
        except ValueError:
            pass
        settings = inbound.get('settings') or {}
        network = (inbound.get('streamSettings') or {}).get('network', 'tcp')
        protos = {'udp'} if network == 'kcp' else {'tcp'}
        if inbound['protocol'] == 'shadowsocks' and 'udp' in str(settings.get('network', '')):
            protos.add('udp')
        if inbound['protocol'] == 'socks' and settings.get('udp'):
            protos.add('udp')
        found.update((proto, int(port)) for proto in protos)
    return sorted(found)


def online_levels(instance):
    """User levels whose online tracking is on in the effective policy (main config, then stats overlay)."""
    return policy_levels(instance, 'statsUserOnline')


def policy_levels(instance, *switches):
    """User levels with every given policy switch on in the effective policy (main config, then stats overlay)."""
    policy = {}
    overlay = instance.get('stats_overlay') or '/etc/joysol-xray/%s-stats.json' % instance['id']
    for path in (instance['config_path'], overlay):
        try:
            policy = json.loads(Path(path).read_text()).get('policy') or policy
        except (OSError, ValueError):
            continue
    return {int(k) for k, v in (policy.get('levels') or {}).items() if str(k).isdigit() and all(v.get(s) for s in switches)}


def topology(instance):
    config = json.loads(Path(instance['config_path']).read_text())
    outbounds, credentials = {}, {}
    for out in config.get('outbounds', []):
        tag, kind = out.get('tag', ''), out.get('protocol', '')
        if out.get('proxySettings') or out.get('streamSettings', {}).get('sockopt', {}).get('dialerProxy'):
            continue
        if kind == 'freedom':
            outbounds[tag] = 'direct'
        elif kind in ('socks', 'http'):
            servers = out.get('settings', {}).get('servers', [])
            # Multiple upstreams cannot be represented by one exit probe.
            if len(servers) == 1 and not out.get('proxySettings'):
                s = servers[0]
                users = s.get('users', [])
                if len(users) > 1:
                    continue
                user = users[0] if users else {}
                outbounds[tag] = 'proxy'
                credentials[tag] = {'type': kind, 'server': s['address'], 'port': int(s['port']),
                                    'username': user.get('user', ''), 'password': user.get('pass', '')}
    nodes = []
    for index, inbound in enumerate(config.get('inbounds', [])):
        if inbound.get('protocol') not in NODE_PROTOCOLS:
            continue
        tag = inbound.get('tag', '')
        rules = [r for r in config.get('routing', {}).get('rules', []) if tag in r.get('inboundTag', [])]
        # Only a single unconditional inbound rule identifies its exact exit.
        simple = [r for r in rules if set(r) <= {'type', 'inboundTag', 'outboundTag'} and r.get('outboundTag')]
        outbound = simple[0]['outboundTag'] if len(rules) == len(simple) == 1 else ''
        stream = inbound.get('streamSettings', {})
        network = stream.get('network', 'tcp')
        users = inbound.get('settings', {}).get('clients', [])
        nodes.append({'key': instance['id'] + ':' + tag, 'instance': instance['id'], 'tag': tag,
                      'label': instance.get('node_labels', {}).get(tag) or inbound['protocol'].upper() + ' · ' + str(inbound.get('port', index + 1)),
                      'protocol': inbound['protocol'], 'transport': network, 'tls': stream.get('security') in ('tls', 'reality') or bool(instance.get('external_tls') and network == 'ws'),
                      'port': instance.get('external_port') if network == 'ws' and instance.get('external_port') else inbound.get('port'),
                      'outbound': outbound, 'probe': outbounds.get(outbound, ''),
                      '_emails': [u['email'] for u in users if u.get('email')],
                      '_levels': {u['email']: u.get('level', 0) for u in users if u.get('email') and isinstance(u.get('level', 0), int)}})
    return nodes, credentials


def outbound_list(instance):
    config = json.loads(Path(instance['config_path']).read_text())
    return [{'tag': o['tag'], 'protocol': o.get('protocol', '')} for o in config.get('outbounds', []) if o.get('tag')]


class Ledger:
    def __init__(self, settings):
        self.lock = threading.RLock()
        self.settings = settings
        settings.data_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        path = settings.data_dir / 'xray-traffic.sqlite3'
        fd = os.open(path, os.O_WRONLY | os.O_CREAT, 0o600)
        os.close(fd)
        os.chmod(path, 0o600)
        self.db = sqlite3.connect(path, check_same_thread=False, timeout=15)
        self.db.row_factory = sqlite3.Row
        self.db.execute('PRAGMA journal_mode=WAL')
        self.db.executescript('''
CREATE TABLE IF NOT EXISTS counters(instance TEXT,tag TEXT,generation TEXT,up INTEGER,down INTEGER,total_up INTEGER,total_down INTEGER,first INTEGER,seen INTEGER,PRIMARY KEY(instance,tag));
CREATE TABLE IF NOT EXISTS daily(day TEXT,instance TEXT,tag TEXT,up INTEGER,down INTEGER,PRIMARY KEY(day,instance,tag));
CREATE TABLE IF NOT EXISTS minute(ts INTEGER,instance TEXT,up INTEGER,down INTEGER,PRIMARY KEY(ts,instance));
CREATE TABLE IF NOT EXISTS node_activity(instance TEXT,tag TEXT,at INTEGER,PRIMARY KEY(instance,tag));
CREATE TABLE IF NOT EXISTS user_counters(instance TEXT,tag TEXT,generation TEXT,up INTEGER,down INTEGER,total_up INTEGER,total_down INTEGER,first INTEGER,seen INTEGER,PRIMARY KEY(instance,tag));
CREATE TABLE IF NOT EXISTS user_daily(day TEXT,instance TEXT,tag TEXT,up INTEGER,down INTEGER,PRIMARY KEY(day,instance,tag));
CREATE TABLE IF NOT EXISTS out_counters(instance TEXT,tag TEXT,generation TEXT,up INTEGER,down INTEGER,total_up INTEGER,total_down INTEGER,first INTEGER,seen INTEGER,PRIMARY KEY(instance,tag));
CREATE TABLE IF NOT EXISTS out_daily(day TEXT,instance TEXT,tag TEXT,up INTEGER,down INTEGER,PRIMARY KEY(day,instance,tag));
CREATE TABLE IF NOT EXISTS probes(instance TEXT,tag TEXT,at INTEGER,result TEXT,PRIMARY KEY(instance,tag));
CREATE TABLE IF NOT EXISTS probe_history(instance TEXT,tag TEXT,at INTEGER,result TEXT,PRIMARY KEY(instance,tag,at));
CREATE INDEX IF NOT EXISTS xray_probe_history_time ON probe_history(at);
''')

    # kind -> (baseline table, daily table); only inbound bytes feed the per-instance minute series.
    KINDS = {'inbound': ('counters', 'daily'), 'user': ('user_counters', 'user_daily'), 'outbound': ('out_counters', 'out_daily')}

    def ingest(self, instance, gen, counters, now, day, kind='inbound'):
        counters_table, daily_table = self.KINDS[kind]
        result = {}
        with self.lock, self.db:
            for tag, values in counters.items():
                up, down = values
                old = self.db.execute('SELECT * FROM %s WHERE instance=? AND tag=?' % counters_table, (instance, tag)).fetchone()
                du = dd = 0
                rate_up = rate_down = None
                if old:
                    reset = gen != old['generation'] or up < old['up'] or down < old['down']
                    du = up if gen != old['generation'] or up < old['up'] else up - old['up']
                    dd = down if gen != old['generation'] or down < old['down'] else down - old['down']
                    elapsed = now - old['seen']
                    if not reset and 0 < elapsed <= 15:
                        rate_up, rate_down = du / elapsed, dd / elapsed
                total_up = (old['total_up'] if old else 0) + du
                total_down = (old['total_down'] if old else 0) + dd
                last_activity = None
                if kind == 'inbound':
                    if old and reset:
                        self.db.execute('DELETE FROM node_activity WHERE instance=? AND tag=?', (instance, tag))
                    if rate_up is not None and rate_down is not None and du + dd > 0:
                        self.db.execute('INSERT OR REPLACE INTO node_activity VALUES(?,?,?)', (instance, tag, now))
                    active = self.db.execute('SELECT at FROM node_activity WHERE instance=? AND tag=?', (instance, tag)).fetchone()
                    last_activity = active['at'] if active else None
                first = old['first'] if old else now
                self.db.execute('INSERT OR REPLACE INTO %s VALUES(?,?,?,?,?,?,?,?,?)' % counters_table, (instance, tag, gen, up, down, total_up, total_down, first, now))
                self.db.execute('INSERT INTO %s VALUES(?,?,?,?,?) ON CONFLICT(day,instance,tag) DO UPDATE SET up=up+excluded.up,down=down+excluded.down' % daily_table, (day, instance, tag, du, dd))
                if kind == 'inbound':
                    self.db.execute('INSERT INTO minute VALUES(?,?,?,?) ON CONFLICT(ts,instance) DO UPDATE SET up=up+excluded.up,down=down+excluded.down', (now // 60 * 60, instance, du, dd))
                today = self.db.execute('SELECT up,down FROM %s WHERE day=? AND instance=? AND tag=?' % daily_table, (day, instance, tag)).fetchone()
                result[tag] = {'upload': total_up, 'download': total_down, 'today_upload': today['up'], 'today_download': today['down'],
                               'up_rate': rate_up, 'down_rate': rate_down, 'since': first, 'sampled_at': now, 'counter_reset': bool(old and reset),
                               **({'last_activity': last_activity} if kind == 'inbound' else {})}
            self.db.execute('DELETE FROM minute WHERE ts<?', (now - 31 * 86400,))
        return result

    def series(self, now):
        with self.lock:
            return [dict(r) for r in self.db.execute('SELECT ts,SUM(up) upload,SUM(down) download FROM minute WHERE ts>=? GROUP BY ts ORDER BY ts', (now - 86400,))]

    def save_probes(self, results):
        with self.lock, self.db:
            now = int(time.time())
            for instance, tag, result in results:
                row = (instance, tag, now, json.dumps(result))
                self.db.execute('INSERT OR REPLACE INTO probes VALUES(?,?,?,?)', row)
                self.db.execute('INSERT OR REPLACE INTO probe_history VALUES(?,?,?,?)', row)
            self.db.execute('DELETE FROM probe_history WHERE at<?', (now - 7 * 86400,))

    def probes(self):
        with self.lock:
            return {r['instance'] + ':' + r['tag']: {'at': r['at'], **json.loads(r['result'])} for r in self.db.execute('SELECT * FROM probes')}

    def probe_health(self, limit, interval):
        """Consecutive completed rounds per target; repeated alert evaluations never count."""
        output = {}
        with self.lock:
            pairs = self.db.execute('SELECT instance,tag FROM probes').fetchall()
            for pair in pairs:
                rows = self.db.execute('SELECT at,result FROM probe_history WHERE instance=? AND tag=? ORDER BY at DESC LIMIT ?',
                                       (pair['instance'], pair['tag'], max(1, min(100, limit)))).fetchall()
                if not rows:
                    continue
                latest = json.loads(rows[0]['result']).get('targets', {})
                states = {}
                for name, result in latest.items():
                    count, previous = 0, rows[0]['at']
                    for row in rows:
                        target = json.loads(row['result']).get('targets', {}).get(name)
                        if previous - row['at'] > max(120, interval * 3) or not target or target.get('ok'):
                            break
                        count += 1
                        previous = row['at']
                    states[name] = {'failures': count, 'at': rows[0]['at'], 'ok': bool(result.get('ok')),
                                    'error': result.get('error', '')}
                output[pair['instance'] + ':' + pair['tag']] = states
        return output

    def user_day_totals(self, day):
        with self.lock:
            return [dict(r) for r in self.db.execute('SELECT instance,tag email,up+down total FROM user_daily WHERE day=?', (day,))]

    def details(self, since, first_day, step=60):
        with self.lock:
            daily = [dict(r) for r in self.db.execute('SELECT day,instance,tag,up upload,down download FROM daily WHERE day>=? ORDER BY day DESC,instance,tag', (first_day,))]
            user_daily = [dict(r) for r in self.db.execute('SELECT day,instance,tag email,up upload,down download FROM user_daily WHERE day>=? ORDER BY day DESC,instance,tag', (first_day,))]
            out_daily = [dict(r) for r in self.db.execute('SELECT day,instance,tag,up upload,down download FROM out_daily WHERE day>=? ORDER BY day DESC,instance,tag', (first_day,))]
            minutes = [dict(r) for r in self.db.execute('SELECT (ts/?)*? ts,instance,SUM(up) upload,SUM(down) download FROM minute WHERE ts>=? GROUP BY 1,2 ORDER BY 1', (step, step, since))]
            probes = [dict(r) for r in self.db.execute('SELECT instance,tag,at,result FROM probe_history WHERE at>=? ORDER BY at DESC LIMIT 1501', (since,))]
        truncated = len(probes) > 1500
        probes = [{k: v for k, v in row.items() if k != 'result'} | json.loads(row['result']) for row in probes[:1500]]
        return {'daily': daily, 'user_daily': user_daily, 'outbound_daily': out_daily, 'minutes': minutes, 'sample_step': step, 'probe_history': probes, 'probe_history_truncated': truncated}


class Monitor:
    def __init__(self, settings, day, stop, client_factory=Client, generation_fn=generation):
        self.settings, self.day, self.stop = settings, day, stop
        self.instances = settings.get('xray.instances') or []
        for instance in self.instances:
            validate_instance(instance)
        if len({i['id'] for i in self.instances}) != len(self.instances):
            raise ValueError('Duplicate Xray instance ID')
        self.ledger = Ledger(settings) if self.instances else None
        self.clients = {i['id']: client_factory(i) for i in self.instances}
        self.node_only = bool(settings.get('xray.node_only'))
        for client in self.clients.values():
            client.node_only = self.node_only
        self.generation_fn = generation_fn
        self.lock = threading.RLock()
        self.probe_lock = threading.Lock()
        self.states, self.rows, self.user_rows, self.out_rows, self.runtimes = {}, {}, {}, {}, {}
        self.last_probe = 0
        self.probe_running = False
        self.probe_error = ''
        self.samples = deque(maxlen=300)

    def poll(self):
        for i in self.instances:
            key = i['id']
            try:
                gen = self.generation_fn(i)
                nodes, _ = topology(i)
                client = self.clients[key]
                raw = client.counters()
                observed = {}
                for node in nodes:
                    names = ['inbound>>>' + node['tag'] + '>>>traffic>>>' + d for d in ('uplink', 'downlink')]
                    if not all(name in raw for name in names):
                        raise RuntimeError('Inbound statistics not enabled')
                    observed[node['tag']] = tuple(raw[name] for name in names)
                levels, members = {}, {}
                for node in ([] if self.node_only else nodes):
                    for email in node['_emails']:
                        levels.setdefault(email, node['_levels'].get(email, 0))
                        members.setdefault(email, []).append(node['key'])
                ips = self._online(i, client, levels) if levels else {}
                users = {}
                counted = set() if self.node_only else policy_levels(i, 'statsUserUplink', 'statsUserDownlink')
                for email, level in levels.items():
                    names = ['user>>>' + email + '>>>traffic>>>' + d for d in ('uplink', 'downlink')]
                    if all(name in raw for name in names):
                        users[email] = tuple(raw[name] for name in names)
                    elif level in counted:
                        # Xray creates a user's counters on that user's first connection: until then it has moved
                        # zero bytes, and the first value seen later must count in full rather than become a baseline.
                        users[email] = (0, 0)
                outbound = {}
                for out in ([] if self.node_only else outbound_list(i)):
                    names = ['outbound>>>' + out['tag'] + '>>>traffic>>>' + d for d in ('uplink', 'downlink')]
                    if all(name in raw for name in names):
                        outbound[out['tag']] = (out['protocol'], tuple(raw[name] for name in names))
                try:
                    runtime = client.runtime()
                except grpc.RpcError:
                    runtime = None
                if gen != self.generation_fn(i):
                    raise RuntimeError('Xray restarted during sample')
                now = int(time.time())
                day = self.day(now)
                values = self.ledger.ingest(key, gen, observed, now, day)
                user_values = {} if self.node_only else self.ledger.ingest(key, gen, users, now, day, 'user')
                out_values = {} if self.node_only else self.ledger.ingest(key, gen, {t: v for t, (_, v) in outbound.items()}, now, day, 'outbound')
                public = []
                for n in nodes:
                    sources, supported = {}, bool(n['_emails'])
                    for email in ([] if self.node_only else n['_emails']):
                        if ips[email] is None:
                            supported = False
                        else:
                            for ip, last in ips[email].items():
                                sources[ip] = max(sources.get(ip, 0), last)
                    public.append({k: v for k, v in n.items() if not k.startswith('_')} | values[n['tag']] |
                                  {'online_sources': sorted(sources) if supported and not self.node_only else None})
                user_rows = [{'key': key + ':' + email, 'instance': key, 'email': email, 'nodes': members[email],
                              'online_ips': sorted(ips[email]) if ips[email] is not None else None} |
                             (user_values.get(email) or {'upload': None, 'download': None, 'today_upload': None, 'today_download': None,
                                                         'up_rate': None, 'down_rate': None, 'since': None, 'sampled_at': now})
                             for email in levels]
                out_rows = [{'key': key + ':' + tag, 'instance': key, 'tag': tag, 'protocol': proto} | out_values[tag]
                            for tag, (proto, _) in outbound.items()]
                with self.lock:
                    self.rows[key] = public
                    self.user_rows[key] = user_rows
                    self.out_rows[key] = out_rows
                    self.runtimes[key] = runtime
                    self.states[key] = {'id': key, 'label': i.get('label', key), 'connected': True, 'last_success': now, 'error': '',
                                        'users_api': getattr(client, 'users_api', None), 'user_stats': bool(users) or not levels, 'outbound_stats': bool(outbound)}
            except Exception as exc:
                with self.lock:
                    previous = self.states.get(key, {})
                    self.states[key] = {'id': key, 'label': i.get('label', key), 'connected': False, 'last_success': previous.get('last_success', 0), 'error': type(exc).__name__}

    @staticmethod
    def _online(instance, client, levels):
        """{email: {ip: last_seen} | None}; None means the core does not track that user's online addresses."""
        if not levels:
            return {}
        bulk = client.online_users()
        tracked = online_levels(instance) if bulk is not None else set()
        result = {}
        for email, level in levels.items():
            if bulk is None:
                found = client.online(email)
            else:
                # GetUsersStats lists only users with addresses; an absent tracked user has none online.
                found = bulk.get(email, {} if level in tracked else None)
            if found is not None:
                valid = {}
                for ip, last in found.items():
                    try:
                        ipaddress.ip_address(ip)
                        valid[ip] = last
                    except ValueError:
                        pass
                found = valid
            result[email] = found
        return result

    def snapshot(self, detail=True):
        with self.lock:
            states = [dict(self.states.get(i['id'], {'id': i['id'], 'label': i.get('label', i['id']), 'connected': False, 'error': '等待首次采样', 'last_success': 0})) for i in self.instances]
            connected = {s['id'] for s in states if s['connected'] and int(time.time()) - s['last_success'] <= 15}
            for state in states:
                state['connected'] = state['id'] in connected
            nodes = [dict(row) | {'fresh': key in connected} for key, rows in self.rows.items() for row in rows]
            users = [dict(row) | {'fresh': key in connected} for key, rows in self.user_rows.items() for row in rows]
            outbounds = [dict(row) | {'fresh': key in connected} for key, rows in self.out_rows.items() for row in rows]
            runtimes = {key: value for key, value in self.runtimes.items() if key in connected}
            samples = list(self.samples)
        for n in nodes:
            n['label'] = (self.settings.get('labels.xray') or {}).get(n['key']) or n['label']
            if not n['fresh']:
                n.update(up_rate=None, down_rate=None, online_sources=None)
            n['online_activity'] = (bool(n.get('last_activity') and int(time.time()) - n['last_activity'] <= 60)
                                    if n['fresh'] and n['up_rate'] is not None and n['down_rate'] is not None else None)
        for row in users + outbounds:
            if not row['fresh']:
                row.update(up_rate=None, down_rate=None)
                if 'online_ips' in row:
                    row['online_ips'] = None
        totals = {key: sum(n[key] for n in nodes) for key in ('upload', 'download', 'today_upload', 'today_download')}
        ready = bool(nodes) and all(n['fresh'] and n['up_rate'] is not None and n['down_rate'] is not None for n in nodes)
        totals.update(rates_ready=ready, up_rate=sum(n['up_rate'] for n in nodes) if ready else None,
                      down_rate=sum(n['down_rate'] for n in nodes) if ready else None,
                      online_users=sum(1 for u in users if u['online_ips']) if any(u['online_ips'] is not None for u in users) else None)
        totals.update(online_nodes=sum(n['online_activity'] is True for n in nodes) if any(n['online_activity'] is not None for n in nodes) else None,
                      online_nodes_unknown=sum(n['online_activity'] is None for n in nodes))
        return {'enabled': bool(self.instances), 'node_only': self.node_only, 'activity_window_seconds': 60,
                'instances': states, 'nodes': nodes, 'users': users, 'outbound_stats': outbounds,
                'runtimes': runtimes, 'totals': totals,
                'series': self.ledger.series(int(time.time())) if self.ledger and detail else [], 'realtime': samples,
                'probes': self.ledger.probes() if self.ledger else {}, 'probe_running': self.probe_running, 'probe_error': self.probe_error,
                'scope': ('仅统计节点入站流量。在线节点按近 60 秒采样到的真实流量判断；无近期流量不代表连接断开，缺失/过期采样为未知。' if self.node_only else 'Xray 入站原生计数；自首次接入采样起，未回填历史。用户流量按 email 计数，同一用户在多个入站共用一份计数。在线来源按核心口径，经过 CDN/Nginx 时可能为边缘或回环，不能冒充真实客户端 IP。'),
                'limitations': 'Xray 不提供逐连接字节、目标域名和关闭单连接接口；用户流量不分配到任何 IP。跨日采样中断期间的增量计入恢复日。'}

    def probe_async(self):
        if not self.instances or not self.probe_lock.acquire(blocking=False):
            return False
        self.probe_running = True
        def work():
            try:
                results = []
                targets = self.settings.get('probes.targets') or []
                timeout = int(self.settings.get('probes.timeout_seconds'))
                jobs = {}
                def perform(mode, upstream):
                    return {t['name']: probe(t, upstream if mode == 'proxy' else None, timeout) for t in targets}
                with ThreadPoolExecutor(max_workers=4) as pool:
                    for instance in self.instances:
                        nodes, creds = topology(instance)
                        for node in nodes:
                            if node['probe'] and (instance['id'], node['outbound']) not in jobs:
                                jobs[(instance['id'], node['outbound'])] = pool.submit(perform, node['probe'], creds.get(node['outbound']))
                    for (instance, tag), job in jobs.items():
                        results.append((instance, tag, {'targets': job.result()}))
                self.ledger.save_probes(results)
                self.probe_error = ''
            except Exception as exc:
                # A failed probe must never replace previous evidence with success.
                self.probe_error = type(exc).__name__
            finally:
                self.last_probe = time.time()
                self.probe_running = False
                self.probe_lock.release()
        threading.Thread(target=work, name='xray-probes', daemon=True).start()
        return True

    def run(self):
        while not self.stop.is_set():
            self.poll()
            snapshot = self.snapshot(detail=False)
            totals = snapshot['totals']
            by_instance = {}
            for instance in self.instances:
                rows = [n for n in snapshot['nodes'] if n['instance'] == instance['id']]
                ready = bool(rows) and all(n['fresh'] and n['up_rate'] is not None and n['down_rate'] is not None for n in rows)
                by_instance[instance['id']] = {'up': sum(n['up_rate'] for n in rows) if ready else None,
                                               'down': sum(n['down_rate'] for n in rows) if ready else None}
            with self.lock:
                self.samples.append({'t': int(time.time() * 1000), 'up': totals['up_rate'], 'down': totals['down_rate'], 'instances': by_instance})
            if self.settings.get('probes.enabled') and time.time() - self.last_probe >= int(self.settings.get('probes.interval_seconds')):
                self.probe_async()
            self.stop.wait(max(1, int(self.settings.get('xray.poll_seconds') or 2)))
