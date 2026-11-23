"""Wire subset of XTLS/Xray-core v26.10.21 app/stats/command/command.proto (GetUsersStats is absent before v26.10).

Uses a private descriptor pool; does not require protoc or modify the core.
"""
from google.protobuf import descriptor_pb2 as d, descriptor_pool, message_factory

f = d.FileDescriptorProto(name='panel/xray_stats.proto', package='xray.app.stats.command', syntax='proto3')


def message(name, fields):
    m = f.message_type.add(name=name)
    for name, number, kind, repeated in fields:
        field = m.field.add(name=name, number=number, label=3 if repeated else 1)
        if isinstance(kind, str):
            field.type = 11
            field.type_name = '.xray.app.stats.command.' + kind
        else:
            field.type = kind
    return m


message('QueryStatsRequest', [('pattern', 1, 9, False), ('reset', 2, 8, False)])
message('Stat', [('name', 1, 9, False), ('value', 2, 3, False)])
message('QueryStatsResponse', [('stat', 1, 'Stat', True)])
message('GetStatsRequest', [('name', 1, 9, False), ('reset', 2, 8, False)])
m = message('GetStatsOnlineIpListResponse', [('name', 1, 9, False)])
entry = m.nested_type.add(name='IpsEntry')
entry.options.map_entry = True
entry.field.add(name='key', number=1, type=9, label=1)
entry.field.add(name='value', number=2, type=3, label=1)
m.field.add(name='ips', number=2, type=11, type_name='.xray.app.stats.command.GetStatsOnlineIpListResponse.IpsEntry', label=3)
message('SysStatsRequest', [])
message('SysStatsResponse', [('NumGoroutine', 1, 13, False), ('NumGC', 2, 13, False), ('Alloc', 3, 4, False), ('TotalAlloc', 4, 4, False),
                             ('Sys', 5, 4, False), ('Mallocs', 6, 4, False), ('Frees', 7, 4, False), ('LiveObjects', 8, 4, False),
                             ('PauseTotalNs', 9, 4, False), ('Uptime', 10, 13, False)])
message('OnlineIPEntry', [('ip', 1, 9, False), ('last_seen', 2, 3, False)])
message('TrafficUserStat', [('uplink', 1, 3, False), ('downlink', 2, 3, False)])
message('UserStat', [('email', 1, 9, False), ('ips', 2, 'OnlineIPEntry', True), ('traffic', 3, 'TrafficUserStat', False)])
message('GetUsersStatsRequest', [('include_traffic', 1, 8, False), ('reset', 2, 8, False)])
message('GetUsersStatsResponse', [('users', 1, 'UserStat', True)])

pool = descriptor_pool.DescriptorPool()
pool.Add(f)
for name in ['QueryStatsRequest', 'QueryStatsResponse', 'GetStatsRequest', 'GetStatsOnlineIpListResponse', 'SysStatsRequest',
             'SysStatsResponse', 'GetUsersStatsRequest', 'GetUsersStatsResponse']:
    desc = pool.FindMessageTypeByName('xray.app.stats.command.' + name)
    globals()[name] = message_factory.GetMessageClass(desc) if hasattr(message_factory, 'GetMessageClass') else message_factory.MessageFactory(pool).GetPrototype(desc)

QUERY = '/xray.app.stats.command.StatsService/QueryStats'
ONLINE = '/xray.app.stats.command.StatsService/GetStatsOnlineIpList'
SYS = '/xray.app.stats.command.StatsService/GetSysStats'
USERS = '/xray.app.stats.command.StatsService/GetUsersStats'
