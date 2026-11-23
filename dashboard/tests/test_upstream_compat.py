"""The upstream engine switch must retain this fork's admin and download boundary."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from helpers import ORIGIN, cleanup, login, make_app, make_env
from panel import subscriptions


class ForkCompatibilityTest(unittest.TestCase):
    def test_optional_xray_keeps_management_and_public_subscription_separate(self):
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp) / 'work'; (work / 'subscribe').mkdir(parents=True)
            (work / 'subscribe/clash2').write_text('proxies: []\n')
            published = Path(tmp) / 'published'; token = 'fixture-token-' + 'x' * 32
            subscriptions.publish(work, published, ORIGIN, token)
            root = make_env(extra={'management': {'enabled': True, 'subscription_dir': str(published)},
                'xray': {'instances': [{'id': 'main', 'service': 'xray.service', 'api_address': '127.0.0.1:8311',
                                       'config_path': '/nonexistent/fixture-xray.json'}]}})
            try:
                app, ctx = make_app(root); client = app.test_client()
                self.assertEqual(client.get('/sub/' + token + '/auto').status_code, 200)
                self.assertEqual(client.get('/monitor/api/manage/status').status_code, 401)
                csrf, _ = login(client)
                overview = client.get('/monitor/api/overview').get_json()
                self.assertTrue(overview['features']['management'])
                self.assertTrue(overview['singbox_enabled'])
                self.assertEqual(overview['primary_engine'], 'xray')
                with patch('panel.management.call', return_value=({'job': {'id': 'compat'}}, 200)) as call:
                    self.assertEqual(client.post('/monitor/api/manage/subscription', json={'origin': ORIGIN}).status_code, 403)
                    self.assertEqual(client.post('/monitor/api/manage/subscription', json={'origin': ORIGIN},
                        headers={'Origin': ORIGIN, 'X-CSRF-Token': csrf}).status_code, 200)
                    call.assert_called_once()
                with patch('panel.system.services', return_value={}) as services, patch('panel.system.xray_runtimes', return_value=[]):
                    self.assertEqual(client.get('/monitor/api/system').status_code, 200)
                    self.assertIn('xray.service', services.call_args.args[0])
                    self.assertNotIn('joysol-dashboard.service', services.call_args.args[0])
                with patch('panel.reachability.api') as public_api:
                    self.assertFalse(ctx.reachability.start_if_due())
                    public_api.assert_not_called()
                ctx.stop.set()
                for peer in ctx.xray.clients.values(): peer.channel.close()
                ctx.xray.ledger.db.close()
            finally:
                cleanup(root)
