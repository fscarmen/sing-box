"""Managed Xray transactions and real Reality client/server interoperability."""
import base64
import copy
import hashlib
import http.server
import io
import json
import os
from pathlib import Path
import shutil
import socket
import ssl
import subprocess
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
import zipfile

from flask import Flask
from helpers import ORIGIN, cleanup, login, make_app, make_env
from manager import OperationError, atomic
from panel import subscriptions
from xray_manager import XrayManager, stats_config
import xray_download


def document(port=9443):
    return {'log': {'loglevel': 'warning'}, 'inbounds': [{'tag': 'xray', 'listen': '0.0.0.0', 'port': port,
        'protocol': 'vless', 'settings': {'decryption': 'none', 'clients': [{'id': '00000000-0000-4000-8000-000000000003',
        'email': 'user@xray', 'level': 0, 'flow': 'xtls-rprx-vision'}]}, 'streamSettings': {'network': 'raw',
        'security': 'reality', 'realitySettings': {'show': False, 'target': 'www.microsoft.com:443',
        'serverNames': ['www.microsoft.com'], 'privateKey': 'A' * 43, 'shortIds': ['1234abcd']}}}],
        'outbounds': [{'tag': 'direct', 'protocol': 'freedom'}], **stats_config()}


class FakeXray(XrayManager):
    def __init__(self, root):
        settings = root / 'settings.json'
        settings.write_text(json.dumps({'xray': {'instances': [{'id': 'external', 'service': 'other.service'}]}, 'singbox': {'enabled': True}}))
        super().__init__({'script': str(root / 'sing-box.sh'), 'data_dir': str(root / 'manager'),
            'work_dir': str(root / 'sing-box'), 'xray_work_dir': str(root / 'xray'), 'xray_binary': str(root / 'bin/xray'),
            'xray_unit': str(root / 'xray.service'), 'xray_monitor_config': str(root / 'runtime.json'),
            'settings_path': str(settings), 'subscription_dir': str(root / 'public'), 'public_url': 'https://panel.example.test',
            'server': '203.0.113.15', 'panel_port': 8443})
        self.work.mkdir(parents=True); self.binary.parent.mkdir(); self.binary.write_text('old-binary')
        self.config_path.write_text(json.dumps(document()))
        self.marker.write_text(json.dumps({'server': '203.0.113.15'}))
        self.commands = []
        self.fail_once = False

    def owned(self): pass
    def run(self, args, timeout=60, capture=False, job=None, env=None):
        self.commands.append(tuple(str(a) for a in args))
        if args[0] == self.binary and args[1] == 'version': return 'Xray test\n'
        if 'x25519' in args: return 'PrivateKey: ' + 'A' * 43 + '\nPassword (PublicKey): ' + 'B' * 43 + '\n'
        return ''
    def check(self, path, binary=None):
        if json.loads(Path(path).read_text()).get('invalid'): raise OperationError('invalid candidate')
    def check_ports(self, doc, old=None): pass
    def save_config(self, doc): atomic(self.config_path, json.dumps(doc))
    def health(self):
        if self.fail_once:
            self.fail_once = False
            raise OperationError('health failed')
    def firewall(self, remove=False): self.commands.append(('firewall', str(remove)))


class XrayManagementTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.manager = FakeXray(self.root)

    def tearDown(self): self.temp.cleanup()

    def task(self, op, payload=None):
        result = self.manager.request(op, payload or {})
        deadline = time.monotonic() + 5
        while self.manager.lock.locked() and time.monotonic() < deadline: time.sleep(.01)
        self.assertFalse(self.manager.lock.locked())
        return json.loads((self.manager.jobs / (result['job']['id'] + '.json')).read_text())

    def test_apply_publishes_clients_and_preserves_independent_tokens(self):
        m = self.manager
        subscriptions_root = m.cfg['subscription_dir']
        source = self.root / 'singbox-source/subscribe'; source.mkdir(parents=True)
        (source / 'clash2').write_text('proxies: []')
        single = subscriptions.publish(source.parent, subscriptions_root, m.cfg['public_url'], 's' * 32)
        config = m.config(); value = json.loads(config['files']['config.json'])
        value['inbounds'][0]['port'] = 10443
        value['api'] = {'listen': '0.0.0.0:9999'}
        config['files']['config.json'] = json.dumps(value)
        result = self.task('apply', config)
        self.assertEqual(result['state'], 'succeeded', result)
        self.assertEqual(result['engine'], 'xray')
        self.assertEqual(m.document()['api']['listen'], '127.0.0.1:8311')
        exported = m.request('subscriptions', {})
        self.assertIn('10443', exported['files']['clash2'])
        uri = base64.b64decode(exported['files']['shadowrocket']).decode()
        self.assertIn('security=reality', uri); self.assertIn('flow=xtls-rprx-vision', uri)
        self.assertNotIn('A' * 43, json.dumps(exported))
        self.assertNotIn('A' * 43, json.dumps(result))
        app = Flask(__name__); subscriptions.register(app, subscriptions_root)
        client = app.test_client()
        self.assertEqual(client.get('/sub/' + 's' * 32 + '/auto').text, 'proxies: []')
        url = exported['links']['auto'].split('https://panel.example.test', 1)[1]
        self.assertEqual(client.get(url).text, exported['files']['clash2'])
        self.assertEqual(client.get(url, headers={'User-Agent': 'Shadowrocket'}).text, exported['files']['shadowrocket'])
        self.assertEqual(client.get(url.replace('/auto', '/../../config.json')).status_code, 404)
        self.assertEqual(client.get('/sub/invalid/auto').status_code, 404)
        self.task('subscription', {'origin': 'https://sub.example.test'})
        new_links = m.request('subscriptions', {})['links']
        self.assertEqual(new_links['auto'].split('/sub/')[1], exported['links']['auto'].split('/sub/')[1])
        self.assertEqual(subscriptions.read_manifest(subscriptions_root), single)

    def test_invalid_and_stale_candidates_do_not_touch_live_config(self):
        before = self.manager.files()
        for mutate in (lambda d: d['inbounds'][0].update(port=8311),
                       lambda d: d['inbounds'][0].update(protocol='socks'),
                       lambda d: d['inbounds'][0]['settings']['clients'][0].update(email=''),
                       lambda d: d['inbounds'].append(copy.deepcopy(d['inbounds'][0])),
                       lambda d: d.update(invalid=True)):
            cfg = self.manager.config(); doc = json.loads(cfg['files']['config.json']); mutate(doc)
            cfg['files']['config.json'] = json.dumps(doc)
            self.assertEqual(self.task('apply', cfg)['state'], 'failed')
            self.assertEqual(self.manager.files(), before)
        cfg = self.manager.config(); cfg['revision'] = 'outdated'
        self.assertEqual(self.task('apply', cfg)['state'], 'failed')
        self.assertFalse(any('restart' in c for c in self.manager.commands))

    def test_failed_health_restores_configuration_and_server(self):
        before = self.manager.files()
        cfg = self.manager.config(); cfg['server'] = 'example.com'
        value = json.loads(cfg['files']['config.json']); value['inbounds'][0]['port'] = 10443
        cfg['files']['config.json'] = json.dumps(value)
        self.manager.fail_once = True
        result = self.task('apply', cfg)
        self.assertEqual(result['state'], 'failed')
        self.assertEqual(self.manager.files(), before)
        self.assertEqual(json.loads(self.manager.marker.read_text())['server'], '203.0.113.15')
        self.assertTrue(any('已恢复' in e['message'] for e in result['events']))

    def test_restore_and_upgrade_keep_subscription_token(self):
        self.task('export')
        links = self.manager.request('subscriptions', {})['links']
        backup = self.task('backup')['backup']
        cfg = self.manager.config(); value = json.loads(cfg['files']['config.json']); value['inbounds'][0]['port'] = 10443
        cfg['files']['config.json'] = json.dumps(value)
        self.assertEqual(self.task('apply', cfg)['state'], 'succeeded')
        self.assertEqual(self.task('restore', {'backup': backup})['state'], 'succeeded')
        self.assertEqual(self.manager.document()['inbounds'][0]['port'], 9443)
        def fetch(version, archive):
            binary = archive.parent / 'xray'; binary.write_text('new-binary'); binary.chmod(0o755); return binary
        with patch.object(self.manager, 'download', side_effect=fetch):
            self.assertEqual(self.task('upgrade', {'version': '26.10.21'})['state'], 'succeeded')
            self.manager.fail_once = True
            self.assertEqual(self.task('upgrade', {'version': '26.10.21'})['state'], 'failed')
        self.assertEqual(self.manager.binary.read_text(), 'new-binary')
        self.assertEqual(self.manager.request('subscriptions', {})['links'], links)

    def test_existing_install_not_overwritten_and_external_adopt_rejected(self):
        before = self.manager.files()
        self.assertEqual(self.task('install')['state'], 'failed')
        self.assertEqual(self.manager.files(), before)
        with self.assertRaises(OperationError): self.manager.request('adopt', {})
        with self.assertRaises(OperationError): self.manager.restore_files('../sing-box')

    def test_monitor_registration_preserves_other_instances_and_singbox(self):
        self.manager.register_monitor(); self.manager.register_monitor()
        settings = json.loads(Path(self.manager.cfg['settings_path']).read_text())
        self.assertEqual([i['id'] for i in settings['xray']['instances']], ['external', 'managed'])
        self.assertTrue(settings['singbox']['enabled'])
        self.assertEqual(settings['xray']['instances'][1]['api_address'], '127.0.0.1:8311')

    def test_private_manager_umask_still_publishes_group_readable_xray(self):
        previous = os.umask(0o077)
        try:
            self.manager.publish_subscriptions()
        finally:
            os.umask(previous)
        directory = self.manager.subscription_dir()
        self.assertEqual(directory.stat().st_mode & 0o777, 0o750)
        self.assertEqual((directory / 'current').stat().st_mode & 0o777, 0o750)
        self.assertEqual((directory / 'current/clash2').stat().st_mode & 0o777, 0o640)

    def test_panel_can_start_without_a_core_only_when_management_enabled(self):
        root = make_env(extra={'management': {'enabled': True, 'socket': '/tmp/test.sock'}, 'singbox': {'enabled': False}, 'xray': {'instances': []}})
        try:
            app, ctx = make_app(root)
            self.assertFalse(ctx.singbox_enabled)
            self.assertFalse(ctx.xray.instances)
            client = app.test_client(); login(client)
            self.assertEqual(client.get('/monitor/api/overview').status_code, 200)
        finally: cleanup(root)

    def test_xray_management_uses_same_primary_admin_and_csrf_checks(self):
        root = make_env(extra={'management': {'enabled': True, 'socket': '/tmp/test.sock'}})
        try:
            app, _ = make_app(root); client = app.test_client()
            self.assertEqual(client.get('/monitor/api/manage/config?engine=xray').status_code, 401)
            csrf, _ = login(client)
            with patch('panel.management.call', return_value=({'job': {'id': '1'}}, 200)) as call:
                self.assertEqual(client.post('/monitor/api/manage/install', json={'engine': 'xray'}).status_code, 403)
                self.assertEqual(client.get('/monitor/api/manage/status?engine=xray').status_code, 200)
                self.assertEqual(call.call_args.args[2]['engine'], 'xray')
                self.assertEqual(client.post('/monitor/api/manage/install', json={'engine': 'xray'}, headers={'Origin': ORIGIN, 'X-CSRF-Token': csrf}).status_code, 200)
        finally: cleanup(root)


class DownloadTest(unittest.TestCase):
    def test_checksum_and_malicious_archive_rejected_before_install(self):
        for bad_hash, bad_path in ((False, False), (True, False), (False, True)):
            data = io.BytesIO()
            with zipfile.ZipFile(data, 'w') as archive:
                archive.writestr('xray', b'test-binary')
                if bad_path: archive.writestr('../escape', b'bad')
            content = data.getvalue()
            digest = '0' * 64 if bad_hash else hashlib.sha256(content).hexdigest()
            url = 'https://github.com/XTLS/Xray-core/releases/download/v26.10.21/Xray-linux-64.zip'
            metadata = json.dumps({'assets': [{'name': 'Xray-linux-64.zip', 'digest': 'sha256:' + digest, 'browser_download_url': url}]}).encode()
            with tempfile.TemporaryDirectory() as tmp, patch('urllib.request.urlopen', side_effect=[io.BytesIO(metadata), io.BytesIO(content)]):
                target = Path(tmp) / 'archive.zip'
                if bad_hash or bad_path:
                    with self.assertRaises(ValueError): xray_download.download('26.10.21', 'amd64', target)
                    self.assertFalse(target.exists())
                else:
                    binary = xray_download.download('26.10.21', 'amd64', target)
                    self.assertEqual(binary.read_bytes(), b'test-binary')
                    self.assertEqual(Path(str(target) + '.dgst').read_text().strip(), 'SHA256=' + digest)

    def test_unpinned_version_never_downloaded(self):
        with patch('urllib.request.urlopen') as open_url:
            for version in ('latest', 'v26.10.21', '../x', '$(id)'):
                with self.assertRaises(ValueError): xray_download.download(version, 'amd64', '/tmp/unused')
            open_url.assert_not_called()


@unittest.skipUnless(os.environ.get('XRAY_TEST_BINARY'), 'set XRAY_TEST_BINARY for native Reality deployment tests')
class RealityNativeTest(unittest.TestCase):
    def test_generated_server_exports_and_real_reality_handshake(self):
        binary = str(Path(os.environ['XRAY_TEST_BINARY']).resolve())
        def port():
            with socket.socket() as s: s.bind(('127.0.0.1', 0)); return s.getsockname()[1]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); m = FakeXray(root)
            # Use production key generation and validation with the real core.
            with patch.object(m, 'run', side_effect=lambda args, **kw: subprocess.check_output([str(a) for a in args], text=True)):
                private, public = XrayManager.keypair(m, binary)
            doc = document(port()); doc['inbounds'][0]['streamSettings']['realitySettings']['privateKey'] = private
            doc = m.validate(doc)
            candidate = root / 'generated.json'; candidate.write_text(json.dumps(doc))
            checked = subprocess.run([binary, 'run', '-test', '-config', str(candidate)], capture_output=True, timeout=15)
            self.assertEqual(checked.returncode, 0, checked.stderr.decode())
            # Local TLS target avoids relying on a third party for the Reality handshake.
            cert, key = root / 'cert.crt', root / 'cert.key'
            subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1', '-subj', '/CN=www.microsoft.com', '-keyout', str(key), '-out', str(cert)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            class Handler(http.server.BaseHTTPRequestHandler):
                def do_GET(self):
                    body = b'local-reality-deployment-' * 1000
                    self.send_response(200); self.send_header('Content-Length', str(len(body))); self.end_headers(); self.wfile.write(body)
                def log_message(self, *args): pass
            tls = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); context.minimum_version = ssl.TLSVersion.TLSv1_3
            context.load_cert_chain(cert, key); context.set_alpn_protocols(['h2', 'http/1.1'])
            tls.socket = context.wrap_socket(tls.socket, server_side=True)
            target = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
            for server in (tls, target): threading.Thread(target=server.serve_forever, daemon=True).start()
            api, socks = port(), port()
            doc['log'] = {'loglevel': 'debug'}
            doc['api']['listen'] = '127.0.0.1:' + str(api)
            inbound = doc['inbounds'][0]; inbound['listen'] = '127.0.0.1'
            inbound['streamSettings']['realitySettings']['show'] = False
            inbound['streamSettings']['realitySettings']['target'] = '127.0.0.1:' + str(tls.server_port)
            doc['outbounds'][0]['settings'] = {'finalRules': [{'action': 'allow', 'ip': ['127.0.0.1/32']}]}
            candidate.write_text(json.dumps(doc)); m.config_path.write_text(json.dumps(doc))
            # Publish actual public keys and validate sing-box can consume its export.
            def real_keypair(core, private=None):
                with patch.object(m, 'run', side_effect=lambda args, **kw: subprocess.check_output([str(a) for a in args], text=True)):
                    return XrayManager.keypair(m, binary, private)
            m.keypair = real_keypair
            m.publish_subscriptions(); files = m.request('subscriptions', {})['files']
            self.assertIn(public, files['clash2']); self.assertNotIn(private, json.dumps(files))
            if os.environ.get('SINGBOX_TEST_BINARY'):
                client_path = root / 'singbox-client.json'; client_path.write_text(files['sing-box'])
                check = subprocess.run([os.environ['SINGBOX_TEST_BINARY'], 'check', '-c', str(client_path)], capture_output=True, timeout=15)
                self.assertEqual(check.returncode, 0, check.stderr.decode())
            client_config = {'log': {'loglevel': 'warning'}, 'inbounds': [{'tag': 'local', 'listen': '127.0.0.1', 'port': socks, 'protocol': 'socks', 'settings': {'auth': 'noauth'}}],
                'outbounds': [{'tag': 'proxy', 'protocol': 'vless', 'settings': {'vnext': [{'address': '127.0.0.1', 'port': inbound['port'],
                    'users': [{'id': inbound['settings']['clients'][0]['id'], 'encryption': 'none', 'flow': 'xtls-rprx-vision'}]}]},
                    'streamSettings': {'network': 'raw', 'security': 'reality', 'realitySettings': {'serverName': 'www.microsoft.com', 'fingerprint': 'chrome', 'password': public, 'shortId': '1234abcd'}}}]}
            client_config['log'] = {'loglevel': 'debug'}
            client_path = root / 'client.json'; client_path.write_text(json.dumps(client_config))
            procs = []
            logs = [open(root / name, 'w+') for name in ('server.log', 'client.log')]
            try:
                procs.append(subprocess.Popen([binary, 'run', '-config', str(candidate)], stdout=logs[0], stderr=logs[0]))
                procs.append(subprocess.Popen([binary, 'run', '-config', str(client_path)], stdout=logs[1], stderr=logs[1]))
                for _ in range(60):
                    self.assertTrue(all(p.poll() is None for p in procs))
                    try:
                        with socket.create_connection(('127.0.0.1', socks), timeout=.1): break
                    except OSError: time.sleep(.1)
                result = subprocess.run(['curl', '-q', '--proxy', 'socks5h://127.0.0.1:' + str(socks), '--noproxy', '', '--max-time', '10', '-fsS', 'http://127.0.0.1:' + str(target.server_port)], capture_output=True, timeout=15)
                for log in logs: log.flush(); log.seek(0)
                self.assertEqual(result.returncode, 0, result.stderr.decode() + ''.join(log.read() for log in logs))
                self.assertGreater(len(result.stdout), 20000)
                from panel.xray import Client
                stats = Client({'id': 'reality', 'service': 'test.service', 'api_address': '127.0.0.1:' + str(api)})
                try:
                    counters = stats.counters()
                    self.assertGreater(counters['user>>>user@xray>>>traffic>>>downlink'], 20000)
                finally: stats.channel.close()
            finally:
                for proc in procs:
                    proc.terminate()
                    try: proc.wait(timeout=5)
                    except subprocess.TimeoutExpired: proc.kill(); proc.wait()
                for server in (tls, target): server.shutdown(); server.server_close()
                for log in logs: log.close()
