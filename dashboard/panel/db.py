"""SQLite access and versioned, additive schema migrations."""
import os
import sqlite3
import time

SCHEMA_V1 = '''
CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY,value TEXT);
CREATE TABLE IF NOT EXISTS connections(id TEXT PRIMARY KEY,ip TEXT NOT NULL,domain TEXT NOT NULL,protocol TEXT NOT NULL,inbound TEXT NOT NULL,outbound TEXT NOT NULL,started INTEGER NOT NULL,ended INTEGER DEFAULT 0,upload INTEGER DEFAULT 0,download INTEGER DEFAULT 0,seen INTEGER NOT NULL,active INTEGER DEFAULT 1);
CREATE INDEX IF NOT EXISTS by_ip ON connections(ip);
CREATE INDEX IF NOT EXISTS by_group ON connections(ip,domain,protocol,inbound);
CREATE TABLE IF NOT EXISTS daily(day TEXT,ip TEXT,upload INTEGER DEFAULT 0,download INTEGER DEFAULT 0,PRIMARY KEY(day,ip));
CREATE TABLE IF NOT EXISTS bans(ip TEXT PRIMARY KEY,reason TEXT,created INTEGER,enforcement TEXT);
CREATE TABLE IF NOT EXISTS sessions(token_hash TEXT PRIMARY KEY,csrf TEXT,expires INTEGER);
CREATE TABLE IF NOT EXISTS failures(ip TEXT,at INTEGER);
CREATE INDEX IF NOT EXISTS failure_time ON failures(at);
CREATE TABLE IF NOT EXISTS audit(at INTEGER,action TEXT,ip TEXT,detail TEXT);
'''


def _v2(c):
    """Rollups, time series, route metadata and management tables."""
    for column in ('rule', 'chain', 'destination', 'user', 'outbound_type'):
        c.execute("ALTER TABLE connections ADD COLUMN %s TEXT DEFAULT ''" % column)
    script(c, '''
CREATE INDEX IF NOT EXISTS conn_seen ON connections(seen);
CREATE INDEX IF NOT EXISTS conn_active ON connections(active) WHERE active=1;
CREATE TABLE ip_totals(ip TEXT PRIMARY KEY,connections INTEGER DEFAULT 0,upload INTEGER DEFAULT 0,download INTEGER DEFAULT 0,first_seen INTEGER DEFAULT 0,last_seen INTEGER DEFAULT 0);
CREATE TABLE history_groups(ip TEXT,domain TEXT,protocol TEXT,inbound TEXT,connections INTEGER DEFAULT 0,upload INTEGER DEFAULT 0,download INTEGER DEFAULT 0,first_seen INTEGER DEFAULT 0,last_seen INTEGER DEFAULT 0,outbounds TEXT DEFAULT '',PRIMARY KEY(ip,domain,protocol,inbound)) WITHOUT ROWID;
CREATE INDEX history_groups_seen ON history_groups(last_seen);
CREATE TABLE series_minute(ts INTEGER,ip TEXT,inbound TEXT,outbound TEXT,upload INTEGER DEFAULT 0,download INTEGER DEFAULT 0,PRIMARY KEY(ts,ip,inbound,outbound)) WITHOUT ROWID;
CREATE TABLE series_hour(ts INTEGER,ip TEXT,inbound TEXT,outbound TEXT,upload INTEGER DEFAULT 0,download INTEGER DEFAULT 0,PRIMARY KEY(ts,ip,inbound,outbound)) WITHOUT ROWID;
CREATE TABLE alerts(id INTEGER PRIMARY KEY,key TEXT,kind TEXT,level TEXT,message TEXT,opened INTEGER,resolved INTEGER DEFAULT 0,acked INTEGER DEFAULT 0);
CREATE INDEX alerts_open ON alerts(key,resolved);
CREATE TABLE probes(at INTEGER,outbound TEXT,target TEXT,ok INTEGER,exit_ip TEXT,colo TEXT,loc TEXT,connect_ms INTEGER,total_ms INTEGER,error TEXT);
CREATE INDEX probes_by ON probes(outbound,at);
CREATE TABLE prefs(key TEXT PRIMARY KEY,value TEXT);
''')
    c.execute('ALTER TABLE bans ADD COLUMN expires INTEGER DEFAULT 0')
    for column, kind in (('created', 'INTEGER DEFAULT 0'), ('ip', "TEXT DEFAULT ''"), ('agent', "TEXT DEFAULT ''"), ('last_seen', 'INTEGER DEFAULT 0')):
        c.execute('ALTER TABLE sessions ADD COLUMN %s %s' % (column, kind))
    # Exact rollups derived from the per-connection ledger.
    c.execute('''INSERT INTO ip_totals SELECT ip,COUNT(*),SUM(upload),SUM(download),MIN(started),MAX(seen) FROM connections GROUP BY ip''')
    c.execute('''INSERT INTO history_groups SELECT ip,domain,protocol,inbound,COUNT(*),SUM(upload),SUM(download),MIN(started),MAX(seen),GROUP_CONCAT(DISTINCT outbound) FROM connections GROUP BY ip,domain,protocol,inbound''')
    # Pre-upgrade hourly series is estimated: each connection's bytes land in its last-seen hour.
    c.execute('''INSERT INTO series_hour SELECT (seen/3600000)*3600,ip,inbound,outbound,SUM(upload),SUM(download) FROM connections WHERE upload+download>0 GROUP BY 1,2,3,4''')
    now = str(int(time.time()))
    c.execute("INSERT OR REPLACE INTO meta VALUES('series_since',?)", (now,))
    c.execute("INSERT OR REPLACE INTO meta VALUES('series_estimated_before',?)", (now,))


def _v3(c):
    """Multiple panel accounts: remember which account owns a session."""
    c.execute("ALTER TABLE sessions ADD COLUMN user TEXT DEFAULT ''")


def _v4(c):
    """Network view: interface byte counters and sampled TCP path quality."""
    script(c, '''
CREATE TABLE nic_minute(ts INTEGER,iface TEXT,rx INTEGER DEFAULT 0,tx INTEGER DEFAULT 0,PRIMARY KEY(ts,iface)) WITHOUT ROWID;
CREATE TABLE nic_hour(ts INTEGER,iface TEXT,rx INTEGER DEFAULT 0,tx INTEGER DEFAULT 0,PRIMARY KEY(ts,iface)) WITHOUT ROWID;
CREATE TABLE quality(ts INTEGER,segment TEXT,key TEXT,conns INTEGER,rtt REAL,rtt_p90 REAL,min_rtt REAL,sent INTEGER DEFAULT 0,retrans INTEGER DEFAULT 0,PRIMARY KEY(ts,segment,key)) WITHOUT ROWID;
CREATE INDEX quality_by_key ON quality(segment,key,ts);
''')


MIGRATIONS = [(2, _v2), (3, _v3), (4, _v4)]


def script(c, sql):
    for statement in sql.split(';'):
        if statement.strip():
            c.execute(statement)


class tx:
    """Explicit transaction on an autocommit connection."""

    def __init__(self, c, mode='IMMEDIATE'):
        self.c, self.mode = c, mode

    def __enter__(self):
        self.c.execute('BEGIN ' + self.mode)
        return self.c

    def __exit__(self, kind, value, trace):
        self.c.execute('COMMIT' if kind is None else 'ROLLBACK')
        return False


def connect(path):
    # Autocommit; writers use `tx` so batches are atomic and short.
    c = sqlite3.connect(str(path), timeout=20, check_same_thread=False, isolation_level=None)
    c.row_factory = sqlite3.Row
    c.execute('PRAGMA busy_timeout=20000')
    c.execute('PRAGMA synchronous=NORMAL')
    return c


def version(c):
    row = c.execute("SELECT value FROM meta WHERE key='schema_version'").fetchone()
    return int(row[0]) if row else 1


def migrate(path):
    """Create or upgrade the ledger. Additive only; never deletes recorded data."""
    c = connect(path)
    try:
        c.execute('PRAGMA journal_mode=WAL')
        applied = apply(c)
    finally:
        c.close()
    os.chmod(path, 0o600)
    return applied


def dry_run(path):
    """Migrate an in-memory copy of a live ledger and check the rollups; the file is only read."""
    source = sqlite3.connect('file:%s?mode=ro' % path, uri=True)
    c = sqlite3.connect(':memory:', isolation_level=None)
    c.row_factory = sqlite3.Row
    try:
        source.backup(c)
        before = c.execute('SELECT COUNT(*),COALESCE(SUM(upload),0),COALESCE(SUM(download),0) FROM connections').fetchone()
        started = time.time()
        applied = apply(c)
        groups = c.execute('SELECT COALESCE(SUM(connections),0),COALESCE(SUM(upload),0),COALESCE(SUM(download),0) FROM history_groups').fetchone()
        ips = c.execute('SELECT COALESCE(SUM(connections),0),COALESCE(SUM(upload),0),COALESCE(SUM(download),0) FROM ip_totals').fetchone()
        return {'applied': applied, 'seconds': round(time.time() - started, 2), 'connections': before[0],
                'rollups_match': tuple(before) == tuple(groups) == tuple(ips), 'schema_version': version(c)}
    finally:
        c.close()
        source.close()


def apply(c):
    """Apply pending migrations on an open autocommit connection."""
    script(c, SCHEMA_V1)
    c.execute("INSERT OR IGNORE INTO meta VALUES('tracking_since',?)", (str(int(time.time() * 1000)),))
    current = version(c)
    applied = []
    for target, step in MIGRATIONS:
        if current < target:
            started = time.time()
            with tx(c):
                step(c)
                c.execute("INSERT OR REPLACE INTO meta VALUES('schema_version',?)", (str(target),))
            applied.append((target, round(time.time() - started, 2)))
            current = target
    # Connections cannot still be active after a restart; the collector re-reports live ones.
    c.execute('UPDATE connections SET active=0 WHERE active=1')
    return applied
