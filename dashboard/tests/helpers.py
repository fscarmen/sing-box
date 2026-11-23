"""Isolated test environment: temporary config + data directories, no network, no firewall."""
import hashlib
import json
import os
import random
import shutil
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
os.environ['JOYSOL_TEST'] = '1'

from panel import create_app, settings as settings_mod  # noqa: E402
from panel import proto as pb  # noqa: E402

PASSWORD = 'test-password'
ORIGIN = 'https://panel.example.test'


class FakeFirewall:
    def __init__(self):
        self.calls = []
        self.rules = set()
        self.jumps = set()

    def __call__(self, binary, args, check=True):
        self.calls.append((binary, tuple(args)))
        out = type('R', (), {'returncode': 0, 'stdout': b''})()
        if args[0] == '-C':
            out.returncode = 0 if tuple(args[1:]) in self.rules else 1
        elif args[0] == '-A':
            self.rules.add(tuple(args[1:]))
        elif args[0] == '-D' and args[1] != 'INPUT':
            self.rules.discard(tuple(args[1:]))
        elif args[0] == '-S':
            out.stdout = '\n'.join('-A INPUT -p %s -m %s --dport %d -j %s' % (pr, pr, p, c) for pr, p, c in sorted(self.jumps)).encode()
        elif args[0] == '-I' and args[1] == 'INPUT':
            self.jumps.add((args[args.index('-p') + 1], int(args[args.index('--dport') + 1]), args[-1]))
        elif args[0] == '-D' and args[1] == 'INPUT':
            self.jumps.discard((args[args.index('-p') + 1], int(args[args.index('--dport') + 1]), args[-1]))
        return out


def account(username, password):
    salt = os.urandom(16).hex()
    return {'username': username, 'salt': salt, 'password_hash': hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(salt), 600000).hex()}


def make_env(base_path='/monitor', extra=None, geo_dir=None, users=()):
    root = Path(tempfile.mkdtemp(prefix='joysol-test-'))
    salt = os.urandom(16).hex()
    secrets = {'username': 'test', 'salt': salt, 'api_secret': 'x' * 40, 'origin_guard': 'g' * 64,
               'password_hash': hashlib.pbkdf2_hmac('sha256', PASSWORD.encode(), bytes.fromhex(salt), 600000).hex()}
    if users:
        secrets['users'] = [account(u, p) for u, p in users]
    (root / 'config.json').write_text(json.dumps(secrets))
    values = {
        'site': {'public_url': ORIGIN + '/', 'base_path': base_path},
        'paths': {'data_dir': str(root / 'data')},
        'singbox': {'config_path': str(HERE / 'fixtures/singbox.json')},
        'probes': {'enabled': False},
        'alerts': {'services': []},
    }
    if geo_dir:
        values['paths']['geo_dir'] = str(geo_dir)
    values = settings_mod.merge(values, extra or {})
    (root / 'settings.json').write_text(json.dumps(values))
    return root


def make_app(root, firewall=None):
    s = settings_mod.load(root / 'settings.json', root / 'config.json', environ={})
    app = create_app(s, firewall_runner=firewall or FakeFirewall(), start_workers=False)
    return app, app.extensions['joysol']


def cleanup(root):
    shutil.rmtree(root, ignore_errors=True)


def conn(cid='a', ip='8.8.8.8', up=0, down=0, domain='example.com', inbound='vless-esa-ws-in', outbound='direct',
         closed=False, rule='', port=50234):
    now = int(time.time() * 1000)
    source = '[%s]:%d' % (ip, port) if ':' in ip else '%s:%d' % (ip, port)
    return pb.Connection(id=cid, source=source, destination='1.1.1.1:443', domain=domain, network='tcp', protocol='tls',
                         inbound=inbound, inboundType='vless', createdAt=now, closedAt=now if closed else 0,
                         uplinkTotal=up, downlinkTotal=down, outbound=outbound, rule=rule, chainList=[outbound])


def event(kind, cid, connection=None, du=0, dd=0, closed_at=0):
    e = pb.ConnectionEvent(type=kind, id=cid, uplinkDelta=du, downlinkDelta=dd, closedAt=closed_at)
    if connection is not None:
        e.connection.CopyFrom(connection)
    return e


def batch(*events, reset=False):
    return pb.ConnectionEvents(events=list(events), reset=reset)


def login(client, base='/monitor'):
    r = client.post(base + '/login', data={'username': 'test', 'password': PASSWORD, 'remember': 'on'}, headers={'Origin': ORIGIN})
    assert r.status_code == 302, r.status_code
    return client.get(base + '/api/overview').get_json()['csrf'], r


def random_events(rng, count=300):
    """Plausible event stream: new, delta updates, snapshots, closes and occasional domain changes."""
    alive = {}
    events = []
    ips = ['8.8.8.8', '1.1.1.1', '2606:4700::1111', '9.9.9.9']
    for n in range(count):
        roll = rng.random()
        if roll < 0.25 or not alive:
            cid = 'c%d' % n
            alive[cid] = {'ip': rng.choice(ips), 'domain': rng.choice(['a.com', 'b.com', 'c.com']), 'up': 0, 'down': 0,
                          'inbound': rng.choice(['vless-esa-ws-in', 'vless-reality-in'])}
            c = alive[cid]
            events.append(event(pb.EVENT_NEW, cid, conn(cid, c['ip'], 0, 0, c['domain'], c['inbound'])))
        elif roll < 0.7:
            cid = rng.choice(list(alive))
            du, dd = rng.randint(0, 5000), rng.randint(0, 50000)
            alive[cid]['up'] += du
            alive[cid]['down'] += dd
            events.append(event(pb.EVENT_UPDATE, cid, du=du, dd=dd))
        elif roll < 0.8:
            cid = rng.choice(list(alive))
            c = alive[cid]
            if rng.random() < 0.3:
                c['domain'] = rng.choice(['a.com', 'b.com', 'd.com'])
            events.append(event(pb.EVENT_UPDATE, cid, conn(cid, c['ip'], c['up'], c['down'], c['domain'], c['inbound'])))
        else:
            cid = rng.choice(list(alive))
            c = alive.pop(cid)
            c['up'] += rng.randint(0, 100)
            events.append(event(pb.EVENT_CLOSED, cid, conn(cid, c['ip'], c['up'], c['down'], c['domain'], c['inbound'], closed=True)))
    return events


__all__ = ['account', 'make_env', 'make_app', 'cleanup', 'conn', 'event', 'batch', 'login', 'random_events', 'FakeFirewall',
           'ORIGIN', 'PASSWORD', 'pb', 'random']
