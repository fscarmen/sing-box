"""Exit probes: discover the server's own public address and each upstream exit address.

Requests go directly (the `direct` outbound) or through the same SOCKS5 / HTTP CONNECT
upstreams sing-box uses, to Cloudflare trace endpoints that echo the arriving address.
Upstream credentials are read from the sing-box config in memory and never stored.
"""
import base64
import ipaddress
import socket
import ssl
import struct
import threading
import time
from urllib.parse import urlsplit


class ProbeError(Exception):
    pass


def _recv_exact(sock, size):
    data = b''
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise ProbeError('上游提前关闭连接')
        data += chunk
    return data


def socks5_connect(sock, host, port, username='', password=''):
    methods = b'\x00\x02' if username else b'\x00'
    sock.sendall(b'\x05' + bytes([len(methods)]) + methods)
    version, method = _recv_exact(sock, 2)
    if version != 5 or method == 0xFF:
        raise ProbeError('SOCKS5 不接受认证方式')
    if method == 2:
        user, pw = username.encode(), password.encode()
        sock.sendall(b'\x01' + bytes([len(user)]) + user + bytes([len(pw)]) + pw)
        if _recv_exact(sock, 2)[1] != 0:
            raise ProbeError('SOCKS5 认证失败')
    name = host.encode('idna')
    sock.sendall(b'\x05\x01\x00\x03' + bytes([len(name)]) + name + struct.pack('!H', port))
    head = _recv_exact(sock, 4)
    if head[1] != 0:
        raise ProbeError('SOCKS5 连接被拒绝 (%d)' % head[1])
    kind = head[3]
    skip = {1: 4, 4: 16}.get(kind)
    if skip is None:
        skip = _recv_exact(sock, 1)[0]
    _recv_exact(sock, skip + 2)


def http_connect(sock, host, port, username='', password=''):
    lines = ['CONNECT %s:%d HTTP/1.1' % (host, port), 'Host: %s:%d' % (host, port)]
    if username:
        token = base64.b64encode(('%s:%s' % (username, password)).encode()).decode()
        lines.append('Proxy-Authorization: Basic ' + token)
    sock.sendall(('\r\n'.join(lines) + '\r\n\r\n').encode())
    reply = b''
    while b'\r\n\r\n' not in reply:
        chunk = sock.recv(1024)
        if not chunk:
            raise ProbeError('HTTP 代理提前关闭连接')
        reply += chunk
        if len(reply) > 16384:
            raise ProbeError('HTTP 代理响应过大')
    status = reply.split(b'\r\n', 1)[0].split()
    if len(status) < 2 or status[1] != b'200':
        raise ProbeError('HTTP 代理返回 %s' % (status[1].decode(errors='replace') if len(status) > 1 else '?'))


def parse_trace(body):
    values = {}
    for line in body.splitlines():
        key, found, value = line.partition('=')
        if found:
            values[key.strip()] = value.strip()
    return values


def fetch(url, upstream=None, timeout=12):
    """GET url, optionally through an upstream proxy. Returns (status, body, connect_ms, total_ms)."""
    parts = urlsplit(url)
    host = parts.hostname
    port = parts.port or (443 if parts.scheme == 'https' else 80)
    started = time.monotonic()
    if upstream:
        raw = socket.create_connection((upstream['server'], upstream['port']), timeout=timeout)
    else:
        raw = socket.create_connection((host, port), timeout=timeout)
    sock = raw
    try:
        raw.settimeout(timeout)
        if upstream:
            if upstream.get('tls'):
                sock = ssl.create_default_context().wrap_socket(raw, server_hostname=upstream.get('sni') or upstream['server'])
            if upstream['type'] == 'socks':
                socks5_connect(sock, host, port, upstream.get('username', ''), upstream.get('password', ''))
            else:
                http_connect(sock, host, port, upstream.get('username', ''), upstream.get('password', ''))
        connected = time.monotonic()
        if parts.scheme == 'https':
            sock = ssl.create_default_context().wrap_socket(sock, server_hostname=host)
        path = (parts.path or '/') + ('?' + parts.query if parts.query else '')
        sock.sendall(('GET %s HTTP/1.1\r\nHost: %s\r\nUser-Agent: joysol-panel-probe/2\r\nAccept: */*\r\nConnection: close\r\n\r\n' % (path, host)).encode())
        data = b''
        while len(data) < 65536:
            chunk = sock.recv(8192)
            if not chunk:
                break
            data += chunk
        finished = time.monotonic()
    finally:
        try:
            sock.close()
        except OSError:
            pass
    head, _sep, body = data.partition(b'\r\n\r\n')
    status_line = head.split(b'\r\n', 1)[0].split()
    status = int(status_line[1]) if len(status_line) > 1 and status_line[1].isdigit() else 0
    if b'transfer-encoding: chunked' in head.lower():
        body = _dechunk(body)
    return status, body.decode(errors='replace'), int((connected - started) * 1000), int((finished - started) * 1000)


def _dechunk(body):
    out = b''
    while body:
        size_line, _sep, rest = body.partition(b'\r\n')
        try:
            size = int(size_line.split(b';')[0], 16)
        except ValueError:
            break
        if size == 0:
            break
        out += rest[:size]
        body = rest[size + 2:]
    return out


def probe(target, upstream=None, timeout=12):
    result = {'target': target['name'], 'ok': 0, 'exit_ip': '', 'colo': '', 'loc': '', 'connect_ms': 0, 'total_ms': 0, 'error': ''}
    try:
        status, body, connect_ms, total_ms = fetch(target['url'], upstream, timeout)
        result.update(connect_ms=connect_ms, total_ms=total_ms)
        is_http = target.get('kind') == 'http'
        trace = parse_trace(body) if status == 200 and not is_http else {}
        ip = trace.get('ip', '')
        try:
            ipaddress.ip_address(ip)
        except ValueError:
            ip = ''
        result.update(exit_ip=ip, colo=trace.get('colo', '')[:8], loc=trace.get('loc', '')[:4])
        if (is_http and 200 <= status < 400) or (not is_http and status == 200 and ip):
            result['ok'] = 1
        else:
            result['error'] = 'HTTP %d' % status
    except (OSError, ProbeError, ssl.SSLError, ValueError) as exc:
        result['error'] = str(exc)[:120] if isinstance(exc, ProbeError) else type(exc).__name__
    return result


class Prober:
    def __init__(self, settings, topology, store, geo):
        self.settings = settings
        self.topology = topology
        self.store = store
        self.geo = geo
        self.last_run = 0
        self.running = False
        self.lock = threading.Lock()
        self.error = store.meta('singbox_probe_error', '')

    def outbounds(self):
        skip = set(self.settings.get('probes.skip') or [])
        return [o for o in self.topology.describe()['outbounds'] if o['probe'] and o['tag'] not in skip]

    def due(self):
        return self.settings.get('probes.enabled') and not self.running and time.time() - self.last_run >= int(self.settings.get('probes.interval_seconds'))

    def run(self):
        if not self.lock.acquire(blocking=False):
            return []
        self.running = True
        try:
            self.last_run = time.time()
            targets = self.settings.get('probes.targets') or []
            timeout = int(self.settings.get('probes.timeout_seconds'))
            results = []
            for outbound in self.outbounds():
                upstream = self.topology.proxy(outbound['tag']) if outbound['probe'] == 'proxy' else None
                for target in targets:
                    result = probe(target, upstream, timeout)
                    result['outbound'] = outbound['tag']
                    results.append(result)
            at = int(time.time())
            with self.store.write() as c:
                c.executemany('INSERT INTO probes VALUES(?,?,?,?,?,?,?,?,?,?)', [
                    (at, r['outbound'], r['target'], r['ok'], r['exit_ip'], r['colo'], r['loc'], r['connect_ms'], r['total_ms'], r['error'])
                    for r in results])
                c.execute('INSERT OR REPLACE INTO meta VALUES(?,?)', ('singbox_probe_error', ''))
            self.error = ''
            return results
        except Exception as exc:
            # An aborted worker is not a completed failure round. Never persist exception text
            # which may contain an upstream address or credential.
            self.error = type(exc).__name__
            with self.store.write() as c:
                c.execute('INSERT OR REPLACE INTO meta VALUES(?,?)', ('singbox_probe_error', self.error))
            return []
        finally:
            self.running = False
            self.lock.release()

    def probe_health(self, limit, interval):
        """Per-target completed rounds, deduplicated by timestamp; never count evaluations."""
        output = {}
        c = self.store.reader()
        for outbound in self.outbounds():
            tag = outbound['tag']
            latest = c.execute('SELECT MAX(at) FROM probes WHERE outbound=?', (tag,)).fetchone()[0]
            states = {}
            for target in self.settings.get('probes.targets') or []:
                rows = c.execute('''SELECT at,MAX(ok) ok,MAX(error) error FROM probes
WHERE outbound=? AND target=? GROUP BY at ORDER BY at DESC LIMIT ?''',
                    (tag, target['name'], max(1, min(100, limit)))).fetchall()
                # A target omitted from the most recent round is unknown, not its older value.
                if not rows or rows[0]['at'] != latest:
                    continue
                count, previous = 0, rows[0]['at']
                for row in rows:
                    if previous - row['at'] > max(120, interval * 3) or row['ok']:
                        break
                    count += 1
                    previous = row['at']
                states[target['name']] = {'at': rows[0]['at'], 'ok': bool(rows[0]['ok']),
                                          'failures': count, 'error': rows[0]['error']}
            output[tag] = states
        return output

    def latest(self):
        rows = self.store.reader().execute('''SELECT p.* FROM probes p JOIN (SELECT outbound,target,MAX(at) at FROM probes GROUP BY 1,2) m
ON p.outbound=m.outbound AND p.target=m.target AND p.at=m.at''').fetchall()
        out = {}
        for r in rows:
            entry = out.setdefault(r['outbound'], {'outbound': r['outbound'], 'at': r['at'], 'targets': {}, 'exit_ip': '', 'geo': None})
            entry['at'] = max(entry['at'], r['at'])
            entry['targets'][r['target']] = {k: r[k] for k in ('ok', 'exit_ip', 'colo', 'loc', 'connect_ms', 'total_ms', 'error')}
            if r['ok'] and not entry['exit_ip']:
                entry['exit_ip'] = r['exit_ip']
        for entry in out.values():
            if entry['exit_ip']:
                g = self.geo.lookup(entry['exit_ip'])
                entry['geo'] = {k: g[k] for k in ('location', 'isp', 'asn', 'lat', 'lon', 'country_code')}
            entry['ok'] = any(t['ok'] for t in entry['targets'].values())
        return out

    def history(self, hours=24):
        rows = self.store.reader().execute('SELECT at,outbound,target,ok,exit_ip,total_ms FROM probes WHERE at>=? ORDER BY at',
                                           (int(time.time()) - hours * 3600,)).fetchall()
        return [dict(r) for r in rows]

    def failures(self, outbound):
        """Consecutive failed rounds (all targets failed) for an outbound."""
        rows = self.store.reader().execute('SELECT at,MAX(ok) ok FROM probes WHERE outbound=? GROUP BY at ORDER BY at DESC LIMIT 10', (outbound,)).fetchall()
        count = 0
        for r in rows:
            if r['ok']:
                break
            count += 1
        return count

    def exit_changes(self, outbound, limit=20):
        rows = self.store.reader().execute(
            "SELECT at,exit_ip FROM probes WHERE outbound=? AND ok=1 AND exit_ip!='' ORDER BY at DESC LIMIT 200", (outbound,)).fetchall()
        changes, previous = [], None
        for r in reversed(rows):
            if r['exit_ip'] != previous:
                changes.append({'at': r['at'], 'exit_ip': r['exit_ip']})
                previous = r['exit_ip']
        return changes[-limit:]
