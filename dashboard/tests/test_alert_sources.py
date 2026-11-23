import json
import io
import time
import unittest
import urllib.error
import http.server
import threading
from unittest.mock import patch

import helpers
from panel.reachability import Reachability, ProviderError, api, classify, public_target
from panel.probes import Prober
import test_xray_dashboard as fixtures


class MainlandTest(unittest.TestCase):
    def setUp(self):
        self.root = helpers.make_env(extra={'reachability': {'enabled': True}})
        self.app, self.ctx = helpers.make_app(self.root)
        self.monitor = self.ctx.reachability

    def tearDown(self):
        helpers.cleanup(self.root)

    def row(self, ok):
        return {'key': 'entry:unicom', 'target': 'entry', 'label': 'Test entry', 'isp': '联通', 'ok': ok, 'error': '' if ok else '连接超时'}

    def test_failure_latch_unknown_and_real_recovery_survive_restart(self):
        self.monitor.commit([self.row(False)])
        self.assertFalse(self.monitor.snapshot()['rows'][0]['alarm'])
        self.monitor.commit([self.row(False)])
        self.assertTrue(self.monitor.snapshot()['rows'][0]['alarm'])
        found = {}; self.ctx.alerts._mainland(found); self.ctx.alerts._sync(found)
        opened = self.ctx.alerts.open_alerts()[0]['id']
        self.ctx.alerts.ack(opened)
        self.monitor.commit([self.row(None)])
        self.assertTrue(self.monitor.snapshot()['rows'][0]['alarm'])
        self.assertEqual(self.monitor.snapshot()['rows'][0]['failures'], 0)
        restarted = Reachability(self.ctx.settings, self.ctx.store, self.ctx.stop)
        self.assertTrue(restarted.snapshot()['rows'][0]['alarm'])
        found = {}; self.ctx.alerts._mainland(found); self.ctx.alerts._sync(found)
        self.assertEqual(self.ctx.alerts.open_alerts()[0]['id'], opened)
        self.monitor.commit([self.row(True)])
        found = {}; self.ctx.alerts._mainland(found); self.ctx.alerts._sync(found)
        self.assertFalse(self.ctx.alerts.open_alerts())
        self.assertTrue(self.ctx.alerts.recent()[0]['resolved'])

    def test_gap_does_not_create_consecutive_failure(self):
        self.monitor.commit([self.row(False)])
        self.monitor.state['at'] -= 5000
        self.monitor.commit([self.row(False)])
        self.assertEqual(self.monitor.snapshot()['rows'][0]['failures'], 1)
        self.assertFalse(self.monitor.snapshot()['rows'][0]['alarm'])

    def test_provider_failure_not_target_failure(self):
        self.monitor.commit([self.row(None)], 'HTTPError')
        self.monitor.commit([self.row(None)], 'HTTPError')
        found = {}; self.ctx.alerts._mainland(found)
        self.assertEqual(set(found), {'reachability:provider'})

    def test_public_target_rejects_secret_paths_and_query(self):
        self.assertEqual(public_target({'host': 'panel.example.test', 'path': '/monitor/login'}), ('panel.example.test', '/monitor/login'))
        for path in ['/subscription/private-token', '/?token=secret', '/monitor/login?token=secret', '//other.test/']:
            with self.assertRaises(ValueError): public_target({'host': 'panel.example.test', 'path': path})
        with self.assertRaises(ValueError): public_target({'host': 'user:secret@panel.example.test'})

    def test_classification_requires_mainland_expected_asn_and_valid_tls(self):
        row = {'probe': {'country': 'CN', 'asn': 4837, 'city': 'Test city'}, 'result': {'status': 'finished', 'statusCode': 200, 'tls': {'authorized': True}}}
        data = {'results': [row]}
        self.assertTrue(classify(data, 4837)['ok'])
        row['result']['tls'] = None
        self.assertFalse(classify(data, 4837)['ok'])
        row['result']['status'] = 'offline'
        self.assertIsNone(classify(data, 4837)['ok'])
        row['probe']['country'] = 'HK'
        self.assertIsNone(classify(data, 4837)['ok'])
        row['probe']['country'] = 'CN'; row['probe']['asn'] = 4134
        self.assertIsNone(classify(data, 4837)['ok'])

    def test_job_restricts_request_and_skips_offline_probe(self):
        self.ctx.settings.values['reachability']['targets'] = [{'id': 'entry', 'label': 'Test', 'host': 'example.test', 'path': '/monitor/login'}]
        calls = []
        def fake_api(path, payload=None):
            calls.append((path, payload))
            if payload: return {'id': 'test-id'}
            return {'status': 'finished', 'results': []}
        with patch('panel.reachability.api', side_effect=fake_api), patch.object(self.ctx.stop, 'wait', return_value=False):
            self.monitor.run()
        posts = [p for _, p in calls if p]
        self.assertEqual(len(posts), 3)
        self.assertTrue(all(p['locations'][0]['country'] == 'CN' for p in posts))
        self.assertTrue(all(r['ok'] is None and r['failures'] == 0 for r in self.monitor.snapshot()['rows']))

    def test_http_200_with_download_timeout_is_still_failure(self):
        data = self.measurement(4837, status='failed', raw='TLS established\nError: Response download timed out')
        row = classify(data, 4837)
        self.assertFalse(row['ok'])
        self.assertEqual(row['stage'], 'download')
        self.assertIn('下载', row['error'])
        self.assertNotEqual(row['error'], 'HTTP 200')
        for text, stage in [('DNS resolution timed out', 'dns'), ('TLS handshake timed out', 'tls')]:
            with self.subTest(stage=stage):
                row = classify(self.measurement(4837, status='failed', raw=text), 4837)
                self.assertFalse(row['ok']); self.assertEqual(row['stage'], stage)

    @staticmethod
    def measurement(asn, status='finished', raw='', city='Test city'):
        return {'status': 'finished', 'results': [{'probe': {'country': 'CN', 'asn': asn, 'city': city},
            'result': {'status': status, 'statusCode': 200, 'tls': {'authorized': True}, 'rawOutput': raw}}]}

    def target(self):
        self.ctx.settings.values['reachability']['targets'] = [{'id': 'entry', 'label': 'Test', 'host': 'example.test', 'path': '/monitor/login'}]

    def test_dns_fallback_uses_same_probe_and_requires_same_city(self):
        self.target()
        for fallback_city in ['Test city', 'Other city']:
            calls = []
            def fake_api(path, payload=None):
                if payload:
                    calls.append(payload)
                    loc = payload['locations'][0]
                    return {'id': 'retry' if 'magic' in loc else str(loc['asn'])}
                mid = path.rsplit('/', 1)[-1]
                if mid == 'retry': return self.measurement(4837, city=fallback_city)
                return self.measurement(int(mid), status='failed' if mid == '4837' else 'finished', raw='DNS resolution timed out')
            with self.subTest(city=fallback_city), patch('panel.reachability.api', side_effect=fake_api), patch.object(self.ctx.stop, 'wait', return_value=False):
                self.monitor.state = {}; self.monitor.run()
                row = next(r for r in self.monitor.snapshot()['rows'] if r['key'] == 'entry:unicom')
                self.assertEqual(row['ok'], True if fallback_city == 'Test city' else None)
                self.assertTrue(row['dns_fallback_used'])
                self.assertEqual(calls[-1]['locations'], [{'magic': '4837', 'limit': 1}])
                self.assertEqual(calls[-1]['measurementOptions']['resolver'], '119.29.29.29')
                self.assertTrue(all(p['measurementOptions']['resolver'] == '223.5.5.5' for p in calls[:3]))

    def test_tls_or_download_failure_never_switches_dns_or_accepts_partial_response(self):
        self.target()
        for raw in ['TLS handshake timed out', 'Response download timed out']:
            calls = []
            def fake_api(path, payload=None):
                if payload:
                    calls.append(payload); return {'id': str(payload['locations'][0]['asn'])}
                asn = int(path.rsplit('/', 1)[-1])
                return self.measurement(asn, status='failed' if asn == 4837 else 'finished', raw=raw)
            with self.subTest(raw=raw), patch('panel.reachability.api', side_effect=fake_api), patch.object(self.ctx.stop, 'wait', return_value=False):
                self.monitor.state = {}; self.monitor.run()
                self.assertEqual(len(calls), 3)
                self.assertFalse(next(r for r in self.monitor.snapshot()['rows'] if r['key'] == 'entry:unicom')['ok'])

    def test_one_provider_error_preserves_other_carriers_and_respects_backoff(self):
        self.target()
        def fake_api(path, payload=None):
            if payload: return {'id': str(payload['locations'][0]['asn'])}
            asn = int(path.rsplit('/', 1)[-1])
            if asn == 4837: raise ProviderError(429, 'rate_limit_exceeded', 1800)
            return self.measurement(asn)
        with patch('panel.reachability.api', side_effect=fake_api), patch.object(self.ctx.stop, 'wait', return_value=False): self.monitor.run()
        status = self.monitor.snapshot()
        self.assertEqual(sum(r['ok'] is True for r in status['rows']), 2)
        self.assertEqual(sum(r['ok'] is None for r in status['rows']), 1)
        self.assertIn('429', status['provider_error'])
        self.assertGreater(status['retry_at'], time.time() + 1700)
        self.monitor.state['resolvers'] = []  # settings changes must not bypass a provider cooldown
        with patch('panel.reachability.threading.Thread') as worker:
            self.assertFalse(self.monitor.start_if_due()); worker.assert_not_called()

    def test_provider_error_retains_only_status_type_and_retry_after(self):
        secret = 'test-only-private-token?key=fictional'
        error = urllib.error.HTTPError('https://example.test/' + secret, 429, secret,
            {'Retry-After': '7200'}, io.BytesIO(json.dumps({'error': {'type': 'rate_limit_exceeded', 'message': secret}}).encode()))
        with patch('panel.reachability.urllib.request.build_opener') as opener:
            opener.return_value.open.side_effect = error
            with self.assertRaises(ProviderError) as raised: api('/measurements')
        self.assertIn('429', str(raised.exception)); self.assertIn('rate_limit_exceeded', str(raised.exception))
        self.assertNotIn(secret, str(raised.exception)); self.assertEqual(raised.exception.retry_after, 3600)
        self.assertNotIn(secret, str(ProviderError(503, secret)))

    def test_other_city_cannot_close_fault_and_next_run_pins_failed_city(self):
        self.target()
        for _ in range(2): self.monitor.commit([dict(self.row(False), city='Fault city')])
        self.monitor.commit([dict(self.row(True), city='Other city')])
        row = self.monitor.snapshot()['rows'][0]
        self.assertIsNone(row['ok']); self.assertTrue(row['alarm']); self.assertEqual(row['failed_city'], 'Fault city')
        calls = []
        def fake_api(path, payload=None):
            if payload:
                calls.append(payload); return {'id': str(payload['locations'][0]['asn'])}
            return self.measurement(int(path.rsplit('/', 1)[-1]), city='Fault city')
        with patch('panel.reachability.api', side_effect=fake_api), patch.object(self.ctx.stop, 'wait', return_value=False): self.monitor.run()
        self.assertEqual(next(p for p in calls if p['locations'][0]['asn'] == 4837)['locations'][0]['city'], 'Fault city')
        row = next(r for r in self.monitor.snapshot()['rows'] if r['key'] == 'entry:unicom')
        self.assertTrue(row['ok']); self.assertFalse(row['alarm']); self.assertEqual(row['failed_city'], '')

    def test_new_resolver_configuration_gets_one_fresh_round(self):
        self.target()
        self.monitor.state = {'at': int(time.time())}
        with patch('panel.reachability.threading.Thread') as worker:
            self.assertTrue(self.monitor.start_if_due()); worker.return_value.start.assert_called_once()
        self.monitor.running = False
        self.monitor.commit([self.row(True)])
        with patch('panel.reachability.threading.Thread') as worker:
            self.assertFalse(self.monitor.start_if_due()); worker.assert_not_called()


class MediaAlertTest(unittest.TestCase):
    setUp = fixtures.DashboardTest.setUp
    tearDown = fixtures.DashboardTest.tearDown
    def test_target_rounds_ack_stale_and_recovery(self):
        self.ctx.settings.values['probes']['enabled'] = True
        # Use the actual structured outbound from the fixture.
        node = self.ctx.xray.rows['main'][0]
        tag = node['outbound']
        def save(at, ok):
            with patch('panel.xray.time.time', return_value=at):
                self.ctx.xray.ledger.save_probes([('main', tag, {'targets': {'Instagram': {'ok': int(ok), 'error': '' if ok else 'HTTP 403'}, 'YouTube': {'ok': 1}}})])
        save(self.now - 300, False)
        found = {}; self.ctx.alerts._xray_media(found); self.assertFalse(found)
        save(self.now, False)
        found = {}; self.ctx.alerts._xray_media(found)
        self.assertEqual(len(found), 1)
        self.assertIn('Instagram', next(iter(found.values()))[2])
        self.ctx.alerts._sync(found)
        self.ctx.alerts.ack(self.ctx.alerts.open_alerts()[0]['id'])
        for _ in range(3):
            found = {}; self.ctx.alerts._xray_media(found); self.ctx.alerts._sync(found)
        self.assertEqual(len(self.ctx.alerts.recent()), 1)
        with patch('panel.alerts.time.time', return_value=self.now + 2000):
            found = {}; self.ctx.alerts._xray_media(found)
        self.assertEqual(len(found), 2)  # unresolved media failure + unknown/stale monitor
        save(self.now + 1, True)
        found = {}; self.ctx.alerts._xray_media(found); self.ctx.alerts._sync(found)
        self.assertFalse(self.ctx.alerts.open_alerts())

    def test_round_gap_breaks_failure_streak(self):
        tag = self.ctx.xray.rows['main'][0]['outbound']
        for at in [self.now - 5000, self.now]:
            with patch('panel.xray.time.time', return_value=at):
                self.ctx.xray.ledger.save_probes([('main', tag, {'targets': {'Instagram': {'ok': 0}}})])
        self.assertEqual(self.ctx.xray.ledger.probe_health(2, 300)['main:' + tag]['Instagram']['failures'], 1)


class SingboxMediaAlertTest(unittest.TestCase):
    def setUp(self):
        self.root = helpers.make_env(extra={'probes': {'enabled': True, 'skip': ['decodo-us-10003', 'oxylabs-8001']}})
        self.app, self.ctx = helpers.make_app(self.root)
        self.now = int(time.time())
        self.ctx.health['started'] = self.now

    def tearDown(self):
        helpers.cleanup(self.root)

    def save(self, at, failed=(), omit=()):
        with self.ctx.store.write() as c:
            c.executemany('INSERT INTO probes VALUES(?,?,?,?,?,?,?,?,?,?)', [
                (at, 'direct', t['name'], int(t['name'] not in failed), '', '', '', 1, 2, 'HTTP 503' if t['name'] in failed else '')
                for t in self.ctx.settings.get('probes.targets') if t['name'] not in omit])

    def evaluate(self):
        found = {}; self.ctx.alerts._singbox_media(found); self.ctx.alerts._sync(found)
        return found

    def test_partial_media_failure_ack_restart_stale_missing_and_recovery(self):
        self.save(self.now - 300, ['Instagram']); self.assertFalse(self.evaluate())
        self.save(self.now, ['Instagram'])
        self.assertEqual(len(self.evaluate()), 1)
        row = self.ctx.alerts.open_alerts()[0]; self.assertEqual(row['kind'], 'media'); self.assertIn('Instagram', row['message'])
        self.ctx.alerts.ack(row['id'])
        for _ in range(3): self.evaluate()
        self.assertEqual(len(self.ctx.alerts.recent()), 1)
        self.ctx.prober = Prober(self.ctx.settings, self.ctx.topology, self.ctx.store, self.ctx.geo)
        self.assertIn(row['key'], self.evaluate())
        with patch('panel.alerts.time.time', return_value=self.now + 2000):
            self.assertEqual(len(self.evaluate()), 2)  # original fault + unknown/stale sampling
        self.save(self.now + 1, omit=['Instagram'])
        self.assertIn(row['key'], self.evaluate())  # another target cannot prove Instagram recovered
        self.save(self.now + 2)
        self.assertFalse(self.evaluate())
        self.assertTrue(all(r['resolved'] for r in self.ctx.alerts.recent()))

    def test_duplicate_timestamp_and_long_gap_do_not_inflate_failures(self):
        for _ in range(3): self.save(self.now, ['Instagram'])
        self.assertFalse(self.evaluate())
        self.assertEqual(self.ctx.prober.probe_health(2, 300)['direct']['Instagram']['failures'], 1)
        self.save(self.now + 5000, ['Instagram'])
        with patch('panel.alerts.time.time', return_value=self.now + 5000): self.assertFalse(self.evaluate())

    def test_skipped_disabled_and_xray_only_do_not_emit_legacy_alerts(self):
        self.save(self.now - 300, ['Instagram']); self.save(self.now, ['Instagram'])
        self.assertTrue(self.evaluate())
        self.ctx.settings.values['probes']['skip'].append('direct'); self.assertFalse(self.evaluate())
        self.ctx.settings.values['probes']['skip'].remove('direct')
        self.ctx.singbox_enabled = False
        with patch.object(self.ctx.prober, 'probe_health') as read:
            self.assertFalse(self.evaluate()); read.assert_not_called()
        self.ctx.singbox_enabled = True; self.ctx.settings.values['probes']['enabled'] = False
        self.assertFalse(self.evaluate())

    def test_all_exit_failure_identity_remains_latched_until_fresh_success(self):
        names = [t['name'] for t in self.ctx.settings.get('probes.targets')]
        self.save(self.now - 300, names); self.save(self.now, names)
        self.assertIn('probe:direct', self.evaluate())
        with patch('panel.alerts.time.time', return_value=self.now + 2000): self.assertIn('probe:direct', self.evaluate())
        self.save(self.now + 2000, names)
        with patch('panel.alerts.time.time', return_value=self.now + 2000): self.assertIn('probe:direct', self.evaluate())
        self.save(self.now + 2001, ['Instagram'])
        self.assertNotIn('probe:direct', self.evaluate())
        self.assertTrue(any(a['kind'] == 'media' for a in self.ctx.alerts.open_alerts()))

    def test_aborted_worker_is_safe_persistent_and_does_not_count_partial_round(self):
        self.save(self.now - 300, ['Instagram'])
        with patch('panel.probes.probe', side_effect=RuntimeError('fictional-password-must-not-leak')):
            self.assertEqual(self.ctx.prober.run(), [])
        self.assertFalse(self.ctx.prober.running)
        self.assertEqual(self.ctx.prober.error, 'RuntimeError')
        self.ctx.prober = Prober(self.ctx.settings, self.ctx.topology, self.ctx.store, self.ctx.geo)
        found = self.evaluate()
        self.assertEqual(set(found), {'singbox:probe-worker'})
        self.assertNotIn('fictional-password', json.dumps(found))
        self.assertEqual(self.ctx.prober.probe_health(2, 300)['direct']['Instagram']['failures'], 1)

    def test_real_loopback_http_rounds_persist_and_alert_only_failed_media(self):
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(503 if self.path == '/instagram' else 204)
                self.send_header('Content-Length', '0'); self.end_headers()
            def log_message(self, *_args): pass
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        worker = threading.Thread(target=server.serve_forever, daemon=True); worker.start()
        try:
            url = 'http://127.0.0.1:' + str(server.server_port)
            self.ctx.settings.values['probes']['targets'] = [
                {'name': 'Instagram', 'url': url + '/instagram', 'kind': 'http'},
                {'name': 'YouTube', 'url': url + '/youtube', 'kind': 'http'}]
            self.ctx.prober.error = 'OldError'
            for at in [self.now - 300, self.now]:
                with patch('panel.probes.time.time', return_value=at): self.assertEqual(len(self.ctx.prober.run()), 2)
            found = self.evaluate(); self.assertEqual(len(found), 1)
            self.assertIn('Instagram', next(iter(found.values()))[2])
            self.assertFalse(self.ctx.prober.error)
            restarted = Prober(self.ctx.settings, self.ctx.topology, self.ctx.store, self.ctx.geo)
            self.assertFalse(restarted.error)
            self.assertEqual(restarted.probe_health(2, 300)['direct']['Instagram']['failures'], 2)
        finally:
            server.shutdown(); server.server_close(); worker.join(timeout=3)


class AlertSourceScopeTest(unittest.TestCase):
    setUp = fixtures.DashboardTest.setUp
    tearDown = fixtures.DashboardTest.tearDown

    def test_lists_badges_shared_mainland_and_ack_are_scoped_for_both_engines(self):
        found = {key: ('monitor', 'warning', key) for key in ['xray:main', 'singbox:probe-worker', 'probe:direct',
            'reachability:entry:unicom', 'cert', 'disk', 'service:nginx.service', 'service:' + self.ctx.xray.instances[0]['service']]}
        self.ctx.alerts._sync(found)
        xray = self.client.get('/monitor/api/alerts?engine=xray').get_json()
        singbox = self.client.get('/monitor/api/alerts?engine=singbox').get_json()
        keys = lambda data: {r['key'] for r in data['open']}
        shared = {'reachability:entry:unicom', 'cert', 'disk'}
        self.assertTrue(shared <= keys(xray) & keys(singbox))
        self.assertIn('singbox:probe-worker', keys(singbox)); self.assertNotIn('xray:main', keys(singbox))
        self.assertNotIn('singbox:probe-worker', keys(xray)); self.assertNotIn('probe:direct', keys(xray))
        self.assertNotIn('service:' + self.ctx.xray.instances[0]['service'], keys(singbox))
        before = self.client.get('/monitor/api/overview').get_json()
        self.assertEqual(before['alerts'], len(singbox['open'])); self.assertEqual(before['alerts_xray'], len(xray['open']))
        headers = {'Origin': helpers.ORIGIN, 'X-CSRF-Token': self.csrf}
        private = next(r for r in xray['open'] if r['key'] == 'xray:main')
        self.assertEqual(self.client.post('/monitor/api/alerts/ack', json={'id': private['id'], 'engine': 'singbox'}, headers=headers).status_code, 404)
        self.assertEqual(self.client.post('/monitor/api/alerts/ack', json={'engine': 'singbox'}, headers=headers).status_code, 200)
        after = self.client.get('/monitor/api/overview').get_json()
        self.assertEqual(after['alerts'], 0); self.assertGreater(after['alerts_xray'], 0)
        self.assertTrue(all(r['acked'] for r in self.client.get('/monitor/api/alerts?engine=singbox').get_json()['open']))
        self.assertFalse(next(r for r in self.ctx.alerts.open_alerts() if r['key'] == 'xray:main')['acked'])
        self.assertEqual(self.client.get('/monitor/api/alerts?engine=invalid').status_code, 400)
        self.assertEqual(self.client.post('/monitor/api/alerts/ack', json={'engine': 'invalid'}, headers=headers).status_code, 400)
        self.assertEqual(self.client.post('/monitor/api/alerts/ack', json={'engine': 'xray'}).status_code, 403)
        self.assertEqual(self.app.test_client().get('/monitor/api/alerts?engine=singbox').status_code, 401)


if __name__ == '__main__':
    unittest.main()
