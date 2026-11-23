"""Local preview with synthetic data; never touches a real server or sing-box.

    python dev/devserver.py [--port 8790] [--geo-dir DIR] [--xray /path/to/xray]

--xray also previews the Xray pages with a real local core: two VLESS users chained on loopback,
with background traffic, so counters, users and outbound bytes are native (not synthesised).

Login: dev / dev-password. Data lives in a temporary directory removed on exit.
"""
import argparse
import atexit
import hashlib
import json
import os
import random
import http.server
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
os.environ.setdefault('JOYSOL_TEST', '1')

from panel import create_app, settings as settings_mod  # noqa: E402
from panel import proto as pb  # noqa: E402
from panel import netstats  # noqa: E402

CLIENTS = ['223.104.1.1', '120.229.1.1', '36.112.1.1', '2409:8a00::1', '114.114.114.114', '101.80.0.1', '183.192.0.1', '8.8.8.8']
DOMAINS = {
    'ai': ['chatgpt.com', 'api.openai.com', 'claude.ai', 'gemini.google.com', 'www.google.com'],
    'other': ['github.com', 'www.youtube.com', 'x.com', 'cdn.jsdelivr.net', 'store.steampowered.com', 'www.reddit.com'],
}
RULE = 'domain_suffix=[openai.com chatgpt.com claude.ai google.com] network=tcp => route(%s)'
INBOUNDS = ['vless-reality-in', 'vless-esa-ws-in', 'vless-esa-oxy-8001']


def route(inbound, domain):
    if domain in DOMAINS['ai']:
        out = 'oxylabs-8001' if inbound == 'vless-esa-oxy-8001' else 'decodo-us-10003'
        return out, RULE % out
    return 'direct', ''


def seed(ctx, rng):
    """Seven days of closed connections written straight into the ledger and rollups."""
    c = ctx.store.writer
    now = int(time.time())
    rows = []
    for n in range(4000):
        at = now - int(rng.random() ** 1.6 * 7 * 86400)
        ip = rng.choice(CLIENTS[:6]) if rng.random() < 0.9 else rng.choice(CLIENTS)
        inbound = rng.choices(INBOUNDS, [3, 6, 1])[0]
        domain = rng.choice(DOMAINS['ai' if rng.random() < 0.35 else 'other'])
        out, rule = route(inbound, domain)
        down = int(rng.lognormvariate(12, 1.6))
        up = int(down * rng.uniform(0.02, 0.2))
        rows.append(('s%d' % n, ip, domain, 'tcp/tls', 'vless/' + inbound, out, at * 1000, (at + 30) * 1000, up, down, (at + 30) * 1000, 0, rule, out, domain + ':443', '', ''))
    c.execute('BEGIN')
    c.executemany('INSERT INTO connections(id,ip,domain,protocol,inbound,outbound,started,ended,upload,download,seen,active,rule,chain,destination,user,outbound_type) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)', rows)
    for r in rows:
        ts = r[10] // 1000
        c.execute("INSERT INTO daily VALUES(?,?,?,?) ON CONFLICT(day,ip) DO UPDATE SET upload=upload+excluded.upload,download=download+excluded.download", (ctx.store.day(ts), r[1], r[8], r[9]))
        for table, step in (('series_hour', 3600), ('series_minute', 60)):
            if table == 'series_minute' and ts < now - 86400:
                continue
            c.execute('INSERT INTO %s VALUES(?,?,?,?,?,?) ON CONFLICT(ts,ip,inbound,outbound) DO UPDATE SET upload=upload+excluded.upload,download=download+excluded.download' % table,
                      (ts // step * step, r[1], r[4], r[5], r[8], r[9]))
    c.execute('DELETE FROM ip_totals')
    c.execute('DELETE FROM history_groups')
    c.execute('INSERT INTO ip_totals SELECT ip,COUNT(*),SUM(upload),SUM(download),MIN(started),MAX(seen) FROM connections GROUP BY ip')
    c.execute('INSERT INTO history_groups SELECT ip,domain,protocol,inbound,COUNT(*),SUM(upload),SUM(download),MIN(started),MAX(seen),GROUP_CONCAT(DISTINCT outbound) FROM connections GROUP BY 1,2,3,4')
    c.execute("UPDATE meta SET value=? WHERE key='tracking_since'", (str((now - 7 * 86400) * 1000),))
    exits = {'direct': '8.8.4.4', 'decodo-us-10003': '198.51.100.44', 'oxylabs-8001': '198.51.100.146'}
    for k in range(0, 24 * 12):
        at = now - k * 300
        for out, ip in exits.items():
            for target, base in (('trace', 180), ('chatgpt', 260), ('claude', 300)):
                ok = rng.random() > 0.03
                exit_ip = ip if k > 40 or out != 'decodo-us-10003' else '198.51.100.45'
                c.execute('INSERT INTO probes VALUES(?,?,?,?,?,?,?,?,?,?)', (at, out, target, int(ok), exit_ip if ok else '', 'LAX', 'US',
                                                                         int(base * 0.4), int(base * rng.uniform(0.8, 1.6) * (2.5 if out != 'direct' else 1)), '' if ok else 'timeout'))
    c.execute("INSERT INTO bans(ip,reason,created,enforcement,expires) VALUES('203.0.113.0/24','扫描来源',?, 'dev', ?)", (now - 3600, now + 86400))
    c.execute("INSERT INTO audit VALUES(?,?,?,?)", (now - 3600, 'ban', '203.0.113.0/24', '扫描来源'))
    c.execute('COMMIT')


UPSTREAMS = {(netstats.ipaddress.ip_address('192.0.2.10'), 10003): 'decodo-us-10003',
             (netstats.ipaddress.ip_address('192.0.2.11'), 8001): 'oxylabs-8001'}
CLIENT_RTT = {'223.104.1.1': 210, '120.229.1.1': 165, '36.112.1.1': 150, '114.114.114.114': 185, '101.80.0.1': 240}


def seed_network(ctx, rng):
    """History for the network view: interface bytes ~2.2x payload, path quality per segment."""
    c = ctx.store.writer
    now = int(time.time())
    c.execute('BEGIN')
    for table, src in (('nic_hour', 'series_hour'), ('nic_minute', 'series_minute')):
        for ts, total in c.execute('SELECT ts,SUM(upload+download) FROM %s GROUP BY ts' % src).fetchall():
            if ts < now - 60:
                c.execute('INSERT INTO %s VALUES(?,?,?,?)' % table, (ts, 'eth0', int(total * rng.uniform(1.05, 1.2)), int(total * rng.uniform(1.05, 1.15))))
    for k in range(7 * 24 * 12):
        ts = now - k * 300
        evening = 1.6 if 12 <= time.gmtime(ts).tm_hour <= 15 else 1.0
        rows = [('client', ip, rtt * evening * rng.uniform(0.9, 1.2), 0.012 * evening) for ip, rtt in CLIENT_RTT.items()]
        rows += [('edge', 'edge', 160 * rng.uniform(0.95, 1.1), 0.004), ('upstream', 'decodo-us-10003', 1.3 * rng.uniform(0.8, 1.6), 0.0005),
                 ('upstream', 'oxylabs-8001', 9 * rng.uniform(0.8, 1.4), 0.001), ('direct', 'direct', 25 * rng.uniform(0.8, 1.5), 0.002)]
        for segment, key, rtt, loss in rows:
            sent = int(rng.lognormvariate(14, 1))
            c.execute('INSERT INTO quality VALUES(?,?,?,?,?,?,?,?,?)', (ts, segment, key, rng.randint(1, 9), round(rtt, 1), round(rtt * 1.3, 1),
                                                                      round(rtt * 0.85, 1), sent, int(sent * loss * rng.uniform(0, 2))))
    c.execute('COMMIT')


def fake_ss(rng):
    lines = []
    for ip, rtt in CLIENT_RTT.items():
        for n in range(rng.randint(1, 4)):
            lines.append('0 0 203.0.113.10:443 %s:%d' % (ip, 50000 + n))
            lines.append('\t bbr rtt:%.1f/9 minrtt:%.1f bytes_sent:%d bytes_retrans:%d' % (rtt * rng.uniform(0.9, 1.3), rtt * 0.85, rng.randint(10 ** 5, 10 ** 7), rng.randint(0, 40000)))
    for n in range(6):
        lines += ['0 0 203.0.113.10:8443 192.0.2.%d:3%04d' % (50 + n, n), '\t bbr rtt:%.1f/5 minrtt:150 bytes_sent:%d bytes_retrans:%d' % (160 * rng.uniform(0.95, 1.1), rng.randint(10 ** 5, 10 ** 7), rng.randint(0, 9000))]
    for (addr, port), _tag in UPSTREAMS.items():
        lines += ['0 0 203.0.113.10:4%04d %s:%d' % (port % 10000, addr, port), '\t bbr rtt:%.2f/0.2 minrtt:0.9 bytes_sent:%d' % (rng.uniform(1, 12), rng.randint(10 ** 4, 10 ** 6))]
    lines += ['0 0 203.0.113.10:41000 192.0.2.200:443', '\t bbr rtt:%.1f/2 minrtt:20 bytes_sent:%d bytes_retrans:%d' % (rng.uniform(18, 40), rng.randint(10 ** 5, 10 ** 7), rng.randint(0, 3000))]
    return '\n'.join(lines) + '\n'


def fake_nic(ctx, proc):
    """Interface counters that follow the simulated payload (both legs plus overhead)."""
    rx = tx = 10 ** 9
    while True:
        frame = ctx.live.frame()
        rx += int((frame['up'] + frame['down']) * 1.08) + 3000
        tx += int((frame['up'] + frame['down']) * 1.1) + 2000
        (proc / 'dev').write_text('h\nh\n    lo: 1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0\n  eth0: %d 0 0 0 0 0 0 0 %d 0 0 0 0 0 0 0\n' % (rx, tx))
        time.sleep(1)


def simulate(ctx, rng):
    """Feed lifecycle events like sing-box does: new, per-second deltas, close."""
    alive = {}
    n = 0
    ctx.store.ingest(pb.ConnectionEvents(reset=True))
    while True:
        events = []
        while len(alive) < 28 or rng.random() < 0.3:
            n += 1
            cid = 'live%d' % n
            ip = rng.choice(CLIENTS[:5])
            inbound = rng.choices(INBOUNDS, [3, 6, 1])[0]
            domain = rng.choice(DOMAINS['ai' if rng.random() < 0.4 else 'other'])
            out, rule = route(inbound, domain)
            alive[cid] = (ip, domain, inbound, out, rule, rng.choice([2e3, 2e4, 2e5, 1.5e6]))
            conn = pb.Connection(id=cid, source=ip + ':40000' if ':' not in ip else '[%s]:40000' % ip, destination=domain + ':443', domain=domain,
                                 network='tcp', protocol='tls', inbound=inbound, inboundType='vless', createdAt=int(time.time() * 1000),
                                 outbound=out, rule=rule, chainList=[out])
            events.append(pb.ConnectionEvent(type=pb.EVENT_NEW, id=cid, connection=conn))
        for cid, (ip, domain, inbound, out, rule, scale) in list(alive.items()):
            wave = 1 + 0.6 * __import__('math').sin(time.time() / 9 + hash(cid) % 7)
            dd = int(rng.expovariate(1 / scale) * wave)
            events.append(pb.ConnectionEvent(type=pb.EVENT_UPDATE, id=cid, uplinkDelta=dd // 12, downlinkDelta=dd))
            if rng.random() < 0.02:
                alive.pop(cid)
                events.append(pb.ConnectionEvent(type=pb.EVENT_CLOSED, id=cid, closedAt=int(time.time() * 1000)))
        ctx.store.ingest(pb.ConnectionEvents(events=events))
        ctx.health.update(connected=True, last_event=int(time.time() * 1000), last_error='')
        time.sleep(1)


def free_port():
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


def start_xray(root, binary):
    """Run a loopback-only Xray: socks local-<user> -> VLESS chain-<user> -> VLESS node -> freedom."""
    api, node, users = free_port(), free_port(), ['alice@dev.invalid', 'bob@dev.invalid']
    ids = {u: '00000000-0000-4000-8000-%012d' % (i + 1) for i, u in enumerate(users)}
    socks = {u: free_port() for u in users}
    config = {'log': {'loglevel': 'none'},
              'inbounds': [{'tag': 'node', 'protocol': 'vless', 'listen': '127.0.0.1', 'port': node,
                            'settings': {'decryption': 'none', 'clients': [{'id': ids[u], 'email': u} for u in users]}}] +
                          [{'tag': 'local-' + u.split('@')[0], 'protocol': 'socks', 'listen': '127.0.0.1', 'port': socks[u], 'settings': {'auth': 'noauth'}} for u in users],
              'outbounds': [{'tag': 'direct', 'protocol': 'freedom', 'settings': {'finalRules': [{'action': 'allow', 'ip': ['127.0.0.1/32']}]}}] +
                           [{'tag': 'chain-' + u.split('@')[0], 'protocol': 'vless', 'settings': {'vnext': [{'address': '127.0.0.1', 'port': node, 'users': [{'id': ids[u], 'encryption': 'none'}]}]}} for u in users],
              'routing': {'rules': [{'type': 'field', 'inboundTag': ['node'], 'outboundTag': 'direct'}] +
                                   [{'type': 'field', 'inboundTag': ['local-' + u.split('@')[0]], 'outboundTag': 'chain-' + u.split('@')[0]} for u in users]}}
    overlay = {'stats': {}, 'api': {'tag': 'dev-stats', 'listen': '127.0.0.1:%d' % api, 'services': ['StatsService']},
               'policy': {'system': {k: True for k in ('statsInboundUplink', 'statsInboundDownlink', 'statsOutboundUplink', 'statsOutboundDownlink')},
                          'levels': {'0': {'statsUserUplink': True, 'statsUserDownlink': True, 'statsUserOnline': True}}}}
    (root / 'xray.json').write_text(json.dumps(config))
    (root / 'xray-stats.json').write_text(json.dumps(overlay))
    proc = subprocess.Popen([binary, 'run', '-config', str(root / 'xray.json'), '-config', str(root / 'xray-stats.json')],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    atexit.register(proc.terminate)
    instance = {'id': 'dev', 'label': '本地 Xray', 'service': 'xray-dev.service', 'config_path': str(root / 'xray.json'),
                'api_address': '127.0.0.1:%d' % api, 'stats_overlay': str(root / 'xray-stats.json'),
                'node_labels': {'node': 'VLESS 主入口'}}
    return instance, list(socks.values())


def xray_traffic(ports):
    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            body = os.urandom(random.randint(20, 400) * 1024)
            self.send_response(200); self.send_header('Content-Length', str(len(body))); self.end_headers(); self.wfile.write(body)

        def log_message(self, *args):
            pass
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    while True:
        for weight, port in zip((1, 3), ports):
            for _ in range(weight):
                subprocess.run(['curl', '-s', '-o', '/dev/null', '--max-time', '5', '--proxy', 'socks5h://127.0.0.1:%d' % port,
                                'http://127.0.0.1:%d/' % server.server_port], check=False)
        time.sleep(2)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8790)
    parser.add_argument('--geo-dir', default=os.environ.get('JOYSOL_DEV_GEO', ''))
    parser.add_argument('--xray', default=os.environ.get('JOYSOL_DEV_XRAY', ''), help='local Xray binary for the Xray preview')
    args = parser.parse_args()
    root = Path(tempfile.mkdtemp(prefix='joysol-dev-'))
    atexit.register(shutil.rmtree, root, True)
    salt = os.urandom(16).hex()
    (root / 'config.json').write_text(json.dumps({
        'username': 'dev', 'salt': salt, 'api_secret': 'dev' * 10, 'origin_guard': 'dev' * 20,
        'password_hash': hashlib.pbkdf2_hmac('sha256', b'dev-password', bytes.fromhex(salt), 600000).hex()}))
    values = {
        'site': {'public_url': 'http://localhost:%d' % args.port, 'base_path': '/monitor', 'title': 'Joysol 节点管理 · 本地预览',
                 'cookie_name': 'joysol_dev_session', 'cookie_secure': False},
        'paths': {'data_dir': str(root / 'data')},
        'singbox': {'config_path': str(HERE.parent / 'tests/fixtures/singbox.json')},
        'probes': {'enabled': False}, 'alerts': {'services': []},
        'gate': {'enabled': True},
        'labels': {'outbounds': {'direct': 'VPS 直连', 'decodo-us-10003': 'Decodo 家宽', 'oxylabs-8001': 'Oxylabs 8001'},
                   'inbounds': {'vless-reality-in': 'Reality 直连', 'vless-esa-ws-in': 'ESA 中转', 'vless-esa-oxy-8001': 'ESA · Oxylabs'}},
    }
    if args.geo_dir:
        values['paths']['geo_dir'] = args.geo_dir
    xray_ports = []
    if args.xray:
        instance, xray_ports = start_xray(root, args.xray)
        values['xray'] = {'instances': [instance]}
    proc = root / 'proc'
    proc.mkdir()
    (proc / 'route').write_text('Iface\tDestination\neth0\t00000000\n')
    (proc / 'boot').write_text('dev\n')
    (proc / 'dev').write_text('h\nh\n  eth0: 1000000000 0 0 0 0 0 0 0 1000000000 0 0 0 0 0 0 0\n')
    values['network'] = {'edge_ports': [8443], 'proc_net_dev': str(proc / 'dev'), 'proc_route': str(proc / 'route'),
                         'boot_id_path': str(proc / 'boot'), 'quality_interval_seconds': 30}
    (root / 'settings.json').write_text(json.dumps(values))
    s = settings_mod.load(root / 'settings.json', root / 'config.json', environ={})
    app = create_app(s, firewall_runner=lambda *a, **k: type('R', (), {'returncode': 1, 'stdout': b''})(), start_workers=False)
    ctx = app.extensions['joysol']
    rng = random.Random(42)
    seed(ctx, rng)
    seed_network(ctx, rng)
    ctx.quality.runner = lambda: fake_ss(rng)
    ctx.quality.upstreams = lambda: UPSTREAMS
    for target in (lambda: simulate(ctx, rng), lambda: fake_nic(ctx, proc), ctx._ticker, ctx._maintenance):
        threading.Thread(target=target, daemon=True).start()
    if xray_ports:
        # No systemd here: one process generation for the preview core.
        ctx.xray.generation_fn = lambda instance: 'dev'
        threading.Thread(target=ctx.xray.run, daemon=True).start()
        threading.Thread(target=xray_traffic, args=(xray_ports,), daemon=True).start()
    print('Preview: http://localhost:%d/monitor/  (dev / dev-password)' % args.port, flush=True)
    app.run(host='127.0.0.1', port=args.port, threaded=True, use_reloader=False)


if __name__ == '__main__':
    main()
