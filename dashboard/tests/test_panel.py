"""Panel test-suite. Run: python -m unittest discover -s tests (no network, firewall or sing-box needed)."""
import faulthandler
import json
import socket
import sqlite3
import threading
import time
import unittest
from unittest.mock import patch

from helpers import (ORIGIN, FakeFirewall, batch, cleanup, conn, event, login, make_app, make_env, pb, random,
                     random_events)

from panel import db as dbm
from panel import netstats, probes, settings as settings_mod
from panel.bans import Firewall, canonical
from panel.live import Live
from panel.routes import _csv_cell
from panel.topology import rule_label

# Never hang a deployment: dump stacks and exit if the suite stalls.
faulthandler.dump_traceback_later(240, exit=True)


class Base(unittest.TestCase):
    base = '/monitor'

    def setUp(self):
        self.root = make_env(self.base)
        self.firewall = FakeFirewall()
        self.app, self.ctx = make_app(self.root, self.firewall)
        self.client = self.app.test_client()

    def tearDown(self):
        cleanup(self.root)

    def headers(self, csrf):
        return {'Origin': ORIGIN, 'X-CSRF-Token': csrf}

    def consistency(self):
        """Rollups must equal aggregates recomputed from the per-connection ledger."""
        c = self.ctx.store.reader()
        groups = {tuple(r[:4]): tuple(r[4:]) for r in c.execute('SELECT ip,domain,protocol,inbound,connections,upload,download FROM history_groups')}
        expect = {tuple(r[:4]): tuple(r[4:]) for r in c.execute('SELECT ip,domain,protocol,inbound,COUNT(*),SUM(upload),SUM(download) FROM connections GROUP BY 1,2,3,4')}
        self.assertEqual(groups, expect)
        ips = {r[0]: tuple(r[1:]) for r in c.execute('SELECT ip,connections,upload,download FROM ip_totals')}
        expect = {r[0]: tuple(r[1:]) for r in c.execute('SELECT ip,COUNT(*),SUM(upload),SUM(download) FROM connections GROUP BY ip')}
        self.assertEqual(ips, expect)
        daily = c.execute('SELECT COALESCE(SUM(upload),0),COALESCE(SUM(download),0) FROM daily').fetchone()
        for table in ('series_minute', 'series_hour'):
            self.assertEqual(tuple(daily), tuple(c.execute('SELECT COALESCE(SUM(upload),0),COALESCE(SUM(download),0) FROM %s' % table).fetchone()))
        total = c.execute('SELECT COALESCE(SUM(upload),0),COALESCE(SUM(download),0) FROM connections').fetchone()
        self.assertEqual(tuple(daily), tuple(total))


class SettingsTest(unittest.TestCase):
    def test_layering_and_legacy_keys(self):
        root = make_env('/panel')
        try:
            secrets = json.loads((root / 'config.json').read_text())
            secrets.update(public_origin='https://legacy.example.test', esa_gate_enabled=True)
            (root / 'config.json').write_text(json.dumps(secrets))
            s = settings_mod.load(root / 'settings.json', root / 'config.json', environ={})
            # settings.json wins over the legacy key in the secrets file.
            self.assertEqual(s.public_origin, ORIGIN)
            self.assertEqual(s.base_path, '/panel')
            self.assertTrue(s.gate_enabled)
            self.assertEqual(s.get('live.max_streams'), settings_mod.DEFAULTS['live']['max_streams'])
            s = settings_mod.load(root / 'settings.json', root / 'config.json', environ={'JOYSOL_PUBLIC_URL': 'https://other.example.test'})
            self.assertEqual(s.public_host, 'other.example.test')
            s.apply_overrides({'labels.outbounds': {'direct': '直连'}, 'site.public_url': 'https://evil.test'})
            self.assertEqual(s.section('labels')['outbounds'], {'direct': '直连'})
            self.assertEqual(s.public_host, 'other.example.test')
            self.assertNotIn('password_hash', json.dumps(s.public_view()))
        finally:
            cleanup(root)

    def test_validation(self):
        root = make_env('/monitor')
        try:
            values = json.loads((root / 'settings.json').read_text())
            values['site']['base_path'] = '/'
            (root / 'settings.json').write_text(json.dumps(values))
            with self.assertRaises(ValueError):
                settings_mod.load(root / 'settings.json', root / 'config.json', environ={})
        finally:
            cleanup(root)


class MigrationTest(unittest.TestCase):
    def test_v1_ledger_upgrades_with_exact_rollups(self):
        root = make_env()
        try:
            data = root / 'data'
            data.mkdir()
            c = sqlite3.connect(str(data / 'stats.sqlite3'))
            c.executescript(dbm.SCHEMA_V1)
            now = int(time.time() * 1000)
            rows = [('c%d' % i, ['8.8.8.8', '1.1.1.1'][i % 2], ['a.com', 'b.com'][i % 3 % 2], 'tcp/tls', 'vless/esa', ['direct', 'x'][i % 2],
                     now - i * 1000, 0, i * 10, i * 100, now - i * 500, i % 2) for i in range(50)]
            c.executemany('INSERT INTO connections VALUES(?,?,?,?,?,?,?,?,?,?,?,?)', rows)
            c.execute("INSERT INTO sessions VALUES('h','c',?)", (int(time.time()) + 100,))
            c.execute("INSERT INTO bans VALUES('9.9.9.9','r',1,'x')")
            c.commit()
            c.close()
            rehearsal = dbm.dry_run(data / 'stats.sqlite3')
            self.assertTrue(rehearsal['rollups_match'])
            self.assertEqual((rehearsal['schema_version'], rehearsal['connections']), (dbm.MIGRATIONS[-1][0], 50))
            self.assertEqual(dbm.version(sqlite3.connect(str(data / 'stats.sqlite3'))), 1)
            applied = dbm.migrate(data / 'stats.sqlite3')
            self.assertEqual([v for v, _ in applied], [v for v, _ in dbm.MIGRATIONS])
            self.assertEqual(dbm.migrate(data / 'stats.sqlite3'), [])
            app, ctx = make_app(root)
            t = ctx.store.totals()
            self.assertEqual(t['upload'], sum(r[8] for r in rows))
            self.assertEqual(t['connections'], 50)
            groups = ctx.store.history(limit=2000)
            self.assertEqual(sum(g['connections'] for g in groups['rows']), 50)
            self.assertEqual(ctx.store.reader().execute('SELECT COUNT(*) FROM connections WHERE active=1').fetchone()[0], 0)
            hour = ctx.store.reader().execute('SELECT SUM(download) FROM series_hour').fetchone()[0]
            self.assertEqual(hour, sum(r[9] for r in rows))
            self.assertEqual(ctx.bans.list()[0]['expires'], 0)
        finally:
            cleanup(root)


class IngestTest(Base):
    def test_closed_short_connection_and_replay(self):
        self.ctx.store.ingest(batch(event(pb.EVENT_CLOSED, 'a', conn('a', up=123, down=456, closed=True))))
        self.ctx.store.ingest(batch(event(pb.EVENT_CLOSED, 'a', conn('a', up=123, down=456, closed=True)), reset=True))
        r = self.ctx.store.reader().execute('SELECT upload,download,active FROM connections').fetchone()
        self.assertEqual(tuple(r), (123, 456, 0))
        self.consistency()

    def test_delta_then_final_totals(self):
        self.ctx.store.ingest(batch(event(pb.EVENT_NEW, 'a', conn('a'))))
        self.ctx.store.ingest(batch(event(pb.EVENT_UPDATE, 'a', du=10, dd=20)))
        self.ctx.store.ingest(batch(event(pb.EVENT_CLOSED, 'a', conn('a', up=30, down=50, closed=True))))
        self.assertEqual(self.ctx.store.reader().execute('SELECT SUM(upload+download) FROM daily').fetchone()[0], 80)
        self.consistency()

    def test_random_streams_keep_rollups_consistent(self):
        rng = random.Random(7)
        events = random_events(rng, 600)
        for i in range(0, len(events), 7):
            self.ctx.store.ingest(batch(*events[i:i + 7], reset=(i % 140 == 0 and i > 0)))
        self.consistency()

    def test_domain_change_moves_group(self):
        self.ctx.store.ingest(batch(event(pb.EVENT_NEW, 'a', conn('a', up=5, down=5, domain='x.com'))))
        self.ctx.store.ingest(batch(event(pb.EVENT_UPDATE, 'a', conn('a', up=9, down=9, domain='y.com'))))
        domains = [r['domain'] for r in self.ctx.store.history()['rows']]
        self.assertEqual(domains, ['y.com'])
        self.consistency()

    def test_live_rates_and_active_list(self):
        self.ctx.store.ingest(batch(event(pb.EVENT_NEW, 'a', conn('a', outbound='decodo-us-10003'))))
        self.ctx.store.ingest(batch(event(pb.EVENT_UPDATE, 'a', du=1000, dd=4000)))
        frame = self.ctx.live.frame()
        self.assertEqual(frame['active'], 1)
        self.assertGreater(frame['down'], 0)
        self.assertIn('decodo-us-10003', frame['out'])
        self.assertEqual(frame['top'][0]['ip'], '8.8.8.8')
        self.ctx.store.ingest(batch(event(pb.EVENT_CLOSED, 'a', conn('a', up=1000, down=4000, closed=True))))
        self.assertEqual(self.ctx.live.frame()['active'], 0)

    def test_first_batch_after_reset_is_not_a_rate(self):
        live = Live(60)
        live.reset()
        live.apply([('a', 'ip', 'in', 'out', 10 ** 9, 10 ** 9)], 1000)
        self.assertEqual(len(live.samples), 0)
        live.apply([('a', 'ip', 'in', 'out', 100, 200)], 2000)
        self.assertEqual(live.samples[-1]['down'], 200)

    def test_ipv6_source(self):
        from panel.store import source_ip
        self.assertEqual(source_ip('[2606:4700:4700::1111]:1234'), '2606:4700:4700::1111')

    def test_series_buckets_and_by_outbound(self):
        self.ctx.store.ingest(batch(event(pb.EVENT_CLOSED, 'a', conn('a', up=10, down=90, outbound='direct', closed=True)),
                                    event(pb.EVENT_CLOSED, 'b', conn('b', up=1, down=9, outbound='oxylabs-8001', closed=True))))
        for span in ('1h', '24h', '7d', '90d'):
            data = self.ctx.store.series(span, 'outbound')
            total = sum(sum(x['down']) for x in data['series'])
            self.assertEqual(total, 99, span)
            self.assertEqual({x['key'] for x in data['series']}, {'direct', 'oxylabs-8001'})


class ApiTest(Base):
    def test_auth_csrf_origin_and_cookie(self):
        self.assertEqual(self.client.get('/monitor/api/overview').status_code, 401)
        self.assertEqual(self.client.get('/monitor/').status_code, 302)
        csrf, r = login(self.client)
        cookie = r.headers['Set-Cookie']
        for flag in ('Secure', 'HttpOnly', 'SameSite=Strict', 'Max-Age=2592000', '__Host-'):
            self.assertIn(flag, cookie)
        self.assertEqual(self.client.post('/monitor/api/ban', json={'ip': '8.8.8.8', 'action': 'ban'}).status_code, 403)
        bad = {'Origin': 'https://evil.test', 'X-CSRF-Token': csrf}
        self.assertEqual(self.client.post('/monitor/api/ban', json={'ip': '8.8.8.8', 'action': 'ban'}, headers=bad).status_code, 403)
        self.assertEqual(self.client.post('/monitor/logout', json={}, headers=self.headers(csrf)).status_code, 200)
        self.assertEqual(self.client.get('/monitor/api/overview').status_code, 401)

    def test_cdn_client_ip_needs_origin_header(self):
        guard = self.ctx.settings.secrets['origin_guard']
        base = {'Origin': ORIGIN, 'X-Dashboard-Client-IP': '47.1.1.1', 'X-Forwarded-For': '6.6.6.6, 203.0.113.50'}
        self.client.post('/monitor/login', data={'username': 'test', 'password': 'x'}, headers=base)
        self.client.post('/monitor/login', data={'username': 'test', 'password': 'x'}, headers=dict(base, **{'X-Joysol-Origin': guard}))
        ips = [r[0] for r in self.ctx.store.reader().execute('SELECT ip FROM failures ORDER BY rowid')]
        self.assertEqual(ips, ['47.1.1.1', '203.0.113.50'])

    def test_login_failure_throttle(self):
        for _ in range(10):
            r = self.client.post('/monitor/login', data={'username': 'test', 'password': 'bad'}, headers={'Origin': ORIGIN})
            self.assertEqual(r.status_code, 401)
        r = self.client.post('/monitor/login', data={'username': 'test', 'password': 'bad'}, headers={'Origin': ORIGIN})
        self.assertEqual(r.status_code, 429)
        self.assertIn('15', r.get_data(as_text=True))

    def test_history_paging_sorting_search_and_range(self):
        old = int(time.time() * 1000) - 3 * 86400 * 1000
        for i in range(30):
            self.ctx.store.ingest(batch(event(pb.EVENT_CLOSED, 'c%d' % i, conn('c%d' % i, up=i, down=i * 10, domain='d%02d.com' % i, closed=True))))
        with self.ctx.store.write() as c:
            c.execute('UPDATE connections SET seen=? WHERE domain=?', (old, 'd00.com'))
        csrf, _ = login(self.client)
        page = self.client.get('/monitor/api/history?limit=10&offset=0&sort=download&dir=desc').get_json()
        self.assertEqual(page['total'], 30)
        self.assertEqual(len(page['rows']), 10)
        self.assertEqual(page['rows'][0]['domain'], 'd29.com')
        page2 = self.client.get('/monitor/api/history?limit=10&offset=10&sort=download&dir=desc').get_json()
        self.assertEqual(page2['rows'][0]['domain'], 'd19.com')
        found = self.client.get('/monitor/api/history?q=d0').get_json()
        self.assertEqual(found['total'], 10)
        ranged = self.client.get('/monitor/api/history?since=24h').get_json()
        self.assertEqual(ranged['total'], 29)
        legacy = self.client.get('/monitor/api/data').get_json()
        for key in ('ips', 'history', 'daily', 'daily_ips', 'bans', 'health', 'csrf', 'esa_gate_enabled', 'esa_origin_verified'):
            self.assertIn(key, legacy)
        self.assertEqual(sum(r['connections'] for r in legacy['ips']), 30)

    def test_daily_per_ip_matches_totals(self):
        with self.ctx.store.write() as c:
            c.executemany('INSERT INTO daily VALUES(?,?,?,?)', [('2026-10-15', '8.8.8.8', 10, 20), ('2026-10-15', '1.1.1.1', 30, 40), ('2026-10-16', '8.8.8.8', 50, 60)])
        login(self.client)
        d = self.client.get('/monitor/api/daily?ip=8.8.8.8').get_json()
        self.assertEqual(len(d['rows']), 2)
        day = next(x for x in d['days'] if x['day'] == '2026-10-15')
        self.assertEqual((day['upload'], day['download']), (40, 60))
        self.assertIn('location', d['rows'][0])

    def test_topology_flows_and_no_credentials(self):
        self.ctx.store.ingest(batch(event(pb.EVENT_CLOSED, 'a', conn('a', up=5, down=50, outbound='decodo-us-10003', closed=True,
                                                                    rule='domain_suffix=[openai.com chatgpt.com] network=tcp => route(decodo-us-10003)'))))
        login(self.client)
        body = self.client.get('/monitor/api/topology?range=24h').get_data(as_text=True)
        data = json.loads(body)
        self.assertNotIn('fixture-pass', body)
        self.assertNotIn('fixture-user', body)
        self.assertEqual(data['flows'][0]['rule_label'], '域名后缀 → decodo-us-10003')
        tags = {x['tag']: x for x in data['topology']['inbounds']}
        self.assertEqual(tags['vless-esa-ws-in']['entry'], 'cdn')
        self.assertEqual(tags['vless-reality-in']['entry'], 'direct')
        system = self.client.get('/monitor/api/system').get_data(as_text=True)
        self.assertNotIn('fixture-pass', system)
        self.assertNotIn(self.ctx.settings.secrets['api_secret'], system)

    def test_prefs_update_labels(self):
        csrf, _ = login(self.client)
        r = self.client.put('/monitor/api/prefs', json={'labels.outbounds': {'decodo-us-10003': 'Decodo 家宽'}}, headers=self.headers(csrf))
        self.assertEqual(r.status_code, 200)
        outs = {o['tag']: o['label'] for o in self.client.get('/monitor/api/overview').get_json()['topology']['outbounds']}
        self.assertEqual(outs['decodo-us-10003'], 'Decodo 家宽')
        r = self.client.put('/monitor/api/prefs', json={'site.public_url': 'https://evil.test'}, headers=self.headers(csrf))
        self.assertEqual(r.status_code, 400)
        r = self.client.put('/monitor/api/prefs', json={'probes.interval_seconds': 5}, headers=self.headers(csrf))
        self.assertEqual(r.status_code, 400)

    def test_sessions_list_and_revoke_others(self):
        other = self.app.test_client()
        login(other)
        csrf, _ = login(self.client)
        rows = self.client.get('/monitor/api/sessions').get_json()['rows']
        self.assertEqual(len(rows), 2)
        self.assertNotIn('token_hash', json.dumps(rows))
        target = next(r for r in rows if not r['current'])['id']
        self.assertEqual(self.client.post('/monitor/api/sessions/revoke', json={'id': target}, headers=self.headers(csrf)).status_code, 200)
        self.assertEqual(other.get('/monitor/api/overview').status_code, 401)
        self.assertEqual(self.client.get('/monitor/api/overview').status_code, 200)

    def test_csv_export_guards_formulas(self):
        self.assertEqual(_csv_cell('=cmd()'), "'=cmd()")
        self.ctx.store.ingest(batch(event(pb.EVENT_CLOSED, 'a', conn('a', domain='=evil.com', up=1, down=1, closed=True))))
        login(self.client)
        text = self.client.get('/monitor/api/export/history.csv').get_data(as_text=True)
        self.assertIn("'=evil.com", text)

    def test_stream_first_frame(self):
        login(self.client)
        r = self.client.get('/monitor/api/stream', buffered=False)
        self.assertEqual(r.mimetype, 'text/event-stream')
        self.assertEqual(r.headers['X-Accel-Buffering'], 'no')
        chunks = iter(r.response)
        first = next(chunks)
        second = next(chunks)
        text = b''.join(x if isinstance(x, bytes) else x.encode() for x in (first, second)).decode()
        self.assertIn('retry: 3000', text)
        self.assertIn('event: frame', text)
        r.close()
        self.assertEqual(self.ctx.hub.count(), 0)


class ConfigurableBaseTest(Base):
    base = '/ops/console'

    def test_everything_follows_base_path(self):
        self.assertEqual(self.client.get('/monitor/login').status_code, 404)
        self.assertEqual(self.client.get('/ops/console/login').status_code, 200)
        html = self.client.get('/ops/console/login').get_data(as_text=True)
        self.assertIn('action="/ops/console/login"', html)
        self.assertNotIn('{{', html)
        csrf, r = login(self.client, '/ops/console')
        self.assertEqual(r.headers['Location'].split('://')[-1].split('/', 1)[-1], 'ops/console/')
        self.assertEqual(self.client.get('/ops/console/api/overview').get_json()['base'], '/ops/console')


class AccountsTest(unittest.TestCase):
    def test_extra_account_login_and_session_owner(self):
        root = make_env(users=[('ops', 'ops-password')])
        try:
            app, ctx = make_app(root)
            client = app.test_client()
            bad = client.post('/monitor/login', data={'username': 'ops', 'password': 'test-password'}, headers={'Origin': ORIGIN})
            self.assertEqual(bad.status_code, 401)
            r = client.post('/monitor/login', data={'username': 'ops', 'password': 'ops-password'}, headers={'Origin': ORIGIN})
            self.assertEqual(r.status_code, 302)
            overview = client.get('/monitor/api/overview').get_json()
            self.assertEqual(overview['user'], 'ops')
            primary = app.test_client()
            login(primary)
            users = sorted(s['user'] for s in primary.get('/monitor/api/sessions').get_json()['rows'])
            self.assertEqual(users, ['ops', 'test'])
            self.assertIn('ops', [row['detail'] for row in ctx.store.audit()['rows'] if row['action'] == 'login'])
            self.assertNotIn('password_hash', json.dumps(primary.get('/monitor/api/system').get_json()))
        finally:
            cleanup(root)


class BanTest(Base):
    def test_canonical_rules(self):
        self.assertEqual(canonical('8.8.8.8'), '8.8.8.8')
        self.assertEqual(canonical('8.8.8.9/24'), '8.8.8.0/24')
        self.assertEqual(canonical('8.8.8.8/32'), '8.8.8.8')
        for bad in ('127.0.0.1', '10.0.0.0/8', '8.0.0.0/8', '8.8.8.8;touch /tmp/x', '2606:4700::/16', ''):
            with self.assertRaises(ValueError, msg=bad):
                canonical(bad)

    def test_ban_cidr_gate_expiry_and_firewall_ports(self):
        csrf, _ = login(self.client)
        self.ctx.store.ingest(batch(event(pb.EVENT_NEW, 'a', conn('a', ip='8.8.8.8'))))
        with patch.object(self.ctx, 'close_connections') as closer:
            r = self.client.post('/monitor/api/ban', json={'ip': '8.8.8.0/24', 'action': 'ban', 'reason': 't', 'duration': 3600}, headers=self.headers(csrf))
            self.assertEqual(r.status_code, 200, r.get_json())
            closer.assert_called_with(['a'])
        self.assertTrue(self.ctx.bans.is_banned('8.8.8.77'))
        self.assertFalse(self.ctx.bans.is_banned('8.8.9.1'))
        # Firewall jump covers only the public inbound port from the sing-box config.
        self.assertEqual({(pr, p) for pr, p, _ in self.firewall.jumps}, {('tcp', 443)})
        guard = {'X-Origin-Guard': self.ctx.settings.secrets['origin_guard'], 'X-Origin-XFF': '9.9.9.9, 8.8.8.20'}
        self.assertEqual(self.client.get('/internal/gate', headers=guard).status_code, 403)
        self.assertEqual(self.client.get('/internal/gate', headers={'X-Origin-XFF': '1.1.1.1'}).status_code, 403)
        ok = dict(guard, **{'X-Origin-XFF': '8.8.8.20, 1.1.1.1'})
        r = self.client.get('/internal/gate', headers=ok)
        self.assertEqual((r.status_code, r.headers['X-Verified-Client-IP']), (204, '1.1.1.1'))
        self.assertEqual(self.client.get('/internal/gate', headers=ok, environ_base={'REMOTE_ADDR': '8.8.8.8'}).status_code, 403)
        with self.ctx.store.write() as c:
            c.execute('UPDATE bans SET expires=?', (int(time.time()) - 1,))
        self.assertEqual(self.ctx.bans.expire(), ['8.8.8.0/24'])
        self.assertFalse(self.ctx.bans.is_banned('8.8.8.77'))
        self.assertFalse(self.firewall.rules)
        actions = [r['action'] for r in self.ctx.store.audit()['rows']]
        self.assertIn('unban-expired', actions)
        r = self.client.post('/monitor/api/ban', json={'ip': '7.7.7.7', 'action': 'unban'}, headers=self.headers(csrf))
        self.assertEqual(r.status_code, 404)

    def test_stale_firewall_jump_removed(self):
        self.firewall.jumps.add(('tcp', 8443, 'JOYSOL_NODE_BANS'))
        self.ctx.bans.firewall.ensure_jumps('/usr/sbin/iptables')
        self.assertEqual({(pr, p) for pr, p, _ in self.firewall.jumps}, {('tcp', 443)})

    def test_udp_inbound_gets_udp_jump_and_drop_rule(self):
        fake = FakeFirewall()
        fw = Firewall('JOYSOL_NODE_BANS', lambda: [('tcp', 443), ('udp', 443)], fake)
        fw.apply('8.8.4.4', True)
        self.assertEqual({(pr, p) for pr, p, _ in fake.jumps}, {('tcp', 443), ('udp', 443)})
        self.assertEqual({r[2] for r in fake.rules}, {'tcp', 'udp'})
        self.assertIn(('JOYSOL_NODE_BANS', '-p', 'udp', '-s', '8.8.4.4', '-j', 'DROP'), fake.rules)
        fw.apply('8.8.4.4', False)
        self.assertFalse(fake.rules)

    def test_ingest_closes_banned(self):
        self.ctx.bans.ban('8.8.8.8')
        with patch.object(self.ctx.store, 'on_banned') as hook:
            self.ctx.store.ingest(batch(event(pb.EVENT_NEW, 'z', conn('z', ip='8.8.8.8'))))
            hook.assert_called_with(['z'])


class TopologyTest(Base):
    def test_rule_labels(self):
        self.assertEqual(rule_label(''), '默认出口 (final)')
        self.assertEqual(rule_label('inbound=[a] domain_suffix=[x y] network=tcp => route(oxylabs-8001)'), '域名后缀 → oxylabs-8001')
        self.assertEqual(rule_label('ip_is_private => reject'), '规则 → reject')
        self.assertEqual(rule_label('rule_set=[geosite-cn] => route(direct)'), '规则集 → direct')

    def test_discovery_and_reload(self):
        t = self.ctx.topology
        self.assertEqual(t.public_ports(), [443])
        self.assertEqual(t.proxy('oxylabs-8001')['type'], 'socks')
        self.assertIsNone(t.proxy('direct'))
        described = json.dumps(t.describe())
        self.assertNotIn('fixture-pass', described)
        self.assertEqual(t.describe()['final'], 'direct')
        self.assertEqual(t.public_endpoints(), [('tcp', 443)])

    def test_udp_inbound_endpoint(self):
        t = self.ctx.topology
        with open(t.path) as handle:
            config = json.load(handle)
        config['inbounds'].append({'type': 'hysteria2', 'tag': 'hy2-in', 'listen': '0.0.0.0', 'listen_port': 443,
                                   'users': [{'name': 'a', 'password': 'fixture-pass'}], 'tls': {'enabled': True}})
        with t.lock:
            t._parse(config)
        self.assertEqual(t.public_endpoints(), [('tcp', 443), ('udp', 443)])
        self.assertEqual(t.public_ports(), [443])
        self.assertEqual(t.inbound('hy2-in')['network'], 'udp')


class ProbeTest(unittest.TestCase):
    def serve(self, handler):
        server = socket.socket()
        server.bind(('127.0.0.1', 0))
        server.listen(4)

        def loop():
            while True:
                try:
                    client, _ = server.accept()
                except OSError:
                    return
                threading.Thread(target=handler, args=(client,), daemon=True).start()
        threading.Thread(target=loop, daemon=True).start()
        self.addCleanup(server.close)
        return server.getsockname()[1]

    def target(self, client):
        client.recv(4096)
        body = b'fl=1\nip=203.0.113.9\ncolo=LAX\nloc=US\n'
        client.sendall(b'HTTP/1.1 200 OK\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s' % (len(body), body))
        client.close()

    def test_socks5_and_http_connect(self):
        web = self.serve(self.target)

        def relay(a, b):
            try:
                while True:
                    data = a.recv(4096)
                    if not data:
                        break
                    b.sendall(data)
            except OSError:
                pass
            finally:
                # shutdown (not close) wakes the peer thread's recv on Linux and sends FIN.
                for sock in (a, b):
                    try:
                        sock.shutdown(socket.SHUT_RDWR)
                    except OSError:
                        pass

        def socks(client):
            greeting = client.recv(2)
            client.recv(greeting[1])
            client.sendall(b'\x05\x02')
            head = client.recv(2)
            user = client.recv(head[1])
            plen = client.recv(1)[0]
            pw = client.recv(plen)
            client.sendall(b'\x01\x00' if (user, pw) == (b'u', b'p') else b'\x01\x01')
            req = client.recv(4)
            size = client.recv(1)[0]
            client.recv(size + 2)
            upstream = socket.create_connection(('127.0.0.1', web))
            client.sendall(b'\x05\x00\x00\x01' + b'\x00' * 6)
            threading.Thread(target=relay, args=(client, upstream), daemon=True).start()
            relay(upstream, client)

        def http_proxy(client):
            data = b''
            while b'\r\n\r\n' not in data:
                data += client.recv(1024)
            ok = b'Proxy-Authorization: Basic dTpw' in data
            if not ok:
                client.sendall(b'HTTP/1.1 407 Auth\r\n\r\n')
                client.close()
                return
            upstream = socket.create_connection(('127.0.0.1', web))
            client.sendall(b'HTTP/1.1 200 Connection established\r\n\r\n')
            threading.Thread(target=relay, args=(client, upstream), daemon=True).start()
            relay(upstream, client)
        target = {'name': 'trace', 'url': 'http://probe.test/cdn-cgi/trace'}
        with patch('socket.getaddrinfo', wraps=socket.getaddrinfo):
            for kind, port in (('socks', self.serve(socks)), ('http', self.serve(http_proxy))):
                result = probes.probe(target, {'type': kind, 'server': '127.0.0.1', 'port': port, 'username': 'u', 'password': 'p'}, 5)
                self.assertEqual((result['ok'], result['exit_ip'], result['colo']), (1, '203.0.113.9', 'LAX'), kind)
            bad = probes.probe(target, {'type': 'http', 'server': '127.0.0.1', 'port': self.serve(http_proxy), 'username': 'x', 'password': 'y'}, 5)
            self.assertEqual(bad['ok'], 0)
            self.assertIn('407', bad['error'])


class AlertTest(Base):
    def test_open_and_resolve(self):
        self.ctx.health.update(connected=False, started=time.time() - 3600, last_event=0, last_error='Unavailable')
        with patch('panel.system.certificate', return_value={}), patch('panel.system.disk', return_value={'percent': 10}):
            self.ctx.alerts.evaluate()
            self.assertEqual([a['kind'] for a in self.ctx.alerts.open_alerts()], ['collector'])
            self.ctx.alerts.evaluate()
            self.assertEqual(len(self.ctx.alerts.recent()), 1)
            self.ctx.health.update(connected=True, last_event=int(time.time() * 1000))
            self.ctx.alerts.evaluate()
            self.assertEqual(self.ctx.alerts.open_alerts(), [])


SS_SAMPLE = """0      0      203.0.113.10:443        [::ffff:198.51.100.7]:50111
\t bbr wscale:9,9 rto:400 rtt:180.5/20.1 mss:1448 cwnd:40 bytes_sent:100000 bytes_retrans:2000 bytes_acked:98000 minrtt:170.2
0      0      203.0.113.10:443        198.51.100.7:50112
\t bbr rtt:200.5/10 bytes_sent:50000 minrtt:175
0      0      203.0.113.10:8443       192.0.2.50:30001
\t bbr rtt:160.1/5 bytes_sent:80000 bytes_retrans:800 minrtt:150
0      0      203.0.113.10:40454      192.0.2.99:10003
\t bbr rtt:1.2/0.2 bytes_sent:4000 minrtt:0.9
0      0      203.0.113.10:41000      192.0.2.200:443
\t bbr rtt:30.0/2 bytes_sent:6000 minrtt:28
0      0      203.0.113.10:22            192.0.2.77:51515
\t bbr rtt:150/3 bytes_sent:9000
0      0      127.0.0.1:33392         127.0.0.1:10000
\t bbr rtt:0.05/0.01 bytes_sent:100
"""


class NetworkTest(unittest.TestCase):
    def setUp(self):
        self.root = make_env(extra={'network': {'edge_ports': [8443]}})
        proc = self.root / 'proc'
        proc.mkdir()
        self.dev = proc / 'dev'
        (proc / 'route').write_text('Iface\tDestination\tGateway\neth0\t00000000\t0101A8C0\neth0\t0000A8C0\t00000000\n')
        (proc / 'boot').write_text('boot-a\n')
        (proc / 'ports').write_text('32768\t60999\n')
        self.counters(1000, 2000)
        extra = {'network': {'edge_ports': [8443], 'proc_net_dev': str(self.dev), 'proc_route': str(proc / 'route'),
                             'boot_id_path': str(proc / 'boot'), 'port_range_path': str(proc / 'ports')}}
        (self.root / 'settings.json').write_text(json.dumps(settings_mod.merge(json.loads((self.root / 'settings.json').read_text()), extra)))
        self.app, self.ctx = make_app(self.root)
        self.client = self.app.test_client()

    def tearDown(self):
        cleanup(self.root)

    def counters(self, rx, tx, lo=(5, 5)):
        self.dev.write_text('Inter-|   Receive\n face |bytes packets\n'
                            '    lo: %d 0 0 0 0 0 0 0 %d 0 0 0 0 0 0 0\n  eth0: %d 9 0 0 0 0 0 0 %d 9 0 0 0 0 0 0\n' % (lo[0], lo[1], rx, tx))

    def test_parsers(self):
        self.assertEqual(netstats.default_interfaces((self.root / 'proc/route').read_text()), ['eth0'])
        socks = netstats.parse_ss(SS_SAMPLE)
        self.assertEqual(len(socks), 7)
        self.assertEqual(str(socks[0]['peer'][0]), '198.51.100.7')
        self.assertEqual(socks[0]['rtt'], 180.5)
        self.assertEqual(socks[0]['bytes_retrans'], 2000)

    def test_nic_counts_bytes_across_restart(self):
        nic = self.ctx.nic
        self.assertEqual(nic.interfaces(), ['eth0'])
        self.counters(1500, 2600)
        nic.sample(nic.previous[0] + 1)
        self.assertEqual(nic.samples[-1]['rx'], 500)
        nic.flush()
        # Panel restarts; bytes received while it was down are attributed on the next start.
        self.counters(4000, 3000)
        _app, ctx2 = make_app(self.root)
        self.counters(4100, 3050)
        ctx2.nic.sample(time.time() + 1)
        ctx2.nic.flush()
        c = ctx2.store.reader()
        self.assertEqual(tuple(c.execute('SELECT SUM(rx),SUM(tx) FROM nic_minute').fetchone()), (3100, 1050))
        self.assertEqual(tuple(c.execute('SELECT SUM(rx),SUM(tx) FROM nic_hour').fetchone()), (3100, 1050))
        # A reboot resets counters: nothing negative or invented.
        (self.root / 'proc/boot').write_text('boot-b\n')
        self.counters(10, 10)
        _app, ctx3 = make_app(self.root)
        ctx3.nic.flush()
        self.assertEqual(tuple(ctx3.store.reader().execute('SELECT SUM(rx),SUM(tx) FROM nic_minute').fetchone()), (3100, 1050))

    def test_quality_segments_and_api(self):
        q = self.ctx.quality
        q.runner = lambda: SS_SAMPLE
        q._upstreams = (time.time(), {(netstats.ipaddress.ip_address('192.0.2.99'), 10003): 'decodo-us-10003'})
        latest = q.run()
        seg = latest['segments']
        self.assertEqual(set(seg), {'client', 'edge', 'upstream', 'direct'})
        self.assertEqual(seg['client']['conns'], 2)
        self.assertAlmostEqual(seg['client']['retrans_pct'], 2000 * 100 / 150000, places=2)
        self.assertEqual(seg['edge']['rtt'], 160.1)
        # Second sample: retransmissions are per interval, not lifetime totals.
        q.runner = lambda: SS_SAMPLE.replace('bytes_sent:100000 bytes_retrans:2000', 'bytes_sent:200000 bytes_retrans:2000')
        q.run(time.time() + 60)
        row = next(r for r in q.latest['keys'] if r['segment'] == 'client')
        self.assertEqual((row['sent'], row['retrans']), (100000, 0))
        csrf, _ = login(self.client)
        data = self.client.get('/monitor/api/network?range=1h').get_json()
        self.assertEqual(data['interfaces'], ['eth0'])
        client = next(r for r in data['quality']['keys'] if r['segment'] == 'client')
        self.assertEqual(client['key'], '198.51.100.7')
        self.assertIn('location', client)
        up = next(r for r in data['quality']['keys'] if r['segment'] == 'upstream')
        self.assertEqual(up['label'], 'decodo-us-10003')
        self.assertIn('client', data['quality']['series']['segments'])
        self.assertIn('nic', self.ctx.frame())
        r = self.client.put('/monitor/api/prefs', json={'network.quality_interval_seconds': 5}, headers={'Origin': ORIGIN, 'X-CSRF-Token': csrf})
        self.assertEqual(r.status_code, 400)


if __name__ == '__main__':
    unittest.main()
