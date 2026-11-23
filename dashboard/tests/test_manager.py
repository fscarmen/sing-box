"""Isolated management tests: no root, live firewall, downloads or production files."""
import json
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

from helpers import ORIGIN, cleanup, login, make_app, make_env
from manager import MANAGED_API, Manager, OperationError, install_options, jsonc


class FakeManager(Manager):
    def __init__(self, root):
        super().__init__({'script': str(root / 'script.sh'), 'data_dir': str(root / 'manager'),
                          'work_dir': str(root / 'sing-box'), 'monitor_config': str(root / 'runtime.json'),
                          'api_address': '127.0.0.1:8306', 'api_secret': 'private-api-secret'})
        self.conf.mkdir(parents=True)
        self.binary.write_text('test binary')
        (self.conf / '11_xtls-reality_inbounds.json').write_text('// "public_key":"metadata"\n' + json.dumps({
            'inbounds': [{'type': 'vless', 'tag': 'node xtls-reality', 'listen_port': 443,
                          'users': [{'uuid': 'private-node-credential'}]}]}))
        (self.conf / MANAGED_API).write_text(self.api_file())
        self.commands = []
        self.fail_health_once = False

    def owned(self):
        pass

    def run(self, args, timeout=60, capture=False):
        self.commands.append(tuple(str(a) for a in args))
        if args[1] == 'check':
            for path in Path(args[-1]).glob('*.json'):
                if jsonc(path.read_text()).get('invalid'):
                    raise OperationError('candidate rejected')
        return 'sing-box version test\n' if capture else ''

    def health(self):
        if self.fail_health_once:
            self.fail_health_once = False
            raise OperationError('health check failed')

    def sync(self):
        self.commands.append(('sync',))
        self.export_monitor()


class ManagerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.manager = FakeManager(Path(self.tmp.name))

    def tearDown(self):
        self.tmp.cleanup()

    def execute(self, operation, payload):
        data = self.manager.request(operation, payload)
        deadline = time.time() + 5
        while self.manager.lock.locked() and time.time() < deadline:
            time.sleep(.01)
        self.assertFalse(self.manager.lock.locked())
        return json.loads((self.manager.jobs / (data['job']['id'] + '.json')).read_text())

    def test_config_hides_managed_api_and_preserves_metadata(self):
        config = self.manager.config()
        self.assertNotIn(MANAGED_API, config['files'])
        name = next(iter(config['files']))
        doc = jsonc(config['files'][name]); doc['inbounds'][0]['listen_port'] = 8444
        config['files'][name] = '// "public_key":"metadata"\n' + json.dumps(doc, indent=2)
        job = self.execute('apply', config)
        self.assertEqual(job['state'], 'succeeded', job)
        saved = (self.manager.conf / name).read_text()
        self.assertIn('"listen_port":8444', saved)
        self.assertTrue(saved.startswith('// "public_key":"metadata"'))
        self.assertTrue(self.manager.backup_list())
        self.assertNotIn('private-node-credential', json.dumps(job))
        self.assertNotIn('private-api-secret', json.dumps(job))

    def test_invalid_candidate_never_changes_live_files_or_restarts(self):
        before = self.manager.files()
        config = self.manager.config(); name = next(iter(config['files']))
        config['files'][name] = '{"invalid":true}'
        job = self.execute('apply', config)
        self.assertEqual(job['state'], 'failed')
        self.assertEqual(self.manager.files(), before)
        self.assertFalse(any('restart' in ' '.join(c) for c in self.manager.commands))

    def test_stale_revision_is_rejected_without_restart(self):
        config = self.manager.config()
        (self.manager.conf / '00_log.json').write_text('{"log":{"level":"info"}}')
        job = self.execute('apply', config)
        self.assertEqual(job['state'], 'failed')
        self.assertIn('重新加载', job['error'])
        self.assertTrue((self.manager.conf / '00_log.json').exists())
        self.assertEqual(self.manager.commands, [])

    def test_failed_post_apply_health_restores_previous_config(self):
        before = self.manager.files()
        config = self.manager.config(); name = next(iter(config['files']))
        config['files'][name] = '{"inbounds":[]}'
        self.manager.fail_health_once = True
        job = self.execute('apply', config)
        self.assertEqual(job['state'], 'failed')
        self.assertEqual(self.manager.files(), before)
        self.assertTrue(any('恢复并通过健康检查' in e['message'] for e in job['events']))

    def test_path_escape_and_managed_api_are_rejected(self):
        for name in ('../../etc/passwd', MANAGED_API, '/tmp/x.json'):
            config = self.manager.config(); config['files'][name] = '{}'
            self.assertEqual(self.execute('apply', config)['state'], 'failed')
        with self.assertRaises(OperationError):
            self.manager.restore_files('../escape')

    def test_jobs_are_serialized_and_unknown_operations_rejected(self):
        self.manager.lock.acquire()
        try:
            with self.assertRaises(OperationError): self.manager.request('restart', {})
        finally:
            self.manager.lock.release()
        with self.assertRaises(OperationError): self.manager.request('shell', {'command': 'anything'})

    def test_interrupted_job_is_not_replayed(self):
        (self.manager.jobs / '1.json').write_text(json.dumps({'id': '1', 'state': 'running'}))
        Manager(self.manager.cfg)
        job = json.loads((self.manager.jobs / '1.json').read_text())
        self.assertEqual(job['state'], 'interrupted')

    def test_restore_keeps_current_firewall_bookkeeping_for_reconciliation(self):
        state = self.manager.work / 'firewall/service_ports.list'
        state.parent.mkdir(); state.write_text('tcp 443\n')
        backup = self.manager.snapshot()
        state.write_text('tcp 14443\n')
        self.manager.restore_files(backup)
        self.assertEqual(state.read_text(), 'tcp 14443\n')

    def test_adopt_checks_api_support_before_touching_live_configuration(self):
        before = self.manager.files()
        with patch.object(self.manager, 'check', side_effect=OperationError('unsupported API')):
            job = self.execute('adopt', {})
        self.assertEqual(job['state'], 'failed')
        self.assertEqual(self.manager.files(), before)
        self.assertFalse(job.get('modified'))

    def test_restore_of_unmanaged_backup_does_not_inject_unsupported_api(self):
        (self.manager.conf / MANAGED_API).unlink()
        backup = self.manager.snapshot()
        (self.manager.conf / MANAGED_API).write_text(self.manager.api_file())
        with patch.object(self.manager, 'health', side_effect=AssertionError('API was not originally configured')):
            self.manager.restore_files(backup)
        self.assertFalse((self.manager.conf / MANAGED_API).exists())

    def test_broken_live_json_keeps_repair_and_backup_controls_available(self):
        backup = self.manager.snapshot()
        (self.manager.conf / '11_xtls-reality_inbounds.json').write_text('{broken')
        status = self.manager.status()
        self.assertTrue(status['installed'])
        self.assertTrue(status['configuration_error'])
        self.assertIn(backup, status['backups'])
        self.assertIn('{broken', self.manager.config()['files'].values())

    def test_install_arguments_are_validated_and_not_shell_code(self):
        options = install_options({}, '203.0.113.10')
        self.assertEqual(options['CHOOSE_PROTOCOLS'], 'bc')
        self.assertEqual(options['START_PORT'], 443)
        for body in ({'protocols': ['x']}, {'name': '$(id)'}, {'server': 'x;id'}, {'start_port': True},
                     {'protocols': ['h']}, {'start_port': 65535}):
            with self.assertRaises(OperationError): install_options(body, '203.0.113.10')

    def test_reserved_panel_port_rejected_before_applying(self):
        self.manager.cfg['panel_port'] = 8443
        self.manager.cfg['subscription_dir'] = str(Path(self.tmp.name) / 'published')
        for port in (8443, 8308):
            config = self.manager.config(); name = next(iter(config['files']))
            config['files'][name] = json.dumps({'inbounds': [{'type': 'vless', 'listen_port': port}]})
            before = self.manager.files()
            self.assertEqual(self.execute('apply', config)['state'], 'failed')
            self.assertEqual(self.manager.files(), before)


class ManagementApiTest(unittest.TestCase):
    def setUp(self):
        self.root = make_env(extra={'management': {'enabled': True, 'socket': '/tmp/test.sock'}})
        self.app, self.ctx = make_app(self.root)
        self.client = self.app.test_client()

    def tearDown(self):
        cleanup(self.root)

    def test_auth_csrf_and_method_enforced(self):
        self.assertEqual(self.client.get('/monitor/api/manage/config').status_code, 401)
        csrf, _ = login(self.client)
        with patch('panel.management.call', return_value=({'job': {'id': '1'}}, 200)) as call:
            self.assertEqual(self.client.get('/monitor/api/manage/restart').status_code, 405)
            self.assertEqual(self.client.post('/monitor/api/manage/restart', json={}).status_code, 403)
            self.assertEqual(self.client.post('/monitor/api/manage/restart', json={}, headers={'X-CSRF-Token': csrf, 'Origin': ORIGIN}).status_code, 200)
            call.assert_called_once()
        self.assertEqual(self.ctx.store.audit(action='manage:restart')['total'], 1)

    def test_extra_monitoring_account_cannot_read_node_secrets(self):
        self.ctx.settings.secrets['username'] = 'other-admin'
        with patch.object(self.ctx.auth, 'lookup', return_value={'user': 'monitor', 'csrf': 'x'}):
            self.assertEqual(self.client.get('/monitor/api/manage/config').status_code, 403)

    def test_direct_listener_ignores_forwarded_ip_headers(self):
        self.ctx.settings.values['site']['trust_proxy'] = False
        self.client.post('/monitor/login', data={'username': 'test', 'password': 'bad'},
                         headers={'Origin': ORIGIN, 'X-Dashboard-Client-IP': '8.8.8.8'})
        ip = self.ctx.store.reader().execute('SELECT ip FROM failures').fetchone()[0]
        self.assertEqual(ip, '127.0.0.1')

    def test_manager_unavailable_returns_503(self):
        login(self.client)
        self.assertEqual(self.client.get('/monitor/api/manage/status').status_code, 503)
