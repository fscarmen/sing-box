import concurrent.futures
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

import helpers
import grpc
from panel import xray, xray_proto as pb


def config():
    return {'inbounds': [{'tag': 'in-a', 'protocol': 'vmess', 'listen': '127.0.0.1', 'port': 12001,
                          'settings': {'clients': [{'id': '00000000-0000-4000-8000-000000000001', 'email': 'test@example.invalid'}]},
                          'streamSettings': {'network': 'ws'}}],
            'outbounds': [{'tag': 'out-a', 'protocol': 'socks', 'settings': {'servers': [{'address': 'proxy.example.invalid', 'port': 1080, 'users': [{'user': 'fixture-user', 'pass': 'fixture-secret'}]}]}}],
            'routing': {'rules': [{'type': 'field', 'inboundTag': ['in-a'], 'outboundTag': 'out-a'}]}}


class XrayTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='xray-unit-')
        self.path = Path(self.tmp.name) / 'xray.json'
        self.path.write_text(json.dumps(config()))
        self.instance = {'id': 'main', 'label': 'test', 'service': 'test.service', 'config_path': str(self.path), 'api_address': '127.0.0.1:8311', 'external_tls': True, 'external_port': 443}
        self.root = helpers.make_env(extra={'xray': {'instances': [self.instance]}})
        self.settings = helpers.settings_mod.load(self.root / 'settings.json', self.root / 'config.json', environ={})

    def tearDown(self):
        helpers.cleanup(self.root)
        self.tmp.cleanup()

    def test_loopback_and_instance_validation(self):
        for patch in [{'api_address': '0.0.0.0:8311'}, {'api_address': 'api.example.com:8311'}, {'service': 'x;true'}, {'id': '../unsafe'}]:
            with self.subTest(patch=patch), self.assertRaises(ValueError):
                xray.validate_instance(self.instance | patch)

    def test_node_only_activity_is_per_inbound_and_becomes_unknown_when_stale(self):
        from unittest.mock import patch
        c = config()
        other = json.loads(json.dumps(c['inbounds'][0])); other.update(tag='in-b', port=12002)
        c['inbounds'].append(other)  # Both nodes deliberately share one user.
        self.path.write_text(json.dumps(c))
        self.settings.values['xray']['node_only'] = True
        traffic = {'a': 0}
        class Fake:
            def __init__(self, instance): pass
            def counters(self):
                return {'inbound>>>in-a>>>traffic>>>uplink': traffic['a'], 'inbound>>>in-a>>>traffic>>>downlink': 0,
                        'inbound>>>in-b>>>traffic>>>uplink': 0, 'inbound>>>in-b>>>traffic>>>downlink': 0}
            def online_users(self): raise AssertionError('Node-only mode must not request users')
            def online(self, email): raise AssertionError('Node-only mode must not request user addresses')
            def runtime(self): return {}
        m = xray.Monitor(self.settings, lambda t: '2026-01-01', threading.Event(), Fake, lambda i: 'g')
        try:
            with patch('panel.xray.time.time', return_value=100):
                m.poll(); self.assertIsNone(m.snapshot()['totals']['online_nodes'])
            traffic['a'] = 4096
            for moment in range(102, 163, 2):
                with patch('panel.xray.time.time', return_value=moment): m.poll()
            reopened = xray.Ledger(self.settings)
            persisted = reopened.ingest('main', 'g', {'in-a': (4096, 0)}, 162, '2026-01-01')['in-a']
            self.assertEqual(persisted['last_activity'], 102, 'Panel restart must preserve recent node activity')
            reopened.db.close()
            with patch('panel.xray.time.time', return_value=162):
                snap = m.snapshot()
                self.assertEqual(snap['totals']['online_nodes'], 1)
                self.assertEqual([n['online_activity'] for n in snap['nodes']], [True, False])
                self.assertEqual(snap['users'], []); self.assertEqual(snap['outbound_stats'], [])
                self.assertTrue(all(n['online_sources'] is None for n in snap['nodes']))
            with patch('panel.xray.time.time', return_value=164):
                m.poll(); self.assertEqual(m.snapshot()['totals']['online_nodes'], 0)
            with patch('panel.xray.time.time', return_value=180):
                self.assertIsNone(m.snapshot()['totals']['online_nodes'])
                self.assertEqual(m.snapshot()['totals']['online_nodes_unknown'], 2)
            self.assertEqual(m.ledger.db.execute('SELECT COUNT(*) FROM user_counters').fetchone()[0], 0)
        finally:
            m.ledger.db.close()

    def test_topology_private_credentials_and_exact_route(self):
        nodes, credentials = xray.topology(self.instance)
        self.assertEqual(nodes[0]['outbound'], 'out-a')
        self.assertEqual(nodes[0]['port'], 443)
        self.assertTrue(nodes[0]['tls'])
        self.assertEqual(credentials['out-a']['password'], 'fixture-secret')
        public = {k: v for k, v in nodes[0].items() if not k.startswith('_')}
        self.assertNotIn('fixture-secret', json.dumps(public))
        self.assertNotIn('test@example.invalid', json.dumps(public))
        c = config()
        c['routing']['rules'].insert(0, {'type': 'field', 'inboundTag': ['in-a'], 'domain': ['example.com'], 'outboundTag': 'another'})
        self.path.write_text(json.dumps(c))
        self.assertFalse(xray.topology(self.instance)[0][0]['probe'])

    def test_ledger_replay_restart_rollover_and_gap(self):
        ledger = xray.Ledger(self.settings)
        def sample(gen, up, down, now, day='2026-01-01'):
            return ledger.ingest('main', gen, {'in-a': (up, down)}, now, day)['in-a']
        self.assertEqual(sample('g1', 100, 200, 100)['upload'], 0)
        self.assertEqual(sample('g1', 160, 300, 102)['up_rate'], 30)
        self.assertEqual(sample('g1', 160, 300, 104)['upload'], 60)
        reopened = xray.Ledger(self.settings)
        self.assertEqual(reopened.ingest('main', 'g1', {'in-a': (170, 330)}, 106, '2026-01-01')['in-a']['upload'], 70)
        r = sample('g2', 5, 8, 108, '2026-01-02')
        self.assertEqual((r['upload'], r['today_upload']), (75, 5))
        self.assertIsNone(r['up_rate'])
        self.assertTrue(r['counter_reset'])
        self.assertIsNone(sample('g2', 100, 200, 140)['up_rate'])
        self.assertEqual(sum(r['upload'] for r in ledger.series(140)), 170)
        one_reset = sample('g2', 110, 10, 142)
        self.assertEqual(one_reset['upload'], 180, 'resetting one direction must not recount the other')
        self.assertEqual((self.settings.data_dir / 'xray-traffic.sqlite3').stat().st_mode & 0o777, 0o600)
        reopened.db.close(); ledger.db.close()

    def test_failure_missing_statistics_never_reports_zero_success(self):
        class Fake:
            def __init__(self, instance): pass
            def counters(self): return {}
        m = xray.Monitor(self.settings, lambda t: '2026-01-01', threading.Event(), Fake, lambda i: 'g')
        m.poll()
        state = m.snapshot()
        self.assertFalse(state['instances'][0]['connected'])
        self.assertEqual(state['nodes'], [])
        m.ledger.db.close()

    def test_poll_hides_stale_rates_and_credentials(self):
        class Fake:
            def __init__(self, instance): self.fail = False
            def counters(self):
                if self.fail: raise RuntimeError('secret must not be returned')
                return {'inbound>>>in-a>>>traffic>>>uplink': 100, 'inbound>>>in-a>>>traffic>>>downlink': 200}
            def online(self, email): return None
            def online_users(self): return None
            def runtime(self): return {}
        m = xray.Monitor(self.settings, lambda t: '2026-01-01', threading.Event(), Fake, lambda i: 'g')
        m.poll(); first = m.snapshot()
        self.assertTrue(first['instances'][0]['connected'])
        self.assertIsNone(first['nodes'][0]['online_sources'])
        m.clients['main'].fail = True
        m.poll(); last = m.snapshot()
        self.assertIsNone(last['nodes'][0]['up_rate'])
        self.assertFalse(last['nodes'][0]['fresh'])
        for secret in ['fixture-secret', '00000000-0000-4000-8000-000000000001', 'secret must not be returned']:
            self.assertNotIn(secret, json.dumps(last))
        # The email is the operator's user label: listed per user, never attached to node rows.
        self.assertNotIn('test@example.invalid', json.dumps(last['nodes']))
        self.assertEqual(last['users'][0]['email'], 'test@example.invalid')
        m.ledger.db.close()

    def test_user_and_outbound_ledgers_never_feed_instance_totals(self):
        ledger = xray.Ledger(self.settings)
        ledger.ingest('main', 'g1', {'in-a': (0, 0)}, 100, '2026-01-01')
        ledger.ingest('main', 'g1', {'u@x': (0, 0)}, 100, '2026-01-01', 'user')
        ledger.ingest('main', 'g1', {'direct': (0, 0)}, 100, '2026-01-01', 'outbound')
        self.assertEqual(ledger.ingest('main', 'g1', {'in-a': (10, 20)}, 102, '2026-01-01')['in-a']['upload'], 10)
        user = ledger.ingest('main', 'g1', {'u@x': (7, 70)}, 102, '2026-01-01', 'user')['u@x']
        self.assertEqual((user['upload'], user['download'], user['down_rate']), (7, 70, 35))
        restarted = ledger.ingest('main', 'g2', {'direct': (5, 9)}, 104, '2026-01-01', 'outbound')['direct']
        self.assertEqual((restarted['upload'], restarted['download']), (5, 9))
        self.assertEqual(sum(r['upload'] for r in ledger.series(104)), 10, 'only inbound bytes enter the minute series')
        detail = ledger.details(0, '2026-01-01')
        self.assertEqual(detail['user_daily'][0]['email'], 'u@x')
        self.assertEqual(detail['outbound_daily'][0]['download'], 9)
        self.assertEqual(ledger.user_day_totals('2026-01-01'), [{'instance': 'main', 'email': 'u@x', 'total': 77}])
        ledger.db.close()

    def test_user_counter_created_after_first_sample_counts_in_full(self):
        state = {'user': None}
        class Fake:
            users_api = True
            def __init__(self, instance): pass
            def counters(self):
                raw = {'inbound>>>in-a>>>traffic>>>uplink': 0, 'inbound>>>in-a>>>traffic>>>downlink': 0}
                if state['user'] is not None:
                    raw |= {'user>>>test@example.invalid>>>traffic>>>uplink': state['user'][0], 'user>>>test@example.invalid>>>traffic>>>downlink': state['user'][1]}
                return raw
            def online_users(self): return {}
            def runtime(self): return None
        def poll_user():
            m.poll()
            return m.snapshot(detail=False)['users'][0]
        overlay = self.path.with_name('policy.json')
        overlay.write_text(json.dumps({'policy': {'levels': {'0': {'statsUserUplink': True, 'statsUserDownlink': True}}}}))
        self.instance['stats_overlay'] = str(overlay)
        m = xray.Monitor(self.settings, lambda t: '2026-01-01', threading.Event(), Fake, lambda i: 'g')
        m.instances[0]['stats_overlay'] = str(overlay)
        self.assertEqual(poll_user()['upload'], 0, 'no counter yet with stats on: the user has moved nothing')
        state['user'] = (300, 4000)
        user = poll_user()
        self.assertEqual((user['upload'], user['download']), (300, 4000), 'the first traffic is not swallowed as a baseline')
        overlay.write_text(json.dumps({'policy': {'levels': {'0': {}}}}))
        state['user'] = None
        m.ledger.db.execute('DELETE FROM user_counters')
        m.user_rows.clear()
        self.assertIsNone(poll_user()['upload'], 'user stats off in policy is unknown, not zero')
        m.ledger.db.close()

    def test_poll_reads_users_outbounds_and_online_semantics(self):
        state = {'up': 100, 'bulk': {'test@example.invalid': {'198.51.100.7': 5, 'not-an-ip': 1}}}
        class Fake:
            def __init__(self, instance): self.users_api = None
            def counters(self):
                return {'inbound>>>in-a>>>traffic>>>uplink': state['up'], 'inbound>>>in-a>>>traffic>>>downlink': 200,
                        'user>>>test@example.invalid>>>traffic>>>uplink': state['up'] // 2, 'user>>>test@example.invalid>>>traffic>>>downlink': 90,
                        'outbound>>>out-a>>>traffic>>>uplink': 40, 'outbound>>>out-a>>>traffic>>>downlink': 50}
            def online(self, email): return {'203.0.113.9': 3}
            def online_users(self):
                self.users_api = state['bulk'] is not None
                return state['bulk']
            def runtime(self): return {'uptime': 9, 'goroutines': 3, 'memory': 1, 'heap': 1, 'gc': 0}
        m = xray.Monitor(self.settings, lambda t: '2026-01-01', threading.Event(), Fake, lambda i: 'g')
        m.poll(); state['up'] = 120; m.poll()
        snap = m.snapshot()
        user = snap['users'][0]
        self.assertEqual((user['email'], user['nodes'], user['online_ips']), ('test@example.invalid', ['main:in-a'], ['198.51.100.7']))
        self.assertEqual(user['upload'], 10)
        self.assertEqual(snap['nodes'][0]['online_sources'], ['198.51.100.7'])
        self.assertEqual(snap['outbound_stats'][0]['tag'], 'out-a')
        self.assertEqual(snap['totals']['upload'], 20, 'user and outbound bytes must not be added to node totals')
        self.assertEqual(snap['runtimes']['main']['uptime'], 9)
        self.assertTrue(snap['instances'][0]['users_api'])
        state['bulk'] = {}
        m.poll()
        self.assertIsNone(m.snapshot()['users'][0]['online_ips'], 'online tracking off in policy is unknown, not zero')
        self.path.with_name('policy.json').write_text(json.dumps({'policy': {'levels': {'0': {'statsUserOnline': True}}}}))
        m.instances[0]['stats_overlay'] = str(self.path.with_name('policy.json'))
        m.poll()
        self.assertEqual(m.snapshot()['users'][0]['online_ips'], [], 'tracked level absent from GetUsersStats has nobody online')
        state['bulk'] = None
        m.poll()
        self.assertEqual(m.snapshot()['users'][0]['online_ips'], ['203.0.113.9'], 'older cores fall back to per-user calls')
        m.ledger.db.close()

    def test_public_endpoints_skip_loopback_and_map_udp(self):
        c = config()
        c['inbounds'] += [{'tag': 'reality', 'protocol': 'vless', 'port': 443, 'settings': {'clients': []}, 'streamSettings': {'network': 'raw', 'security': 'reality'}},
                          {'tag': 'kcp', 'protocol': 'vmess', 'listen': '0.0.0.0', 'port': 8443, 'streamSettings': {'network': 'kcp'}},
                          {'tag': 'ss', 'protocol': 'shadowsocks', 'listen': '::', 'port': 8388, 'settings': {'network': 'tcp,udp'}},
                          {'tag': 'unix', 'protocol': 'vless', 'listen': '/run/x.sock', 'port': 0},
                          {'tag': 'api', 'protocol': 'dokodemo-door', 'port': 9000}]
        self.path.write_text(json.dumps(c))
        self.assertEqual(xray.public_endpoints(self.instance), [('tcp', 443), ('tcp', 8388), ('udp', 8388), ('udp', 8443)])

    def test_routes_require_login_and_csrf(self):
        app, ctx = helpers.make_app(self.root)
        client = app.test_client()
        self.assertEqual(client.get('/monitor/api/xray').status_code, 401)
        csrf, _ = helpers.login(client)
        self.assertEqual(client.get('/monitor/api/xray').status_code, 200)
        self.assertEqual(client.post('/monitor/api/xray/probes/run', json={}).status_code, 403)


class WireTest(unittest.TestCase):
    def test_real_grpc_wire_and_read_only_requests(self):
        seen = []
        def query(req, context):
            seen.append((req.pattern, req.reset))
            response = pb.QueryStatsResponse()
            response.stat.add(name='inbound>>>local>>>traffic>>>uplink', value=123)
            return response
        def online(req, context):
            seen.append((req.name, req.reset))
            response = pb.GetStatsOnlineIpListResponse(name=req.name)
            response.ips['198.51.100.7'] = 123
            return response
        missing = [False]
        def users(req, context):
            seen.append(('users', req.reset))
            if missing[0]:
                context.abort(grpc.StatusCode.UNIMPLEMENTED, 'unknown method')
            response = pb.GetUsersStatsResponse()
            response.users.add(email='test@example.invalid').ips.add(ip='198.51.100.8', last_seen=456)
            return response
        def sysstats(req, context):
            return pb.SysStatsResponse(Uptime=77, NumGoroutine=5)
        server = grpc.server(concurrent.futures.ThreadPoolExecutor(max_workers=2))
        server.add_generic_rpc_handlers((grpc.method_handlers_generic_handler('xray.app.stats.command.StatsService', {
            'QueryStats': grpc.unary_unary_rpc_method_handler(query, request_deserializer=pb.QueryStatsRequest.FromString, response_serializer=pb.QueryStatsResponse.SerializeToString),
            'GetStatsOnlineIpList': grpc.unary_unary_rpc_method_handler(online, request_deserializer=pb.GetStatsRequest.FromString, response_serializer=pb.GetStatsOnlineIpListResponse.SerializeToString),
            'GetUsersStats': grpc.unary_unary_rpc_method_handler(users, request_deserializer=pb.GetUsersStatsRequest.FromString, response_serializer=pb.GetUsersStatsResponse.SerializeToString),
            'GetSysStats': grpc.unary_unary_rpc_method_handler(sysstats, request_deserializer=pb.SysStatsRequest.FromString, response_serializer=pb.SysStatsResponse.SerializeToString),
        }),))
        port = server.add_insecure_port('127.0.0.1:0'); server.start()
        try:
            c = xray.Client({'id': 'wire', 'api_address': '127.0.0.1:' + str(port), 'service': 'test.service'})
            self.assertEqual(c.counters()['inbound>>>local>>>traffic>>>uplink'], 123)
            self.assertEqual(c.online('test@example.invalid'), {'198.51.100.7': 123})
            self.assertEqual(c.online_users(), {'test@example.invalid': {'198.51.100.8': 456}})
            self.assertTrue(c.users_api)
            self.assertEqual(c.runtime()['uptime'], 77)
            self.assertTrue(all(not reset for _, reset in seen))
            c.channel.close()
            old = xray.Client({'id': 'old', 'api_address': '127.0.0.1:' + str(port), 'service': 'test.service'})
            missing[0] = True
            self.assertIsNone(old.online_users())
            self.assertIs(old.users_api, False)
            old.channel.close()
        finally:
            server.stop(0).wait()


@unittest.skipUnless(os.environ.get('XRAY_TEST_BINARY'), 'set XRAY_TEST_BINARY for the real Xray test')
class NativeCoreTest(unittest.TestCase):
    def test_local_native_core_multi_config_and_real_traffic(self):
        binary = Path(os.environ['XRAY_TEST_BINARY'])
        self.assertTrue(binary.is_file(), 'Native Xray runtime is required')
        def free_port():
            with socket.socket() as s:
                s.bind(('127.0.0.1', 0)); return s.getsockname()[1]
        api, inbound, node = free_port(), free_port(), free_port()
        # The core leaves 127.0.0.1 and ::1 out of online lists; Linux can source the VLESS hop from 127.0.0.2.
        try:
            with socket.socket() as probe_source:
                probe_source.bind(('127.0.0.2', 0))
            source = '127.0.0.2'
        except OSError:
            source = ''
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                body = b'xray-real-local-traffic-' * 1000
                self.send_response(200);self.send_header('Content-Length', str(len(body)));self.end_headers();self.wfile.write(body)
            def log_message(self, *args): pass
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True);thread.start()
        with tempfile.TemporaryDirectory(prefix='xray-native-') as folder:
            base, overlay = Path(folder) / 'base.json', Path(folder) / 'stats.json'
            # socks -> VLESS chain -> VLESS node (one email user) -> freedom, all on loopback in one process.
            uid, email = '00000000-0000-4000-8000-000000000002', 'native@example.invalid'
            base.write_text(json.dumps({'log': {'loglevel': 'none'},
                'inbounds': [{'tag': 'local', 'protocol': 'socks', 'listen': '127.0.0.1', 'port': inbound, 'settings': {'auth': 'noauth'}},
                             {'tag': 'node', 'protocol': 'vless', 'listen': '127.0.0.1', 'port': node, 'settings': {'decryption': 'none', 'clients': [{'id': uid, 'email': email}]}}],
                # v26.10 freedom blocks private targets unless a final rule allows them.
                'outbounds': [{'tag': 'direct', 'protocol': 'freedom', 'settings': {'finalRules': [{'action': 'allow', 'ip': ['127.0.0.1/32']}]}},
                              {'tag': 'chain', 'protocol': 'vless', **({'sendThrough': source} if source else {}), 'settings': {'vnext': [{'address': '127.0.0.1', 'port': node, 'users': [{'id': uid, 'encryption': 'none'}]}]}}],
                'routing': {'rules': [{'type': 'field', 'inboundTag': ['local'], 'outboundTag': 'chain'}, {'type': 'field', 'inboundTag': ['node'], 'outboundTag': 'direct'}]}}))
            overlay.write_text(json.dumps({'stats': {}, 'api': {'tag': 'monitor-api', 'listen': '127.0.0.1:' + str(api), 'services': ['StatsService']},
                                           'policy': {'system': {'statsInboundUplink': True, 'statsInboundDownlink': True, 'statsOutboundUplink': True, 'statsOutboundDownlink': True},
                                                      'levels': {'0': {'statsUserUplink': True, 'statsUserDownlink': True, 'statsUserOnline': True}}}}))
            before = base.read_bytes()
            command = [str(binary), 'run', '-config', str(base), '-config', str(overlay)]
            check = subprocess.run(command + ['-test'], capture_output=True, timeout=15)
            self.assertEqual(check.returncode, 0)
            proc = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            c = xray.Client({'id': 'native', 'api_address': '127.0.0.1:' + str(api), 'service': 'test.service'})
            try:
                for _ in range(50):
                    self.assertIsNone(proc.poll())
                    try: initial = c.counters();break
                    except grpc.RpcError: time.sleep(.1)
                else: self.fail('Native API unavailable')
                r = subprocess.run(['/usr/bin/curl', '-q', '--proxy', 'socks5h://127.0.0.1:' + str(inbound), '--noproxy', '', '--max-time', '8', '-fsS', 'http://127.0.0.1:' + str(server.server_port)], capture_output=True, timeout=10)
                self.assertEqual(r.returncode, 0)
                self.assertGreater(len(r.stdout), 20000)
                counters = c.counters()
                self.assertGreater(counters['inbound>>>local>>>traffic>>>downlink'], initial['inbound>>>local>>>traffic>>>downlink'])
                self.assertGreater(counters['user>>>' + email + '>>>traffic>>>downlink'], 20000)
                self.assertGreater(counters['outbound>>>direct>>>traffic>>>downlink'], 20000)
                self.assertEqual(c.counters(), counters, 'QueryStats must never reset counters')
                self.assertGreaterEqual(c.runtime()['goroutines'], 1)
                # Online addresses are listed only while a connection is open: hold one through SOCKS.
                with socket.create_connection(('127.0.0.1', inbound), timeout=5) as held:
                    held.sendall(b'\x05\x01\x00'); held.recv(2)
                    held.sendall(b'\x05\x01\x00\x01\x7f\x00\x00\x01' + server.server_port.to_bytes(2, 'big')); held.recv(10)
                    held.sendall(b'GET / HTTP/1.1\r\n')  # an unfinished request keeps the chain open
                    for _ in range(20):
                        online = c.online_users()
                        # GetUsersStats exists from v26.10; older cores report it unimplemented and use per-user calls.
                        found = online.get(email, {}) if c.users_api else c.online(email) or {}
                        if not source or source in found:
                            break
                        time.sleep(.1)
                    if source:
                        self.assertIn(source, found)
                self.assertEqual(base.read_bytes(), before)
            finally:
                c.channel.close();proc.terminate()
                try: proc.wait(timeout=5)
                except subprocess.TimeoutExpired: proc.kill();proc.wait(timeout=5)
        server.shutdown();server.server_close();thread.join(timeout=5)


if __name__ == '__main__':
    unittest.main()
