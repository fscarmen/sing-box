"""Client routing is independent of VPS routes, nodes, tokens and core lifecycle."""
import copy
import http.server
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
import yaml
from flask import Flask

from helpers import ORIGIN, cleanup, login, make_app, make_env, conn, batch, event
from manager import Manager
from panel import client_rules as rules, subscriptions as sub


def policy():
    return rules.validate({'default_action': 'inherit', 'rules': [
        {'id': 'exact', 'type': 'domain', 'target': 'api.example.com', 'action': 'direct', 'enabled': True, 'note': 'history'},
        {'id': 'suffix', 'type': 'domain_suffix', 'target': 'example.com', 'action': 'proxy', 'enabled': True},
        {'id': 'ip', 'type': 'ip_cidr', 'target': '2001:db8::1234/64', 'action': 'reject', 'enabled': True},
        {'id': 'off', 'type': 'domain', 'target': 'disabled.example.com', 'action': 'reject', 'enabled': False}]})


def raw_files():
    node = {'name': 'fixture-node', 'type': 'socks5', 'server': '127.0.0.1', 'port': 19090, 'username': 'fixture-user', 'password': 'fixture-node-password'}
    clash = yaml.safe_dump({'mixed-port': 7890, 'mode': 'global', 'proxies': [node],
        'proxy-groups': [{'name': 'Original', 'type': 'select', 'proxies': ['fixture-node', 'DIRECT']}],
        'rules': ['DOMAIN,base.example.org,DIRECT', 'MATCH,Original']}, allow_unicode=True)
    single = {'outbounds': [{'type': 'socks', 'tag': 'fixture-node', 'server': '127.0.0.1', 'server_port': 19090, 'username': 'fixture-user', 'password': 'fixture-node-password'},
                           {'type': 'direct', 'tag': 'direct'}],
        'route': {'final': 'fixture-node', 'rules': [{'action': 'sniff'}, {'protocol': 'dns', 'action': 'hijack-dns'}, {'domain': ['base.example.org'], 'action': 'route', 'outbound': 'direct'}]}}
    return {'clash': clash, 'clash2': clash, 'sing-box': json.dumps(single), 'proxies': 'proxies: []\n',
            'shadowrocket': 'node-only-subscription', 'v2rayn': 'node-only-v2rayn', 'throne': 'node-only-throne'}


class CompilerTest(unittest.TestCase):
    def test_normalizes_targets_and_rejects_injected_rules(self):
        self.assertEqual(rules.normalize_target('domain', 'ExAmPlE.COM.'), 'example.com')
        self.assertEqual(rules.normalize_target('domain_suffix', '.example.com'), 'example.com')
        self.assertEqual(rules.normalize_target('ip_cidr', '203.0.113.12'), '203.0.113.12/32')
        self.assertEqual(rules.normalize_target('domain', '例子.测试'), 'xn--fsqu00a.xn--0zwm56d')
        for kind, target in [('domain', 'http://example.com'), ('domain', 'example.com:443'), ('domain', 'a.com,DIRECT'),
                             ('domain_suffix', '*.example.com'), ('ip_cidr', 'bad/32'), ('domain', '127.0.0.1'),
                             ('domain', 'a.com\nMATCH,DIRECT'), ('domain_keyword', 'a,REJECT')]:
            with self.assertRaises(ValueError): rules.normalize_target(kind, target)
        for mutate in (lambda p: p['rules'].append(copy.deepcopy(p['rules'][0])), lambda p: p['rules'][0].update(action='shell'),
                       lambda p: p['rules'][0].update(enabled=1), lambda p: p.update(default_action='invalid')):
            value = policy(); mutate(value)
            with self.assertRaises(ValueError): rules.validate(value)

    def test_history_uses_destination_without_source_or_port_and_first_match_wins(self):
        for text, expected in [('api.example.com:443', {'type': 'domain', 'target': 'api.example.com'}),
                               ('203.0.113.17:443', {'type': 'ip_cidr', 'target': '203.0.113.17/32'}),
                               ('[2001:db8::7]:443', {'type': 'ip_cidr', 'target': '2001:db8::7/128'})]:
            self.assertEqual(rules.candidate(text), expected)
        self.assertIsNone(rules.candidate('未知'))
        self.assertIsNone(rules.candidate('https://example.com/path'))
        self.assertEqual(rules.match_target(policy(), 'api.example.com')['id'], 'exact')
        self.assertEqual(rules.match_target(policy(), 'child.example.com')['id'], 'suffix')
        self.assertIsNone(rules.match_target(policy(), 'notexample.com'))
        self.assertEqual(rules.match_target(policy(), '[2001:db8::7]:443')['action'], 'reject')

    def test_empty_policy_does_not_change_existing_subscription_bytes(self):
        for name, text in raw_files().items(): self.assertEqual(rules.render(name, text, rules.EMPTY), text)

    def test_clash_preserves_nodes_base_rules_and_selects_real_proxy_group(self):
        original = yaml.safe_load(raw_files()['clash2'])
        value = yaml.safe_load(rules.render('clash2', raw_files()['clash2'], policy()))
        self.assertEqual(value['proxies'], original['proxies'])
        self.assertEqual(value['rules'][0], 'DOMAIN,api.example.com,DIRECT')
        self.assertEqual(value['rules'][1], 'DOMAIN-SUFFIX,example.com,面板代理')
        self.assertEqual(value['rules'][2], 'IP-CIDR6,2001:db8::/64,REJECT,no-resolve')
        self.assertEqual(value['rules'][-2:], original['rules'])
        self.assertEqual(value['proxy-groups'][-1]['proxies'], ['fixture-node'])
        self.assertEqual(value['mode'], 'rule')
        self.assertNotIn('disabled.example.com', '\n'.join(value['rules']))
        providers = yaml.safe_dump({'proxy-providers': {'live': {'type': 'http', 'url': 'https://example.test/sub/token/proxies'}}, 'rules': []})
        provider_value = rules.clash_document(providers, policy())
        self.assertEqual(provider_value['proxy-groups'][-1]['use'], ['live'])

    def test_yaml_credential_spelling_and_aliases_survive_rule_updates(self):
        for password in ('001234', 'on', 'off', '2026-10-27'):
            text = raw_files()['clash2'].replace('password: fixture-node-password', 'password: ' + password)
            original = yaml.load(text, Loader=yaml.BaseLoader)
            output = yaml.load(rules.render('clash2', text, policy()), Loader=yaml.BaseLoader)
            self.assertEqual(output['proxies'], original['proxies'])
        text = """proxies:
  - &node {name: original, type: socks5, server: 127.0.0.1, port: 19090, password: 001234}
proxy-groups:
  - {name: Existing, type: select, proxies: [original]}
custom-metadata: *node
rules: [MATCH,Existing]
"""
        # The quoted rule is required to be a single rule string in a flow sequence.
        text = text.replace('[MATCH,Existing]', '["MATCH,Existing"]')
        out = yaml.load(rules.render('clash2', text, policy()), Loader=yaml.BaseLoader)
        self.assertIs(out['proxies'][0], out['custom-metadata'])
        self.assertEqual(out['proxies'][0]['password'], '001234')

    def test_singbox_infrastructure_and_node_credentials_preserved(self):
        original = json.loads(raw_files()['sing-box'])
        value = json.loads(rules.render('sing-box', raw_files()['sing-box'], policy()))
        self.assertEqual(value['outbounds'], original['outbounds'])
        self.assertEqual(value['route']['rules'][:2], original['route']['rules'][:2])
        self.assertEqual(value['route']['rules'][2], {'domain': ['api.example.com'], 'action': 'route', 'outbound': 'direct'})
        self.assertEqual(value['route']['rules'][4], {'ip_cidr': ['2001:db8::/64'], 'action': 'reject'})
        self.assertEqual(value['route']['rules'][-1], original['route']['rules'][-1])

    def test_default_action_overrides_only_fallback(self):
        p = policy(); p['default_action'] = 'reject'
        clash = rules.clash_document(raw_files()['clash2'], p)
        self.assertEqual(clash['rules'][-1], 'MATCH,REJECT')
        self.assertEqual(len([r for r in clash['rules'] if r.startswith('MATCH,')]), 1)
        self.assertIn('DOMAIN,base.example.org,DIRECT', clash['rules'])
        single = rules.singbox_document(raw_files()['sing-box'], p)
        self.assertEqual(single['route']['rules'][-1], {'action': 'reject'})
        p['default_action'] = 'direct'
        self.assertEqual(rules.singbox_document(raw_files()['sing-box'], p)['route']['final'], 'direct')

    def test_shadowrocket_v2rayn_are_separate_rule_downloads_not_node_subscriptions(self):
        config = rules.shadowrocket(policy(), 'https://sub.example.test/sub/opaque/shadowrocket.conf')
        self.assertIn('[General]\nupdate-url = https://', config)
        self.assertIn('DOMAIN,api.example.com,DIRECT', config)
        self.assertTrue(config.endswith('FINAL,PROXY\n'))
        value = rules.v2rayn(policy())
        self.assertEqual(value[0]['domain'], ['full:api.example.com'])
        self.assertEqual(value[1]['domain'], ['domain:example.com'])
        self.assertEqual(value[2]['ip'], ['2001:db8::/64'])
        for name in ('shadowrocket', 'v2rayn', 'throne', 'proxies'):
            self.assertEqual(rules.render(name, raw_files()[name], policy()), raw_files()[name])


class RulePublicationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.root = Path(self.temp.name)
        self.directory = self.root / 'public'
        self.manager = Manager({'script': str(self.root / 'no-script'), 'data_dir': str(self.root / 'manager'),
            'work_dir': str(self.root / 'no-installed-core'), 'subscription_dir': str(self.directory), 'public_url': ORIGIN})
        self.tokens = {'singbox': 's' * 40, 'xray': 'x' * 40}
        for engine in ('singbox', 'xray'):
            work = self.root / engine / 'subscribe'; work.mkdir(parents=True)
            for name, text in raw_files().items(): (work / name).write_text(text)
            sub.publish(work.parent, self.directory / ('xray' if engine == 'xray' else ''), ORIGIN, self.tokens[engine])
        self.app = Flask(__name__); sub.register(self.app, self.directory)
        self.client = self.app.test_client()

    def tearDown(self): self.temp.cleanup()

    def task(self, payload):
        data = self.manager.request('rules-save', payload)
        deadline = time.monotonic() + 5
        while self.manager.lock.locked() and time.monotonic() < deadline: time.sleep(.01)
        self.assertFalse(self.manager.lock.locked())
        return json.loads((self.manager.jobs / (data['job']['id'] + '.json')).read_text())

    def test_atomic_global_policy_updates_both_core_urls_without_services_or_reexport(self):
        before = {e: sub.read_manifest(self.directory / ('xray' if e == 'xray' else '')) for e in self.tokens}
        with patch.object(self.manager, 'run', side_effect=AssertionError('rules must not restart a service')):
            job = self.task({'policy': policy(), 'revision': rules.revision(rules.EMPTY)})
        self.assertEqual(job['state'], 'succeeded', job)
        for engine, token in self.tokens.items():
            folder = self.directory / ('xray' if engine == 'xray' else '')
            response = self.client.get('/sub/' + token + '/auto')
            self.assertIn('DOMAIN,api.example.com,DIRECT', response.text)
            self.assertEqual(response.headers['X-Client-Rules-Revision'], rules.revision(policy()))
            self.assertEqual(sub.read_manifest(folder), before[engine])
            self.assertEqual((folder / 'current/clash2').read_text(), raw_files()['clash2'])
            shadow = self.client.get('/sub/' + token + '/shadowrocket.conf').text
            self.assertIn('FINAL,PROXY', shadow)
            self.assertEqual(self.client.get('/sub/' + token + '/shadowrocket').text, 'node-only-subscription')
            self.assertEqual(self.client.get('/sub/' + token + '/client-rules.json').status_code, 404)
        self.assertEqual((self.directory / rules.RULE_FILE).stat().st_mode & 0o777, 0o640)
        self.assertTrue(list((self.manager.data / 'client-rule-backups').glob('*.json')))

    def test_stale_and_invalid_saves_preserve_previous_policy_and_downloads(self):
        first = self.task({'policy': policy(), 'revision': rules.revision(rules.EMPTY)})
        self.assertEqual(first['state'], 'succeeded')
        before = (self.directory / rules.RULE_FILE).read_bytes()
        self.assertEqual(self.task({'policy': rules.EMPTY, 'revision': 'outdated'})['state'], 'failed')
        bad = policy(); bad['rules'][0]['target'] = 'example.com\nMATCH,DIRECT'
        self.assertEqual(self.task({'policy': bad, 'revision': rules.revision(policy())})['state'], 'failed')
        self.assertEqual((self.directory / rules.RULE_FILE).read_bytes(), before)

    def test_reexport_and_new_manager_keep_policy_and_token_but_remove_restores_base(self):
        self.task({'policy': policy(), 'revision': rules.revision(rules.EMPTY)})
        root = self.root / 'singbox'
        again = sub.publish(root, self.directory, ORIGIN, self.tokens['singbox'])
        self.assertEqual(again['token'], self.tokens['singbox'])
        self.assertEqual(rules.load(self.directory), policy())
        manager = Manager(self.manager.cfg)
        self.assertEqual(manager.request('rules', {})['policy'], policy())
        job = self.task({'policy': rules.EMPTY, 'revision': rules.revision(policy())})
        self.assertEqual(job['state'], 'succeeded')
        self.assertEqual(self.client.get('/sub/' + self.tokens['singbox'] + '/auto').text, raw_files()['clash2'])

    def test_rules_preview_never_exposes_node_password_and_corrupt_policy_fails_closed(self):
        data = self.manager.rules_view()
        self.assertNotIn('fixture-node-password', json.dumps(data))
        self.assertTrue(any(c['base']['rules'] for c in data['clients'] if c['format'] == 'clash2'))
        (self.directory / rules.RULE_FILE).write_text('{broken')
        self.assertEqual(self.client.get('/sub/' + self.tokens['singbox'] + '/auto').status_code, 503)
        self.assertEqual(self.client.get('/sub/wrong/auto').status_code, 404)

    def test_preflight_failure_on_one_core_keeps_global_policy_unchanged(self):
        (self.directory / 'xray/current/clash2').write_text('proxies: []\nrules: []\n')
        job = self.task({'policy': policy(), 'revision': rules.revision(rules.EMPTY)})
        self.assertEqual(job['state'], 'failed')
        self.assertFalse((self.directory / rules.RULE_FILE).exists())
        self.assertNotIn('fixture-node-password', json.dumps(job))

    def test_primary_admin_csrf_and_history_annotations(self):
        root = make_env(extra={'management': {'enabled': True, 'subscription_dir': str(self.directory), 'socket': '/tmp/rules-test.sock'}})
        try:
            app, ctx = make_app(root); client = app.test_client()
            self.assertEqual(client.get('/monitor/api/manage/rules').status_code, 401)
            csrf, _ = login(client)
            self.assertEqual(client.post('/monitor/api/manage/rules-save', json={}).status_code, 403)
            with patch('panel.management.call', return_value=({'job': {'id': 'test'}}, 200)):
                self.assertEqual(client.post('/monitor/api/manage/rules-save', json={}, headers={'Origin': ORIGIN, 'X-CSRF-Token': csrf}).status_code, 200)
            self.task({'policy': policy(), 'revision': rules.revision(rules.EMPTY)})
            from panel import proto as pb
            ctx.store.ingest(batch(event(pb.EVENT_NEW, 'history', conn(cid='history', domain='api.example.com'))))
            data = client.get('/monitor/api/history').get_json()['rows'][0]
            self.assertEqual(data['client_rule_target'], {'type': 'domain', 'target': 'api.example.com'})
            self.assertEqual(data['client_rule']['action'], 'direct')
            ctx.settings.secrets['username'] = 'other-primary'
            self.assertEqual(client.get('/monitor/api/manage/rules').status_code, 403)
            self.assertFalse(client.get('/monitor/api/overview').get_json()['features']['client_rules'])
            self.assertNotIn('client_rule_target', client.get('/monitor/api/history').get_json()['rows'][0])
        finally: cleanup(root)


@unittest.skipUnless(os.environ.get('SINGBOX_TEST_BINARY'), 'set SINGBOX_TEST_BINARY for native client rule validation')
class NativeRouteTest(unittest.TestCase):
    def test_singbox_compiled_rules_check_and_direct_vs_reject_traffic(self):
        binary = str(Path(os.environ['SINGBOX_TEST_BINARY']).resolve())
        def port():
            with socket.socket() as sock: sock.bind(('127.0.0.1', 0)); return sock.getsockname()[1]
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for action in ('inherit', 'proxy', 'direct', 'reject'):
                p = policy(); p['default_action'] = action
                path = root / 'check.json'; path.write_text(rules.render('sing-box', raw_files()['sing-box'], p))
                result = subprocess.run([binary, 'check', '-c', str(path)], capture_output=True, timeout=15)
                self.assertEqual(result.returncode, 0, result.stderr.decode())
            class Handler(http.server.BaseHTTPRequestHandler):
                def do_GET(self):
                    payload = b'client-rule-direct-works'
                    self.send_response(200); self.send_header('Content-Length', str(len(payload))); self.end_headers(); self.wfile.write(payload)
                def log_message(self, *args): pass
            server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
            threading.Thread(target=server.serve_forever, daemon=True).start()
            try:
                for action in ('direct', 'reject'):
                    socks = port()
                    base = json.dumps({'log': {'level': 'error'}, 'inbounds': [{'type': 'socks', 'listen': '127.0.0.1', 'listen_port': socks}],
                        'outbounds': [{'type': 'http', 'tag': 'unavailable-proxy', 'server': '127.0.0.1', 'server_port': port()}], 'route': {'final': 'unavailable-proxy'}})
                    p = rules.validate({'rules': [{'id': 'loopback', 'type': 'ip_cidr', 'target': '127.0.0.1/32', 'action': action}]})
                    path = root / 'client.json'; path.write_text(rules.render('sing-box', base, p))
                    proc = subprocess.Popen([binary, 'run', '-c', str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    try:
                        for _ in range(30):
                            self.assertIsNone(proc.poll())
                            try:
                                with socket.create_connection(('127.0.0.1', socks), timeout=.1): break
                            except OSError: time.sleep(.1)
                        result = subprocess.run(['curl', '-q', '--noproxy', '', '--proxy', 'socks5h://127.0.0.1:' + str(socks), '--max-time', '5', '-fsS', 'http://127.0.0.1:' + str(server.server_port)], capture_output=True, timeout=10)
                        if action == 'direct': self.assertEqual(result.stdout, b'client-rule-direct-works')
                        else: self.assertNotEqual(result.returncode, 0)
                    finally: proc.terminate(); proc.wait(timeout=5)
            finally: server.shutdown(); server.server_close()

@unittest.skipUnless(os.environ.get('MIHOMO_TEST_BINARY'), 'set MIHOMO_TEST_BINARY for native Clash rule validation')
class MihomoNativeTest(unittest.TestCase):
    def test_real_mihomo_accepts_compiled_rules_and_fallbacks(self):
        binary = str(Path(os.environ['MIHOMO_TEST_BINARY']).resolve())
        with tempfile.TemporaryDirectory() as folder:
            for action in ('inherit', 'proxy', 'direct', 'reject'):
                p = policy(); p['default_action'] = action
                path = Path(folder) / 'client.yaml'; path.write_text(rules.render('clash2', raw_files()['clash2'], p))
                result = subprocess.run([binary, '-t', '-d', folder, '-f', str(path)], capture_output=True, timeout=20)
                self.assertEqual(result.returncode, 0, (result.stdout + result.stderr).decode())
