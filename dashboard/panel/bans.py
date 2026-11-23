"""Node access bans: single addresses or CIDR ranges, optional expiry.

Firewall rules only cover the public node ports (derived from sing-box inbounds, TCP or UDP),
never SSH or the panel. The CDN/WebSocket path is enforced by the Nginx auth_request gate.
"""
import ipaddress
import logging
import subprocess
import threading
import time

log = logging.getLogger(__name__)


def canonical(value, min_v4=16, min_v6=32):
    """Normalise an address or network; refuse private, reserved or overly broad ranges."""
    value = str(value or '').strip()
    if '/' in value:
        net = ipaddress.ip_network(value, strict=False)
        floor = min_v4 if net.version == 4 else min_v6
        if net.prefixlen < floor:
            raise ValueError('网段过大：IPv%d 最短 /%d' % (net.version, floor))
        if not net.network_address.is_global or not net.broadcast_address.is_global:
            raise ValueError('只允许封禁公网地址段')
        if net.prefixlen == net.max_prefixlen:
            return str(net.network_address)
        return str(net)
    ip = ipaddress.ip_address(value)
    if not ip.is_global:
        raise ValueError('只允许封禁公网地址')
    return str(ip)


class Firewall:
    def __init__(self, chain, endpoints_fn, run=None):
        self.chain = chain
        self.endpoints_fn = endpoints_fn
        self._run = run or self._exec

    @staticmethod
    def _exec(binary, args, check=True):
        return subprocess.run([binary, '-w', '5', *args], capture_output=True, check=check, timeout=10)

    def _binary(self, target):
        return '/usr/sbin/ip6tables' if ':' in target else '/usr/sbin/iptables'

    def ensure_jumps(self, binary):
        self._run(binary, ['-N', self.chain], False)
        wanted = set(self.endpoints_fn())
        listing = self._run(binary, ['-S', 'INPUT'], False)
        present = set()
        for line in (listing.stdout or b'').decode(errors='replace').splitlines():
            if ('-j ' + self.chain) in line and '--dport' in line and ' -p ' in line:
                proto = line.split(' -p ', 1)[1].split()[0]
                port = line.split('--dport', 1)[1].split()[0]
                if proto in ('tcp', 'udp') and port.isdigit():
                    present.add((proto, int(port)))
        for proto, port in sorted(wanted - present):
            self._run(binary, ['-I', 'INPUT', '1', '-p', proto, '--dport', str(port), '-j', self.chain])
        for proto, port in sorted(present - wanted):
            # Inbound moved or was removed; drop the stale jump.
            self._run(binary, ['-D', 'INPUT', '-p', proto, '--dport', str(port), '-j', self.chain], False)

    def _rules(self, target):
        # TCP gets a reset so clients fail fast; QUIC has no equivalent, so UDP is dropped.
        return {'tcp': [self.chain, '-p', 'tcp', '-s', target, '-j', 'REJECT', '--reject-with', 'tcp-reset'],
                'udp': [self.chain, '-p', 'udp', '-s', target, '-j', 'DROP']}

    def apply(self, target, ban):
        binary = self._binary(target)
        self.ensure_jumps(binary)
        protos = {proto for proto, _ in self.endpoints_fn()}
        for proto, rule in self._rules(target).items():
            exists = self._run(binary, ['-C', *rule], False).returncode == 0
            if ban and proto in protos and not exists:
                self._run(binary, ['-A', *rule])
            if not ban and exists:
                self._run(binary, ['-D', *rule])


class Bans:
    def __init__(self, store, firewall, settings):
        self.store = store
        self.firewall = firewall
        self.settings = settings
        self.lock = threading.Lock()
        self.exact = set()
        self.networks = []
        self.reload()

    def reload(self):
        rows = self.store.reader().execute('SELECT ip FROM bans').fetchall()
        exact, networks = set(), []
        for row in rows:
            if '/' in row['ip']:
                try:
                    networks.append(ipaddress.ip_network(row['ip']))
                except ValueError:
                    continue
            else:
                exact.add(row['ip'])
        with self.lock:
            self.exact, self.networks = exact, networks

    def is_banned(self, ip):
        with self.lock:
            if ip in self.exact:
                return True
            if not self.networks:
                return False
            networks = list(self.networks)
        try:
            address = ipaddress.ip_address(ip)
        except ValueError:
            return False
        return any(address.version == n.version and address in n for n in networks)

    def matches(self, target):
        """Predicate for live connections affected by a ban target."""
        if '/' in target:
            net = ipaddress.ip_network(target)

            def match(ip):
                try:
                    a = ipaddress.ip_address(ip)
                    return a.version == net.version and a in net
                except ValueError:
                    return False
            return match
        return lambda ip: ip == target

    def list(self):
        rows = [dict(r) for r in self.store.reader().execute('SELECT * FROM bans ORDER BY created DESC')]
        return rows

    def ban(self, target, reason='', duration=0, actor=''):
        target = canonical(target, self.settings.get('firewall.min_prefix_v4'), self.settings.get('firewall.min_prefix_v6'))
        expires = int(time.time()) + int(duration) if duration and int(duration) > 0 else 0
        self.firewall.apply(target, True)
        with self.store.write() as c:
            c.execute('INSERT OR REPLACE INTO bans(ip,reason,created,enforcement,expires) VALUES(?,?,?,?,?)',
                      (target, reason[:160], int(time.time()), 'node ports + CDN gateway', expires))
            c.execute('INSERT INTO audit VALUES(?,?,?,?)', (int(time.time()), 'ban', target, (reason or '')[:160] + (' · 到期 %d' % expires if expires else '')))
        self.reload()
        return target, expires

    def unban(self, target, actor='', reason='unban'):
        target = str(target).strip()
        self.firewall.apply(target, False)
        with self.store.write() as c:
            c.execute('DELETE FROM bans WHERE ip=?', (target,))
            c.execute('INSERT INTO audit VALUES(?,?,?,?)', (int(time.time()), reason, target, actor))
        self.reload()

    def enforce_all(self):
        for row in self.list():
            try:
                self.firewall.apply(row['ip'], True)
            except Exception:
                log.error('Ban reapply failed')

    def expire(self):
        now = int(time.time())
        due = [r['ip'] for r in self.store.reader().execute('SELECT ip FROM bans WHERE expires>0 AND expires<=?', (now,))]
        for target in due:
            try:
                self.unban(target, 'system', 'unban-expired')
            except Exception:
                log.error('Expired ban removal failed')
        return due
