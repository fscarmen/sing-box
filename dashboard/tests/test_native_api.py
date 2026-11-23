"""Optional real-core check: SINGBOX_TEST_BINARY=/path/to/sing-box python -m unittest ..."""
import json
import os
import socket
import subprocess
import tempfile
import unittest
from pathlib import Path

from helpers import pb
import grpc


@unittest.skipUnless(os.environ.get('SINGBOX_TEST_BINARY'), 'set SINGBOX_TEST_BINARY for the real-core test')
class NativeApiTest(unittest.TestCase):
    def test_managed_service_supports_authenticated_lifecycle_stream(self):
        binary = str(Path(os.environ['SINGBOX_TEST_BINARY']).resolve())
        with tempfile.TemporaryDirectory() as tmp:
            with socket.socket() as sock:
                sock.bind(('127.0.0.1', 0)); port = sock.getsockname()[1]
            config = {'outbounds': [{'type': 'direct', 'tag': 'direct'}],
                      'services': [{'type': 'api', 'tag': 'fork-dashboard-api', 'listen': '127.0.0.1',
                                    'listen_port': port, 'secret': 'integration-secret', 'dashboard': False}]}
            Path(tmp, '09_dashboard_api.json').write_text(json.dumps(config))
            subprocess.run([binary, 'check', '-C', tmp], capture_output=True, check=True)
            process = subprocess.Popen([binary, 'run', '-C', tmp], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            channel = grpc.insecure_channel('127.0.0.1:%d' % port)
            try:
                grpc.channel_ready_future(channel).result(timeout=10)
                subscribe = channel.unary_stream(pb.SUBSCRIBE, request_serializer=pb.SubscribeConnectionsRequest.SerializeToString,
                                                 response_deserializer=pb.ConnectionEvents.FromString)
                stream = subscribe(pb.SubscribeConnectionsRequest(interval=1_000_000_000),
                                   metadata=[('authorization', 'Bearer integration-secret')], timeout=10)
                batch = next(stream)
                self.assertTrue(batch.reset)
                stream.cancel()
                with self.assertRaises(grpc.RpcError) as caught:
                    next(subscribe(pb.SubscribeConnectionsRequest(), timeout=5))
                self.assertEqual(caught.exception.code(), grpc.StatusCode.UNAUTHENTICATED)
            finally:
                channel.close()
                process.terminate()
                process.wait(timeout=10)
