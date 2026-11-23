"""Public downloads must not acquire management privileges or reveal other files."""
import hashlib
import json
import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from flask import Flask
from helpers import cleanup, make_app, make_env, login, ORIGIN
from manager import Manager
from panel import subscriptions as sub
from admin import reset_password


class SubscriptionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.work, self.published = self.root / 'work', self.root / 'published'
        (self.work / 'subscribe').mkdir(parents=True)
        self.token = 'private-test-token-' + 'x' * 32
        self.files = {'clash': 'proxy-providers:\n  nodes:\n    url: "http://203.0.113.10:17660/old-token/proxies"\n',
                      'clash2': 'proxies:\n  - {name: node, server: 203.0.113.10, password: private-node-password, servername: node.trycloudflare.com}\n',
                      'proxies': 'proxies: []\n', 'shadowrocket': 'base64-client-config', 'sing-box': '{"outbounds":[]}'}
        for name, data in self.files.items():
            (self.work / 'subscribe' / name).write_text(data)
        self.manifest = sub.publish(self.work, self.published, 'https://sub.example.test', self.token)
        self.app = Flask(__name__)
        sub.register(self.app, self.published)
        self.client = self.app.test_client()

    def tearDown(self):
        self.tmp.cleanup()

    def test_no_cookie_needed_but_token_format_and_methods_are_enforced(self):
        path = '/sub/' + self.token + '/auto'
        for agent, expected in [('Clash.Meta', self.files['clash2']), ('mihomo', self.files['clash2']),
                                ('Shadowrocket', self.files['shadowrocket']), ('SFA', self.files['sing-box']),
                                ('Mozilla/5.0', self.files['clash2'])]:
            response = self.client.get(path, headers={'User-Agent': agent})
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.text, expected)
            self.assertIn('no-store', response.headers['Cache-Control'])
        self.assertEqual(self.client.head(path).status_code, 200)
        self.assertEqual(self.client.get('/sub/wrong/auto').status_code, 404)
        self.assertEqual(self.client.get('/sub/' + self.token + '/manifest.json').status_code, 404)
        self.assertEqual(self.client.get('/sub/' + self.token + '/../../config.json').status_code, 404)
        self.assertEqual(self.client.post(path).status_code, 405)
        self.assertEqual(self.client.get('/monitor/api/manage/status').status_code, 404)

    def test_fixed_origin_only_rewrites_provider_url_and_is_atomic(self):
        original = (self.work / 'subscribe/clash').read_text()
        before = (self.published / 'current').resolve()
        sub.publish(self.work, self.published, 'https://new.example.test', self.token)
        self.assertNotEqual(before, (self.published / 'current').resolve())
        self.assertEqual((self.work / 'subscribe/clash').read_text(), original)
        self.assertEqual((self.published / 'current/clash2').read_text(), self.files['clash2'])
        self.assertIn('https://new.example.test/sub/' + self.token + '/proxies', (self.published / 'current/clash').read_text())
        self.assertEqual(sub.read_manifest(self.published)['token'], self.token)
        for origin in ('http://insecure.example', 'https://user:pw@example.com', 'https://example.com/path',
                       'https://example.com?x=1', 'https://example.com:99999', 'https://example.com\\evil', 'https://a.example\nHost: bad'):
            with self.assertRaises(ValueError): sub.publish(self.work, self.published, origin, self.token)
        self.assertEqual(sub.read_manifest(self.published)['origin'], 'https://new.example.test')

    def test_manager_export_origin_survives_new_instance_and_token_stays_fixed(self):
        cfg = {'script': str(self.root / 'script.sh'), 'work_dir': str(self.work), 'data_dir': str(self.root / 'manager'),
               'subscription_dir': str(self.published), 'public_url': ORIGIN}
        manager = Manager(cfg)
        first = manager.publish_subscriptions()
        second = manager.publish_subscriptions('https://sub.example.test')
        third = Manager(cfg).publish_subscriptions()
        self.assertEqual(first['token'], second['token'])
        self.assertEqual(second, third)
        self.assertEqual(third['origin'], 'https://sub.example.test')
        self.assertEqual((Path(cfg['data_dir']) / 'subscription.json').stat().st_mode & 0o777, 0o600)

    def test_panel_download_does_not_bypass_api_authentication(self):
        root = make_env(extra={'management': {'enabled': True, 'subscription_dir': str(self.published)}})
        try:
            app, ctx = make_app(root)
            client = app.test_client()
            self.assertEqual(client.get('/sub/' + self.token + '/auto').status_code, 200)
            self.assertEqual(client.get('/monitor/api/manage/subscriptions').status_code, 401)
            csrf, _ = login(client)
            self.assertEqual(client.post('/monitor/api/manage/subscription', json={'origin': 'https://sub.example.test'}).status_code, 403)
            with patch('panel.management.call', return_value=({'job': {'id': '1'}}, 200)):
                self.assertEqual(client.post('/monitor/api/manage/subscription', json={'origin': 'https://sub.example.test'},
                                            headers={'Origin': ORIGIN, 'X-CSRF-Token': csrf}).status_code, 200)
        finally:
            cleanup(root)


class RecoveryTests(unittest.TestCase):
    def test_password_reset_revokes_sessions_and_preserves_history_and_other_secrets(self):
        root = make_env()
        try:
            app, ctx = make_app(root)
            client = app.test_client()
            login(client)
            cfg = json.loads((root / 'config.json').read_text())
            before_totals = ctx.store.totals()
            login_path = root / 'new-login.txt'
            reset_password(root, login_path)
            updated = json.loads((root / 'config.json').read_text())
            for field in ('username', 'api_secret', 'origin_guard'):
                self.assertEqual(updated[field], cfg[field])
            password = login_path.read_text().split('密码：', 1)[1].strip()
            digest = hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(updated['salt']), 600000).hex()
            self.assertEqual(digest, updated['password_hash'])
            self.assertEqual(login_path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(client.get('/monitor/api/overview').status_code, 401)
            self.assertEqual(ctx.store.totals(), before_totals)
        finally:
            cleanup(root)
