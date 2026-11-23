"""Wire-compatible subset of sing-box daemon/started_service.proto, built at runtime.

Building descriptors in code removes the protoc step from deployment and works with both
the distribution protobuf 3.12 on the server and newer runtimes used in development.
Upstream schema: SagerNet sing-box (GPL-3.0-or-later), https://github.com/SagerNet/sing-box
"""
from google.protobuf import descriptor_pb2, descriptor_pool, message_factory

_T = descriptor_pb2.FieldDescriptorProto
STRING, INT32, INT64, BOOL, MESSAGE = _T.TYPE_STRING, _T.TYPE_INT32, _T.TYPE_INT64, _T.TYPE_BOOL, _T.TYPE_MESSAGE
OPTIONAL, REPEATED = _T.LABEL_OPTIONAL, _T.LABEL_REPEATED

MESSAGES = {
    'Empty': [],
    'SubscribeConnectionsRequest': [('interval', 1, INT64)],
    'Connection': [
        ('id', 1, STRING), ('inbound', 2, STRING), ('inboundType', 3, STRING), ('ipVersion', 4, INT32),
        ('network', 5, STRING), ('source', 6, STRING), ('destination', 7, STRING), ('domain', 8, STRING),
        ('protocol', 9, STRING), ('user', 10, STRING), ('fromOutbound', 11, STRING), ('createdAt', 12, INT64),
        ('closedAt', 13, INT64), ('uplink', 14, INT64), ('downlink', 15, INT64), ('uplinkTotal', 16, INT64),
        ('downlinkTotal', 17, INT64), ('rule', 18, STRING), ('outbound', 19, STRING), ('outboundType', 20, STRING),
        ('chainList', 21, STRING, REPEATED),
    ],
    'ConnectionEvent': [
        ('type', 1, INT32), ('id', 2, STRING), ('connection', 3, '.daemon.Connection'),
        ('uplinkDelta', 4, INT64), ('downlinkDelta', 5, INT64), ('closedAt', 6, INT64),
    ],
    'ConnectionEvents': [('events', 1, '.daemon.ConnectionEvent', REPEATED), ('reset', 2, BOOL)],
    'CloseConnectionRequest': [('id', 1, STRING)],
}

# ConnectionEvent.type values used by sing-box.
EVENT_NEW, EVENT_UPDATE, EVENT_CLOSED = 0, 1, 2


def _build():
    fdp = descriptor_pb2.FileDescriptorProto(name='joysol/started_service.proto', package='daemon', syntax='proto3')
    for name, fields in MESSAGES.items():
        message = fdp.message_type.add(name=name)
        for spec in fields:
            field_name, number, kind = spec[:3]
            label = spec[3] if len(spec) > 3 else OPTIONAL
            field = message.field.add(name=field_name, number=number, label=label, json_name=field_name)
            if isinstance(kind, str):
                field.type = MESSAGE
                field.type_name = kind
            else:
                field.type = kind
    pool = descriptor_pool.DescriptorPool()
    pool.Add(fdp)
    classes = {}
    factory = message_factory.MessageFactory(pool)
    for name in MESSAGES:
        desc = pool.FindMessageTypeByName('daemon.' + name)
        if hasattr(message_factory, 'GetMessageClass'):
            classes[name] = message_factory.GetMessageClass(desc)
        else:
            classes[name] = factory.GetPrototype(desc)
    return classes


_classes = _build()
Empty = _classes['Empty']
SubscribeConnectionsRequest = _classes['SubscribeConnectionsRequest']
Connection = _classes['Connection']
ConnectionEvent = _classes['ConnectionEvent']
ConnectionEvents = _classes['ConnectionEvents']
CloseConnectionRequest = _classes['CloseConnectionRequest']

SUBSCRIBE = '/daemon.StartedService/SubscribeConnections'
CLOSE = '/daemon.StartedService/CloseConnection'
