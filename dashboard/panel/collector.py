"""sing-box gRPC telemetry: lifecycle event stream and connection close."""
import logging
import time

import grpc

from . import proto as pb

log = logging.getLogger(__name__)


class Collector:
    def __init__(self, ctx):
        self.ctx = ctx
        settings = ctx.settings
        self.channel = grpc.insecure_channel(settings.get('singbox.api_address'))
        self.subscribe = self.channel.unary_stream(pb.SUBSCRIBE, request_serializer=pb.SubscribeConnectionsRequest.SerializeToString,
                                                   response_deserializer=pb.ConnectionEvents.FromString)
        self.close_rpc = self.channel.unary_unary(pb.CLOSE, request_serializer=pb.CloseConnectionRequest.SerializeToString,
                                                  response_deserializer=pb.Empty.FromString)
        self.metadata = [('authorization', 'Bearer ' + settings.secrets['api_secret'])]
        self.interval = int(settings.get('singbox.subscribe_interval_ms')) * 1_000_000

    def run(self):
        health = self.ctx.health
        backoff = 2
        while not self.ctx.stop.is_set():
            try:
                self.ctx.live.reset()
                for batch in self.subscribe(pb.SubscribeConnectionsRequest(interval=self.interval), metadata=self.metadata):
                    self.ctx.store.ingest(batch)
                    health.update(connected=True, last_event=int(time.time() * 1000), last_error='')
                    backoff = 2
            except Exception as exc:
                health.update(connected=False, last_error=type(exc).__name__)
                log.warning('Telemetry disconnected: %s', type(exc).__name__)
                try:
                    self.ctx.store.collector_lost()
                except Exception:
                    log.exception('marking connections inactive failed')
                self.ctx.stop.wait(backoff)
                backoff = min(30, backoff * 2)

    def close(self, cid):
        try:
            self.close_rpc(pb.CloseConnectionRequest(id=cid), metadata=self.metadata, timeout=5)
            return True
        except grpc.RpcError:
            return False
