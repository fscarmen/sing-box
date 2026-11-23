"""Persistent ledger: telemetry ingest with incremental rollups, and read queries."""
import ipaddress
import json
import threading
import time
from datetime import datetime, timezone

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover
    ZoneInfo = None

from . import db as dbm
from .proto import EVENT_CLOSED

RANGES = {'15m': 900, '1h': 3600, '6h': 21600, '24h': 86400, '7d': 604800, '30d': 2592000, '90d': 7776000}
HISTORY_SORT = {'ip', 'domain', 'protocol', 'inbound', 'outbounds', 'connections', 'upload', 'download', 'total',
                'last_seen', 'first_seen', 'online'}
GROUP_UPSERT = '''INSERT INTO history_groups(ip,domain,protocol,inbound,connections,upload,download,first_seen,last_seen,outbounds)
VALUES(?,?,?,?,?,?,?,?,?,?) ON CONFLICT(ip,domain,protocol,inbound) DO UPDATE SET
connections=connections+excluded.connections,upload=upload+excluded.upload,download=download+excluded.download,
first_seen=CASE WHEN excluded.first_seen>0 AND (first_seen=0 OR excluded.first_seen<first_seen) THEN excluded.first_seen ELSE first_seen END,
last_seen=MAX(last_seen,excluded.last_seen),
outbounds=CASE WHEN excluded.outbounds='' OR instr(','||outbounds||',',','||excluded.outbounds||',')>0 THEN outbounds
 WHEN outbounds='' THEN excluded.outbounds ELSE outbounds||','||excluded.outbounds END'''
IP_UPSERT = '''INSERT INTO ip_totals(ip,connections,upload,download,first_seen,last_seen) VALUES(?,?,?,?,?,?)
ON CONFLICT(ip) DO UPDATE SET connections=connections+excluded.connections,upload=upload+excluded.upload,
download=download+excluded.download,
first_seen=CASE WHEN excluded.first_seen>0 AND (first_seen=0 OR excluded.first_seen<first_seen) THEN excluded.first_seen ELSE first_seen END,
last_seen=MAX(last_seen,excluded.last_seen)'''
SERIES_UPSERT = '''INSERT INTO %s(ts,ip,inbound,outbound,upload,download) VALUES(?,?,?,?,?,?)
ON CONFLICT(ts,ip,inbound,outbound) DO UPDATE SET upload=upload+excluded.upload,download=download+excluded.download'''


def source_ip(source):
    try:
        return str(ipaddress.ip_address(source))
    except ValueError:
        pass
    try:
        return str(ipaddress.ip_address(source.rsplit(':', 1)[0].strip('[]')))
    except ValueError:
        return 'unknown'


def now_ms():
    return int(time.time() * 1000)


class Store:
    def __init__(self, settings, live, is_banned=lambda ip: False, on_banned=None):
        self.settings = settings
        self.path = settings.data_dir / 'stats.sqlite3'
        self.live = live
        self.is_banned = is_banned
        self.on_banned = on_banned
        self.lock = threading.RLock()
        self.tz = ZoneInfo(settings.get('site.timezone')) if ZoneInfo else timezone.utc
        settings.data_dir.mkdir(parents=True, exist_ok=True)
        self.migrations = dbm.migrate(self.path)
        self.writer = dbm.connect(self.path)
        self.local = threading.local()

    # -- connections -------------------------------------------------------------------
    def reader(self):
        c = getattr(self.local, 'c', None)
        if c is None:
            c = dbm.connect(self.path)
            self.local.c = c
        return c

    def write(self):
        """Serialised writer transaction for management actions."""
        return _Locked(self.lock, self.writer)

    def day(self, ts=None):
        moment = datetime.fromtimestamp(ts or time.time(), timezone.utc).astimezone(self.tz)
        return moment.strftime('%Y-%m-%d')

    def day_start(self, ts=None):
        """Unix time of local midnight (site timezone) for the day containing ts."""
        moment = datetime.fromtimestamp(ts or time.time(), timezone.utc).astimezone(self.tz)
        return int(moment.replace(hour=0, minute=0, second=0, microsecond=0).timestamp())

    def meta(self, key, default=None):
        row = self.reader().execute('SELECT value FROM meta WHERE key=?', (key,)).fetchone()
        return row[0] if row else default

    # -- ingest ---------------------------------------------------------------------------
    def ingest(self, batch):
        now = now_ms()
        now_s = now // 1000
        minute, hour = now_s // 60 * 60, now_s // 3600 * 3600
        day = self.day(now_s)
        deltas, banned = [], []
        c = self.writer
        with self.lock, dbm.tx(c):
            if batch.reset:
                c.execute('UPDATE connections SET active=0 WHERE active=1')
                self.live.reset()
            for e in batch.events:
                row = c.execute('SELECT ip,domain,protocol,inbound,outbound,upload,download FROM connections WHERE id=?', (e.id,)).fetchone()
                before_up = row['upload'] if row else 0
                before_down = row['download'] if row else 0
                if e.HasField('connection'):
                    x = e.connection
                    ip = source_ip(x.source)
                    domain = (x.domain or x.destination or '未知').lower().rstrip('.')
                    protocol = '/'.join(filter(None, [x.network, x.protocol])) or '未知'
                    inbound = (x.inboundType + '/' + x.inbound).strip('/')
                    outbound = x.outbound
                    ended = x.closedAt or e.closedAt
                    closed = bool(ended) or e.type == EVENT_CLOSED
                    # Cumulative counters are upserted, never added: replay must not double count.
                    up = max(0, x.uplinkTotal, before_up)
                    down = max(0, x.downlinkTotal, before_down)
                    started = x.createdAt or now
                    chain = ','.join(x.chainList)
                    rule = x.rule[:300]
                    c.execute('''INSERT INTO connections(id,ip,domain,protocol,inbound,outbound,started,ended,upload,download,seen,active,rule,chain,destination,user,outbound_type)
VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET domain=excluded.domain,protocol=excluded.protocol,
outbound=excluded.outbound,ended=excluded.ended,upload=excluded.upload,download=excluded.download,seen=excluded.seen,
active=excluded.active,rule=excluded.rule,chain=excluded.chain,destination=excluded.destination,user=excluded.user,
outbound_type=excluded.outbound_type''', (e.id, ip, domain, protocol, inbound, outbound, started, ended, up, down, now,
                                          0 if closed else 1, rule, chain, x.destination, x.user, x.outboundType))
                    key = (ip, domain, protocol, inbound)
                    if row is None:
                        c.execute(GROUP_UPSERT, key + (1, up, down, started, now, outbound))
                        c.execute(IP_UPSERT, (ip, 1, up, down, started, now))
                    else:
                        old = (row['ip'], row['domain'], row['protocol'], row['inbound'])
                        if old != key:
                            c.execute(GROUP_UPSERT, old + (-1, -before_up, -before_down, 0, 0, ''))
                            c.execute('DELETE FROM history_groups WHERE ip=? AND domain=? AND protocol=? AND inbound=? AND connections<=0 AND upload<=0 AND download<=0', old)
                            c.execute(GROUP_UPSERT, key + (1, up, down, started, now, outbound))
                        else:
                            c.execute(GROUP_UPSERT, key + (0, up - before_up, down - before_down, 0, now, outbound))
                        c.execute(IP_UPSERT, (ip, 0, up - before_up, down - before_down, 0, now))
                    if closed:
                        self.live.close(e.id)
                    else:
                        self.live.upsert(e.id, {'ip': ip, 'domain': domain, 'destination': x.destination, 'protocol': protocol,
                                                'inbound': inbound, 'outbound': outbound, 'rule': rule, 'chain': chain,
                                                'started': started, 'up': up, 'down': down})
                elif row:
                    ip, inbound, outbound = row['ip'], row['inbound'], row['outbound']
                    up = before_up + max(0, e.uplinkDelta)
                    down = before_down + max(0, e.downlinkDelta)
                    closed = e.type == EVENT_CLOSED
                    c.execute('UPDATE connections SET upload=?,download=?,ended=?,active=?,seen=? WHERE id=?',
                              (up, down, e.closedAt, 0 if closed else 1, now, e.id))
                    key = (ip, row['domain'], row['protocol'], inbound)
                    c.execute(GROUP_UPSERT, key + (0, up - before_up, down - before_down, 0, now, ''))
                    c.execute(IP_UPSERT, (ip, 0, up - before_up, down - before_down, 0, now))
                    if closed:
                        self.live.close(e.id)
                    else:
                        self.live.upsert(e.id, {'up': up, 'down': down})
                else:
                    continue
                du, dd = max(0, up - before_up), max(0, down - before_down)
                if du or dd:
                    c.execute('INSERT INTO daily VALUES(?,?,?,?) ON CONFLICT(day,ip) DO UPDATE SET upload=upload+excluded.upload,download=download+excluded.download', (day, ip, du, dd))
                    c.execute(SERIES_UPSERT % 'series_minute', (minute, ip, inbound, outbound, du, dd))
                    c.execute(SERIES_UPSERT % 'series_hour', (hour, ip, inbound, outbound, du, dd))
                    deltas.append((e.id, ip, inbound, outbound, du, dd))
                if not closed and self.is_banned(ip):
                    banned.append(e.id)
        self.live.apply(deltas, now)
        if banned and self.on_banned:
            self.on_banned(banned)
        return len(deltas)

    def collector_lost(self):
        with self.lock, dbm.tx(self.writer) as c:
            c.execute('UPDATE connections SET active=0 WHERE active=1')
        self.live.reset()

    # -- read side --------------------------------------------------------------------------
    def totals(self):
        c = self.reader()
        row = c.execute('SELECT COALESCE(SUM(upload),0) up,COALESCE(SUM(download),0) down,COALESCE(SUM(connections),0) n,COUNT(*) ips FROM ip_totals').fetchone()
        today = c.execute('SELECT COALESCE(SUM(upload),0) up,COALESCE(SUM(download),0) down FROM daily WHERE day=?', (self.day(),)).fetchone()
        return {'upload': row['up'], 'download': row['down'], 'connections': row['n'], 'ips': row['ips'],
                'today_upload': today['up'], 'today_download': today['down'],
                'tracking_since': int(self.meta('tracking_since', '0')), 'series_since': int(self.meta('series_since', '0') or 0)}

    def ip_totals(self):
        return [dict(r) for r in self.reader().execute('SELECT * FROM ip_totals')]

    def history(self, ip='', q='', since='all', sort='last_seen', direction='desc', limit=100, offset=0, online=None):
        sort = sort if sort in HISTORY_SORT else 'last_seen'
        direction = 'ASC' if direction == 'asc' else 'DESC'
        limit = max(1, min(int(limit), 2000))
        offset = max(0, int(offset))
        where, args = [], []
        cutoff = RANGES.get(since)
        if cutoff:
            where.append('seen>=?')
            args.append(now_ms() - cutoff * 1000)
        if ip:
            where.append('ip=?')
            args.append(ip)
        if cutoff:
            # Window = connections active in range; their full cumulative traffic is shown.
            source = ('SELECT ip,domain,protocol,inbound,COUNT(*) connections,SUM(upload) upload,SUM(download) download,'
                      'MIN(started) first_seen,MAX(seen) last_seen,GROUP_CONCAT(DISTINCT outbound) outbounds FROM connections'
                      + (' WHERE ' + ' AND '.join(where) if where else '') + ' GROUP BY ip,domain,protocol,inbound')
            inner_args = args
        else:
            source = 'SELECT * FROM history_groups' + (' WHERE ' + ' AND '.join(where) if where else '')
            inner_args = args
        outer, outer_args = [], []
        if q:
            like = '%' + q.lower().replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_') + '%'
            outer.append("(lower(ip) LIKE ? ESCAPE '\\' OR lower(domain) LIKE ? ESCAPE '\\' OR lower(protocol) LIKE ? ESCAPE '\\' OR lower(inbound) LIKE ? ESCAPE '\\' OR lower(outbounds) LIKE ? ESCAPE '\\')")
            outer_args += [like] * 5
        base = 'SELECT *,upload+download total FROM (' + source + ')' + (' WHERE ' + ' AND '.join(outer) if outer else '')
        c = self.reader()
        total = c.execute('SELECT COUNT(*) FROM (' + base + ')', inner_args + outer_args).fetchone()[0]
        if sort == 'online':
            rows = [dict(r) for r in c.execute(base, inner_args + outer_args)]
            for r in rows:
                r['online'] = (online or {}).get((r['ip'], r['domain'], r['protocol'], r['inbound']), 0)
            rows.sort(key=lambda r: (r['online'], r['last_seen']), reverse=direction == 'DESC')
            rows = rows[offset:offset + limit]
        else:
            rows = [dict(r) for r in c.execute(base + ' ORDER BY %s %s, last_seen DESC LIMIT ? OFFSET ?' % (sort, direction),
                                               inner_args + outer_args + [limit, offset])]
            for r in rows:
                r['online'] = (online or {}).get((r['ip'], r['domain'], r['protocol'], r['inbound']), 0)
        return {'rows': rows, 'total': total, 'limit': limit, 'offset': offset}

    def daily(self, days=30, ip=''):
        c = self.reader()
        days = max(1, min(int(days), 400))
        totals = [dict(r) for r in c.execute('SELECT day,SUM(upload) upload,SUM(download) download,COUNT(*) ips FROM daily GROUP BY day ORDER BY day DESC LIMIT ?', (days,))]
        wanted = [r['day'] for r in totals]
        if not wanted:
            return {'days': [], 'rows': []}
        marks = ','.join('?' * len(wanted))
        args = list(wanted)
        sql = 'SELECT day,ip,upload,download FROM daily WHERE day IN (%s)' % marks
        if ip:
            sql += ' AND ip=?'
            args.append(ip)
        rows = [dict(r) for r in c.execute(sql + ' ORDER BY day DESC,upload+download DESC', args)]
        return {'days': totals, 'rows': rows}

    def series(self, span='24h', by='', ip=''):
        seconds = RANGES.get(span, 86400)
        end = int(time.time())
        start = end - seconds
        if seconds <= 21600:
            table, step = 'series_minute', 60
        elif seconds <= 86400:
            table, step = 'series_minute', 300
        elif seconds <= 2592000:
            table, step = 'series_hour', 3600
        else:
            table, step = 'series_hour', 21600
        group = {'outbound': 'outbound', 'inbound': 'inbound', 'ip': 'ip'}.get(by)
        offset = int(datetime.now(self.tz).utcoffset().total_seconds()) if step >= 21600 else 0
        bucket = '((ts+%d)/%d)*%d-%d' % (offset, step, step, offset)
        where, args = ['ts>=?'], [((start + offset) // step) * step - offset]
        if ip:
            where.append('ip=?')
            args.append(ip)
        sql = 'SELECT %s b,%s k,SUM(upload) u,SUM(download) d FROM %s WHERE %s GROUP BY 1,2 ORDER BY 1' % (
            bucket, group or "''", table, ' AND '.join(where))
        first = ((start + offset) // step) * step - offset
        buckets = list(range(first, end + 1, step))
        index = {b: i for i, b in enumerate(buckets)}
        series = {}
        for r in self.reader().execute(sql, args):
            pos = index.get(r['b'])
            if pos is None:
                pos = min(len(buckets) - 1, max(0, (r['b'] - first) // step))
            entry = series.setdefault(r['k'] or 'total', {'key': r['k'] or 'total', 'up': [0] * len(buckets), 'down': [0] * len(buckets)})
            entry['up'][pos] += r['u']
            entry['down'][pos] += r['d']
        return {'step': step, 'buckets': buckets, 'series': sorted(series.values(), key=lambda s: -sum(s['up']) - sum(s['down'])),
                'source': table, 'series_since': int(self.meta('series_since', '0') or 0),
                'estimated_before': int(self.meta('series_estimated_before', '0') or 0)}

    def top(self, span='24h', by='domain', limit=10, ip='', outbound=''):
        by = by if by in ('domain', 'ip', 'inbound', 'outbound', 'rule', 'protocol') else 'domain'
        limit = max(1, min(int(limit), 100))
        seconds = RANGES.get(span)
        args = []
        if seconds or outbound or by in ('rule', 'outbound'):
            where = ['seen>=?'] if seconds else []
            args = [now_ms() - seconds * 1000] if seconds else []
            if ip:
                where.append('ip=?')
                args.append(ip)
            if outbound:
                where.append('outbound=?')
                args.append(outbound)
            sql = ('SELECT %s k,COUNT(*) connections,SUM(upload) upload,SUM(download) download FROM connections%s '
                   'GROUP BY 1 ORDER BY SUM(upload+download) DESC LIMIT ?') % (by, ' WHERE ' + ' AND '.join(where) if where else '')
        else:
            where = ' WHERE ip=?' if ip else ''
            args = [ip] if ip else []
            sql = ('SELECT %s k,SUM(connections) connections,SUM(upload) upload,SUM(download) download FROM history_groups%s '
                   'GROUP BY 1 ORDER BY SUM(upload+download) DESC LIMIT ?') % (by, where)
        return [dict(r) for r in self.reader().execute(sql, args + [limit])]

    def flows(self, span='24h'):
        seconds = RANGES.get(span, 86400)
        sql = ('SELECT ip,inbound,rule,outbound,COUNT(*) connections,SUM(upload) upload,SUM(download) download '
               'FROM connections WHERE seen>=? GROUP BY 1,2,3,4')
        return [dict(r) for r in self.reader().execute(sql, (now_ms() - seconds * 1000,))]

    def bytes_by_ip(self, span):
        seconds = RANGES.get(span)
        if not seconds:
            return {r['ip']: r['upload'] + r['download'] for r in self.reader().execute('SELECT ip,upload,download FROM ip_totals')}
        rows = self.reader().execute('SELECT ip,SUM(upload+download) b FROM series_hour WHERE ts>=? GROUP BY ip', (int(time.time()) - seconds,))
        return {r['ip']: r['b'] for r in rows}

    def audit(self, limit=100, offset=0, action=''):
        sql = 'SELECT rowid id,* FROM audit' + (' WHERE action=?' if action else '') + ' ORDER BY at DESC LIMIT ? OFFSET ?'
        args = ([action] if action else []) + [max(1, min(int(limit), 500)), max(0, int(offset))]
        total = self.reader().execute('SELECT COUNT(*) FROM audit' + (' WHERE action=?' if action else ''), [action] if action else []).fetchone()[0]
        return {'rows': [dict(r) for r in self.reader().execute(sql, args)], 'total': total}

    def record(self, action, ip='', detail=''):
        with self.write() as c:
            c.execute('INSERT INTO audit VALUES(?,?,?,?)', (int(time.time()), action, ip, detail[:300]))

    def prefs(self):
        return {r['key']: json.loads(r['value']) for r in self.reader().execute('SELECT key,value FROM prefs')}

    def set_pref(self, key, value):
        with self.write() as c:
            if value is None:
                c.execute('DELETE FROM prefs WHERE key=?', (key,))
            else:
                c.execute('INSERT OR REPLACE INTO prefs VALUES(?,?)', (key, json.dumps(value)))

    def size(self):
        total = 0
        for suffix in ('', '-wal', '-shm'):
            try:
                total += (self.path.parent / (self.path.name + suffix)).stat().st_size
            except OSError:
                pass
        return total


class _Locked:
    def __init__(self, lock, c):
        self.lock, self.c, self.t = lock, c, None

    def __enter__(self):
        self.lock.acquire()
        self.t = dbm.tx(self.c)
        try:
            return self.t.__enter__()
        except Exception:
            self.lock.release()
            raise

    def __exit__(self, kind, value, trace):
        try:
            return self.t.__exit__(kind, value, trace)
        finally:
            self.lock.release()
