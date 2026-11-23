"""Host network view: interface byte counters (/proc/net/dev) and TCP path quality sampled with `ss -ti`.

Interface totals are what the VPS actually sends and receives (protocol overhead, both proxy legs, SSH,
panel), as opposed to the proxy payload sing-box reports. Path quality is grouped by segment:

- client:   public proxy inbounds (TCP to the client itself; only direct entries, a CDN terminates TCP)
- edge:     CDN edge to origin (the TLS origin port behind the CDN)
- upstream: sing-box to an upstream proxy outbound (residential exits etc.)
- direct:   sing-box straight to destinations

Nothing here hard-codes ports or addresses: they come from the topology and settings.
"""
import ipaddress
import json
import logging
import re
import socket
import subprocess
import threading
import time
from collections import deque


log = logging.getLogger(__name__)
SEGMENTS = ('client', 'edge', 'upstream', 'direct')
NIC_UPSERT = 'INSERT INTO %s(ts,iface,rx,tx) VALUES(?,?,?,?) ON CONFLICT(ts,iface) DO UPDATE SET rx=rx+excluded.rx,tx=tx+excluded.tx'
_FIELD = re.compile(r'\b(rtt|minrtt|bytes_sent|bytes_retrans):([0-9.]+)(?:/([0-9.]+))?')


def _read(path):
    try:
        with open(path) as handle:
            return handle.read()
    except OSError:
        return ''


def parse_net_dev(text):
    """{iface: (rx_bytes, tx_bytes)} from /proc/net/dev."""
    out = {}
    for line in text.splitlines()[2:]:
        if ':' not in line:
            continue
        name, data = line.split(':', 1)
        fields = data.split()
        if len(fields) >= 9:
            out[name.strip()] = (int(fields[0]), int(fields[8]))
    return out


def default_interfaces(route_text):
    """Interfaces carrying an IPv4 default route (/proc/net/route)."""
    found = []
    for line in route_text.splitlines()[1:]:
        fields = line.split()
        if len(fields) > 2 and fields[1] == '00000000' and fields[0] not in found:
            found.append(fields[0])
    return found


def _address(text):
    """('192.0.2.1', 443) from ss address forms: 192.0.2.1:443, [::ffff:192.0.2.1]:443, [2001::1]:443."""
    host, _, port = text.rpartition(':')
    host = host.strip('[]').split('%')[0]
    try:
        addr = ipaddress.ip_address(host)
        port = int(port)
    except ValueError:
        return None
    if addr.version == 6 and addr.ipv4_mapped:
        addr = addr.ipv4_mapped
    return addr, port


def parse_ss(text):
    """Established TCP sockets from `ss -tinH state established`: dicts with local, peer and tcp_info fields."""
    sockets = []
    current = None
    for line in text.splitlines():
        if not line.strip():
            continue
        if not line[0].isspace():
            fields = line.split()
            # Recv-Q Send-Q Local Peer [Process]
            if len(fields) < 4:
                current = None
                continue
            local, peer = _address(fields[2]), _address(fields[3])
            current = {'local': local, 'peer': peer} if local and peer else None
            if current:
                sockets.append(current)
        elif current is not None:
            for name, first, _second in _FIELD.findall(line):
                current[name] = float(first)
    return sockets


def _percentile(values, fraction):
    ordered = sorted(values)
    if not ordered:
        return None
    pos = (len(ordered) - 1) * fraction
    low = int(pos)
    high = min(low + 1, len(ordered) - 1)
    return ordered[low] + (ordered[high] - ordered[low]) * (pos - low)


class Nic:
    """Per-second interface rates in memory; minute/hour byte totals in the ledger.

    The last persisted counters are kept with the boot id, so bytes sent while the panel was
    restarting are still counted on the next start (counters only reset on reboot).
    """

    def __init__(self, settings, store):
        self.settings = settings
        self.store = store
        self.lock = threading.Lock()
        self.samples = deque(maxlen=max(60, int(settings.get('live.history_seconds'))))
        self.previous = None
        self.pending = {}
        self.minute = None
        self.boot = _read(settings.get('network.boot_id_path')).strip()
        self._restore()

    def interfaces(self):
        configured = self.settings.get('network.interfaces') or []
        if configured:
            return list(configured)
        found = default_interfaces(_read(self.settings.get('network.proc_route')))
        return found or [n for n in parse_net_dev(_read(self.settings.get('network.proc_net_dev'))) if n != 'lo']

    def _counters(self):
        names = set(self.interfaces())
        return {k: v for k, v in parse_net_dev(_read(self.settings.get('network.proc_net_dev'))).items() if k in names}

    def _restore(self):
        counters = self._counters()
        try:
            saved = json.loads(self.store.meta('nic_last', '') or '{}')
        except ValueError:
            saved = {}
        if saved.get('boot') == self.boot and self.boot:
            now = int(time.time())
            for name, (rx, tx) in counters.items():
                old = saved.get('counters', {}).get(name)
                if old and rx >= old[0] and tx >= old[1]:
                    self._add(now, name, rx - old[0], tx - old[1])
        self.previous = (time.time(), counters)
        self.minute = int(time.time()) // 60 * 60
        if self.pending:
            self.flush(counters)
        elif not saved:
            self._save(counters)

    def _add(self, ts, name, rx, tx):
        key = (ts // 60 * 60, name)
        entry = self.pending.setdefault(key, [0, 0])
        entry[0] += rx
        entry[1] += tx

    def sample(self, now=None):
        """Read counters once; called every second by the ticker."""
        now = now or time.time()
        counters = self._counters()
        with self.lock:
            if self.previous is None:
                self.previous = (now, counters)
                return
            then, before = self.previous
            elapsed = max(0.2, now - then)
            rx = tx = 0
            for name, (r, t) in counters.items():
                old = before.get(name)
                if not old or r < old[0] or t < old[1]:
                    continue
                self._add(int(now), name, r - old[0], t - old[1])
                rx += r - old[0]
                tx += t - old[1]
            self.previous = (now, counters)
            self.samples.append({'t': int(now * 1000), 'rx': rx / elapsed, 'tx': tx / elapsed})
            minute = int(now) // 60 * 60
            rolled = minute != self.minute
            self.minute = minute
        if rolled:
            self.flush(counters)

    def flush(self, counters=None):
        with self.lock:
            pending, self.pending = self.pending, {}
            counters = counters if counters is not None else self.previous[1]
        self._save(counters, pending)

    def _save(self, counters, pending=None):
        # Buckets and the counters they were measured up to commit together, so a restart neither loses nor repeats bytes.
        with self.store.write() as c:
            for (minute, name), (rx, tx) in (pending or {}).items():
                c.execute(NIC_UPSERT % 'nic_minute', (minute, name, rx, tx))
                c.execute(NIC_UPSERT % 'nic_hour', (minute // 3600 * 3600, name, rx, tx))
            c.execute("INSERT OR REPLACE INTO meta VALUES('nic_last',?)",
                      (json.dumps({'boot': self.boot, 'counters': counters, 'at': int(time.time())}),))
            c.execute("INSERT OR IGNORE INTO meta VALUES('nic_since',?)", (str(int(time.time())),))

    def current(self):
        with self.lock:
            last = self.samples[-1] if self.samples else None
        if not last or time.time() * 1000 - last['t'] > 3500:
            return {'rx': 0, 'tx': 0}
        return {'rx': round(last['rx']), 'tx': round(last['tx'])}

    def series_live(self, seconds=300):
        cutoff = time.time() * 1000 - seconds * 1000
        with self.lock:
            return [{'t': s['t'], 'rx': round(s['rx']), 'tx': round(s['tx'])} for s in self.samples if s['t'] >= cutoff]


class Quality:
    """Periodic `ss -ti` sample; retransmissions are counted per interval from each socket's counters."""

    def __init__(self, settings, store, topology, runner=None):
        self.settings = settings
        self.store = store
        self.topology = topology
        self.runner = runner or self._ss
        self.last_run = 0
        self.previous = {}
        self.latest = {'at': 0, 'segments': {}, 'keys': [], 'error': ''}
        self._upstreams = (0, {})

    @staticmethod
    def _ss():
        out = subprocess.run(['ss', '-tinH', 'state', 'established'], capture_output=True, timeout=10)
        if out.returncode != 0:
            raise RuntimeError(out.stderr.decode(errors='replace').strip()[:200] or 'ss failed')
        return out.stdout.decode(errors='replace')

    def due(self):
        if not self.settings.get('network.quality_enabled'):
            return False
        return time.time() - self.last_run >= int(self.settings.get('network.quality_interval_seconds'))

    def upstreams(self):
        """{(address, port): outbound tag} for proxy outbounds, resolved at most every 10 minutes."""
        at, cached = self._upstreams
        if time.time() - at < 600 and cached:
            return cached
        found = {}
        for item in self.topology.describe()['outbounds']:
            if not item.get('server') or not item.get('port') or item['type'] == 'direct':
                continue
            try:
                infos = socket.getaddrinfo(item['server'], int(item['port']), proto=socket.IPPROTO_TCP)
            except (OSError, ValueError):
                continue
            for info in infos:
                addr = ipaddress.ip_address(info[4][0].split('%')[0])
                found[(addr, int(item['port']))] = item['tag']
        self._upstreams = (time.time(), found)
        return found

    def _ephemeral(self):
        text = _read(self.settings.get('network.port_range_path')).split()
        try:
            return int(text[0]), int(text[1])
        except (IndexError, ValueError):
            return 32768, 60999

    def classify(self, sock, public, edge, upstreams, ephemeral):
        local_addr, local_port = sock['local']
        peer_addr, peer_port = sock['peer']
        if peer_addr.is_loopback or local_addr.is_loopback:
            return None
        if local_port in public:
            return 'client', str(peer_addr)
        if local_port in edge:
            return 'edge', 'edge'
        tag = upstreams.get((peer_addr, peer_port))
        if tag:
            return 'upstream', tag
        # Outgoing: our ephemeral port to a service port. Inbound SSH etc. have an ephemeral peer port instead.
        if ephemeral[0] <= local_port <= ephemeral[1] and peer_port < ephemeral[0]:
            return 'direct', 'direct'
        return None

    def run(self, now=None):
        now = int(now or time.time())
        self.last_run = now
        try:
            sockets = parse_ss(self.runner())
        except Exception as exc:
            self.latest = {**self.latest, 'error': type(exc).__name__ + ': ' + str(exc)[:160]}
            return self.latest
        public = set(self.topology.public_ports())
        edge = {int(p) for p in (self.settings.get('network.edge_ports') or [])}
        upstreams = self.upstreams()
        ephemeral = self._ephemeral()
        groups = {}
        seen = {}
        for sock in sockets:
            if 'rtt' not in sock:
                continue
            where = self.classify(sock, public, edge, upstreams, ephemeral)
            if not where:
                continue
            ident = (sock['local'], sock['peer'])
            sent, retrans = int(sock.get('bytes_sent', 0)), int(sock.get('bytes_retrans', 0))
            seen[ident] = (sent, retrans)
            old = self.previous.get(ident)
            if old and sent >= old[0] and retrans >= old[1]:
                sent, retrans = sent - old[0], retrans - old[1]
            g = groups.setdefault(where, {'rtt': [], 'min': [], 'sent': 0, 'retrans': 0})
            g['rtt'].append(sock['rtt'])
            g['min'].append(sock.get('minrtt', sock['rtt']))
            g['sent'] += sent
            g['retrans'] += retrans
        self.previous = seen
        rows = []
        for (segment, key), g in groups.items():
            rows.append((now, segment, key, len(g['rtt']), round(_percentile(g['rtt'], 0.5), 2),
                         round(_percentile(g['rtt'], 0.9), 2), round(min(g['min']), 2), g['sent'], g['retrans']))
        with self.store.write() as c:
            c.executemany('INSERT OR REPLACE INTO quality VALUES(?,?,?,?,?,?,?,?,?)', rows)
        self.latest = {'at': now, 'error': '', 'keys': [_row(r) for r in rows], 'segments': _summarise(rows)}
        return self.latest


def _row(r):
    ts, segment, key, conns, rtt, p90, low, sent, retrans = r
    return {'segment': segment, 'key': key, 'conns': conns, 'rtt': rtt, 'rtt_p90': p90, 'min_rtt': low,
            'sent': sent, 'retrans': retrans, 'retrans_pct': round(retrans * 100 / sent, 3) if sent else 0}


def _summarise(rows):
    out = {}
    for segment in SEGMENTS:
        mine = [r for r in rows if r[1] == segment]
        if not mine:
            continue
        sent, retrans = sum(r[7] for r in mine), sum(r[8] for r in mine)
        weights = sum(r[3] for r in mine)
        out[segment] = {'keys': len(mine), 'conns': weights,
                        'rtt': round(sum(r[4] * r[3] for r in mine) / weights, 2),
                        'rtt_p90': round(max(r[5] for r in mine), 2),
                        'retrans_pct': round(retrans * 100 / sent, 3) if sent else 0, 'sent': sent}
    return out


class NetworkQueries:
    """Read side for /api/network."""

    STEPS = ((21600, 'nic_minute', 60), (86400, 'nic_minute', 300), (604800, 'nic_hour', 3600), (2592000, 'nic_hour', 3600))

    def __init__(self, store):
        self.store = store

    def _plan(self, seconds):
        for limit, table, step in self.STEPS:
            if seconds <= limit:
                return table, step
        return 'nic_hour', 21600

    def traffic(self, seconds):
        """NIC rx/tx per bucket beside the proxy payload (both directions) for the same buckets."""
        table, step = self._plan(seconds)
        end = int(time.time())
        first = (end - seconds) // step * step
        buckets = list(range(first, end + 1, step))
        index = {b: i for i, b in enumerate(buckets)}
        rx, tx, payload = [0] * len(buckets), [0] * len(buckets), [0] * len(buckets)
        c = self.store.reader()
        for r in c.execute('SELECT (ts/%d)*%d b,SUM(rx) rx,SUM(tx) tx FROM %s WHERE ts>=? GROUP BY 1' % (step, step, table), (first,)):
            pos = index.get(r['b'])
            if pos is not None:
                rx[pos], tx[pos] = r['rx'], r['tx']
        series = 'series_minute' if table == 'nic_minute' else 'series_hour'
        for r in c.execute('SELECT (ts/%d)*%d b,SUM(upload+download) p FROM %s WHERE ts>=? GROUP BY 1' % (step, step, series), (first,)):
            pos = index.get(r['b'])
            if pos is not None:
                payload[pos] = r['p']
        return {'step': step, 'buckets': buckets, 'rx': rx, 'tx': tx, 'payload': payload}

    def totals(self, since):
        # Minute resolution so a period starting mid-hour (e.g. when counting began) compares like with like.
        # Older periods fall back to hours (minute rows are pruned after a few days).
        c = self.store.reader()
        recent = since >= time.time() - 5 * 86400
        start = since // 60 * 60 if recent else since // 3600 * 3600
        nic_table, series_table = ('nic_minute', 'series_minute') if recent else ('nic_hour', 'series_hour')
        nic = c.execute('SELECT COALESCE(SUM(rx),0) rx,COALESCE(SUM(tx),0) tx FROM %s WHERE ts>=?' % nic_table, (start,)).fetchone()
        payload = c.execute('SELECT COALESCE(SUM(upload+download),0) FROM %s WHERE ts>=?' % series_table, (start,)).fetchone()[0]
        return {'rx': nic['rx'], 'tx': nic['tx'], 'payload': payload}

    def quality_series(self, seconds):
        step = 60 if seconds <= 21600 else 300 if seconds <= 86400 else 3600 if seconds <= 604800 else 10800
        end = int(time.time())
        first = (end - seconds) // step * step
        buckets = list(range(first, end + 1, step))
        index = {b: i for i, b in enumerate(buckets)}
        out = {}
        sql = ('SELECT (ts/%d)*%d b,segment,SUM(rtt*conns)/SUM(conns) rtt,SUM(sent) sent,SUM(retrans) retrans '
               'FROM quality WHERE ts>=? GROUP BY 1,2') % (step, step)
        for r in self.store.reader().execute(sql, (first,)):
            pos = index.get(r['b'])
            if pos is None:
                continue
            entry = out.setdefault(r['segment'], {'rtt': [None] * len(buckets), 'retrans_pct': [None] * len(buckets)})
            entry['rtt'][pos] = round(r['rtt'], 1)
            entry['retrans_pct'][pos] = round(r['retrans'] * 100 / r['sent'], 3) if r['sent'] else 0
        return {'step': step, 'buckets': buckets, 'segments': out}

    def quality_keys(self, seconds, segment=''):
        where, args = ['ts>=?'], [int(time.time()) - seconds]
        if segment:
            where.append('segment=?')
            args.append(segment)
        sql = ('SELECT segment,key,COUNT(*) samples,MAX(conns) peak_conns,SUM(rtt*conns)/SUM(conns) rtt,'
               'AVG(rtt_p90) rtt_p90,MIN(min_rtt) min_rtt,SUM(sent) sent,SUM(retrans) retrans,MAX(ts) last '
               'FROM quality WHERE %s GROUP BY 1,2 ORDER BY SUM(sent) DESC LIMIT 500') % ' AND '.join(where)
        rows = []
        for r in self.store.reader().execute(sql, args):
            row = dict(r)
            row['rtt'] = round(row['rtt'] or 0, 1)
            row['rtt_p90'] = round(row['rtt_p90'] or 0, 1)
            row['retrans_pct'] = round(row['retrans'] * 100 / row['sent'], 3) if row['sent'] else 0
            rows.append(row)
        return rows

    def prune(self, quality_days, minute_days):
        now = int(time.time())
        with self.store.write() as c:
            c.execute('DELETE FROM quality WHERE ts<?', (now - quality_days * 86400,))
            c.execute('DELETE FROM nic_minute WHERE ts<?', (now - minute_days * 86400,))
