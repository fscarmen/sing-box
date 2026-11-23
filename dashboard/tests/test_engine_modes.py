"""Both install profiles, without a production server or firewall."""
import json
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

import helpers
from panel import settings as settings_mod


class EngineModesTest(unittest.TestCase):
    def setUp(self):
        self.instance = {'id': 'main', 'label': 'Test Xray', 'service': 'xray.service',
                         'api_address': '127.0.0.1:8311', 'config_path': '/nonexistent/test-xray.json'}
        self.root = helpers.make_env(extra={'singbox': {'enabled': False}, 'xray': {'instances': [self.instance]}})
        path = self.root / 'config.json'
        secrets = json.loads(path.read_text()); secrets.pop('api_secret'); path.write_text(json.dumps(secrets))
        self.firewall = helpers.FakeFirewall()
        self.app, self.ctx = helpers.make_app(self.root, self.firewall)
        self.client = self.app.test_client()
        self.csrf, _ = helpers.login(self.client)

    def tearDown(self):
        self.ctx.stop.set()
        for client in self.ctx.xray.clients.values(): client.channel.close()
        self.ctx.xray.ledger.db.close()
        helpers.cleanup(self.root)

    def test_xray_only_without_singbox_config_or_api_secret(self):
        self.assertFalse(self.ctx.singbox_enabled)
        self.assertNotIn('api_secret', self.ctx.settings.secrets)
        self.assertFalse(self.ctx.topology.describe()['inbounds'])
        with patch('panel.topology.os.stat') as stat:
            self.ctx.topology.refresh()
            stat.assert_not_called()
        overview = self.client.get('/monitor/api/overview').get_json()
        self.assertEqual(overview['primary_engine'], 'xray')
        self.assertFalse(overview['singbox_enabled'])
        self.assertFalse(overview['features']['stream'])

    def test_startup_and_maintenance_do_not_manage_singbox_or_firewall(self):
        with patch('panel.threading.Thread'), patch('panel.collector.Collector') as collector, patch.object(self.ctx.bans, 'enforce_all') as enforce:
            self.ctx.start()
            collector.assert_not_called(); enforce.assert_not_called()
        with patch.object(self.ctx.bans, 'expire') as expire, patch.object(self.ctx.prober, 'due') as due:
            self.ctx._expire_bans(); self.ctx._probe_if_due()
            expire.assert_not_called(); due.assert_not_called()
        self.assertIsNone(self.ctx.collector)
        self.assertFalse(self.firewall.calls)

    def test_disabled_legacy_mutations_and_stream_are_explicitly_rejected(self):
        headers = {'Origin': helpers.ORIGIN, 'X-CSRF-Token': self.csrf}
        for path in ['ban', 'connections/close', 'probes/run']:
            result = self.client.post('/monitor/api/' + path, json={'action': 'ban', 'ip': '203.0.113.7', 'id': 'fixture'}, headers=headers)
            self.assertEqual(result.status_code, 409)
        self.assertEqual(self.client.get('/monitor/api/stream').status_code, 409)
        self.assertFalse(self.firewall.calls)
        self.assertEqual(self.app.test_client().post('/monitor/api/ban', json={}).status_code, 401)
        self.assertEqual(self.client.post('/monitor/api/ban', json={}).status_code, 403)

    def test_disabled_collector_does_not_create_alert(self):
        self.ctx.health['started'] = time.time() - 3600
        self.ctx.xray.states['main'] = {'id': 'main', 'label': 'Test Xray', 'connected': True, 'last_success': time.time(), 'error': ''}
        with patch('panel.system.certificate', return_value={}), patch('panel.system.disk', return_value={'percent': 10}):
            self.ctx.alerts.evaluate()
        self.assertFalse(self.ctx.alerts.open_alerts())
        health = self.client.get('/internal/health').get_json()
        self.assertEqual(health['primary_engine'], 'xray')
        self.assertTrue(health['ok'])
        self.assertFalse(health['health']['enabled'])
        self.ctx.xray.states['main']['last_success'] -= 30
        self.assertFalse(self.client.get('/internal/health').get_json()['ok'])

    def test_legacy_mode_remains_enabled_by_default(self):
        root = helpers.make_env()
        try:
            _, ctx = helpers.make_app(root)
            self.assertTrue(ctx.singbox_enabled)
            self.assertTrue(ctx.topology.describe()['inbounds'])
        finally:
            helpers.cleanup(root)

    def test_reject_no_engine_or_non_boolean_switch(self):
        for extra in [{'singbox': {'enabled': False}}, {'singbox': {'enabled': 'false'}}]:
            root = helpers.make_env(extra=extra)
            try:
                with self.assertRaises(ValueError): helpers.make_app(root)
            finally:
                helpers.cleanup(root)

    def test_public_xray_profile_and_service_need_no_firewall_privileges(self):
        deploy = Path(__file__).resolve().parents[1] / 'deploy'
        profile = json.loads((deploy / 'settings.xray.example.json').read_text())
        values = settings_mod.merge(settings_mod.DEFAULTS, profile)
        settings_mod.validate(values, self.ctx.settings.secrets)
        self.assertFalse(profile['singbox']['enabled'])
        self.assertEqual(profile['xray']['instances'][0]['api_address'], '127.0.0.1:8311')
        unit = (deploy / 'vps-dashboard-xray.service').read_text()
        self.assertIn('127.0.0.1:8307', unit)
        self.assertNotIn('CAP_NET_ADMIN', unit)
        self.assertNotIn('/run/xtables.lock', unit)


class XrayAccessControlTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='xray-acl-')
        core = Path(self.tmp.name) / 'xray.json'
        core.write_text(json.dumps({'inbounds': [
            {'tag': 'reality', 'protocol': 'vless', 'port': 443, 'settings': {'clients': []}, 'streamSettings': {'network': 'raw'}},
            {'tag': 'ws', 'protocol': 'vless', 'listen': '127.0.0.1', 'port': 10080, 'settings': {'clients': []}, 'streamSettings': {'network': 'ws'}}],
            'outbounds': [{'tag': 'direct', 'protocol': 'freedom'}]}))
        instance = {'id': 'main', 'label': 'Test Xray', 'service': 'xray.service', 'api_address': '127.0.0.1:8311', 'config_path': str(core)}
        self.root = helpers.make_env(extra={'singbox': {'enabled': False}, 'xray': {'instances': [instance], 'access_control': True}})
        self.firewall = helpers.FakeFirewall()
        self.app, self.ctx = helpers.make_app(self.root, self.firewall)
        self.client = self.app.test_client()
        self.csrf, _ = helpers.login(self.client)

    def tearDown(self):
        for client in self.ctx.xray.clients.values(): client.channel.close()
        self.ctx.xray.ledger.db.close()
        helpers.cleanup(self.root); self.tmp.cleanup()

    def test_bans_cover_public_xray_ports_and_gate_only(self):
        headers = {'Origin': helpers.ORIGIN, 'X-CSRF-Token': self.csrf}
        self.assertTrue(self.ctx.bans_enabled)
        self.assertEqual(self.ctx.public_endpoints(), [('tcp', 443)], 'loopback WS behind Nginx is left to the gate')
        r = self.client.post('/monitor/api/ban', json={'action': 'ban', 'ip': '8.8.4.4'}, headers=headers)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(self.firewall.jumps, {('tcp', 443, 'JOYSOL_NODE_BANS')})
        self.assertIn(('JOYSOL_NODE_BANS', '-p', 'tcp', '-s', '8.8.4.4', '-j', 'REJECT', '--reject-with', 'tcp-reset'), self.firewall.rules)
        gate = {'X-Origin-Guard': 'g' * 64, 'X-ESA-Client-IP': '8.8.4.4'}
        self.assertEqual(self.client.get('/internal/gate', headers=gate).status_code, 403)
        self.assertTrue(self.client.get('/monitor/api/overview').get_json()['features']['xray_bans'])
        self.assertEqual(self.client.post('/monitor/api/connections/close', json={'id': 'x'}, headers=headers).status_code, 409)
        r = self.client.post('/monitor/api/ban', json={'action': 'unban', 'ip': '8.8.4.4'}, headers=headers)
        self.assertEqual(r.status_code, 200)
        self.assertFalse(self.firewall.rules)

    def test_access_control_must_be_boolean(self):
        values = settings_mod.merge(settings_mod.DEFAULTS, {'xray': {'access_control': 'yes'}})
        with self.assertRaises(ValueError):
            settings_mod.validate(values, self.ctx.settings.secrets)


if __name__ == '__main__':
    unittest.main()
