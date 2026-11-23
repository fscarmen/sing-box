"""Xray-first presentation. Never borrow sing-box bytes or connection counts."""
import time


GEO_KEYS = ('location', 'isp', 'asn', 'lat', 'lon', 'country_code', 'precision', 'source')


def present(ctx):
    data = ctx.xray.snapshot(detail=False)
    sources = {}
    outbounds = {}
    supported = 0
    for node in data['nodes']:
        node['outbound_key'] = node['instance'] + ':' + node['outbound'] if node['outbound'] else ''
        if node['online_sources'] is not None:
            supported += 1
            for ip in node['online_sources']:
                entry = sources.setdefault(ip, {'ip': ip, 'nodes': [], 'sampled_at': node['sampled_at']})
                entry['nodes'].append(node['key'])
                entry['sampled_at'] = max(entry['sampled_at'], node['sampled_at'])
        if node['outbound_key']:
            out = outbounds.setdefault(node['outbound_key'], {
                'key': node['outbound_key'], 'instance': node['instance'], 'tag': node['outbound'],
                'label': node['label'] + ' · 出口', 'nodes': [], 'probe': node['probe'],
                'upload': 0, 'download': 0, 'up_rate': 0, 'down_rate': 0, 'fresh': True,
            })
            out['nodes'].append(node['key'])
            for key in ('upload', 'download'):
                out[key] += node[key]
            for key in ('up_rate', 'down_rate'):
                if node[key] is None or out[key] is None:
                    out[key] = None
                else:
                    out[key] += node[key]
            out['fresh'] = out['fresh'] and node['fresh']
    measured = {o['key']: o for o in data['outbound_stats']}
    for out in outbounds.values():
        # Real outbound counters when the core records them; summed inbound bytes stay as the fallback.
        real = measured.get(out['key'])
        out['measured'] = bool(real)
        if real:
            out.update({k: real[k] for k in ('upload', 'download', 'up_rate', 'down_rate', 'today_upload', 'today_download')})
    for user in data['users']:
        user['total'] = None if user['upload'] is None else user['upload'] + user['download']
        user['today'] = None if user['today_upload'] is None else user['today_upload'] + user['today_download']
    for entry in sources.values():
        geo = ctx.geo.lookup(entry['ip'])
        entry['geo'] = {k: geo[k] for k in GEO_KEYS}
    for out in outbounds.values():
        result = data['probes'].get(out['key'])
        trace = result.get('targets', {}).get('trace', {}) if result else {}
        # Only a validated echo is an observed exit address.
        out['exit_ip'] = trace.get('exit_ip', '') if trace.get('ok') else ''
        out['probe_at'] = result['at'] if result else None
        out['targets'] = result.get('targets', {}) if result else {}
        out['geo'] = {k: ctx.geo.lookup(out['exit_ip'])[k] for k in GEO_KEYS} if out['exit_ip'] else None
    data.update(engine='xray', sources=list(sources.values()), source_nodes_supported=supported,
                outbounds=list(outbounds.values()), since=min((n['since'] for n in data['nodes']), default=None),
                probe_interval=ctx.settings.get('probes.interval_seconds'),
                probe_targets=[t['name'] for t in ctx.settings.get('probes.targets') or [] if t['name'] != 'trace'], probes_enabled=bool(ctx.settings.get('probes.enabled')),
                capabilities={'node_bytes': True, 'node_rates': True, 'daily_bytes': True, 'connection_count': False,
                              'per_connection_bytes': False, 'client_bytes': False, 'destination_history': False,
                              'user_bytes': any(u['upload'] is not None for u in data['users']),
                              'outbound_bytes': bool(data['outbound_stats']),
                              'close_connection': False, 'access_control': ctx.bans_enabled and bool(ctx.settings.get('xray.access_control'))})
    return data


def details(ctx, span):
    seconds = {'24h': 86400, '7d': 7 * 86400, '30d': 30 * 86400}.get(span, 86400)
    now = int(time.time())
    step = 60 if seconds <= 86400 else 3600
    result = ctx.xray.ledger.details(now - seconds, ctx.store.day(now - seconds), step) if ctx.xray.ledger else {
        'daily': [], 'user_daily': [], 'outbound_daily': [], 'minutes': [], 'sample_step': step, 'probe_history': [], 'probe_history_truncated': False}
    result.update(engine='xray', range=span, since=now - seconds,
                  history_scope='每分钟按实例记录入站流量，用户与出站按自然日累计；逐连接、目标域名和单个 IP 的字节未由 Xray 提供。探测历史最多保留 7 天。')
    if ctx.settings.get('xray.node_only'):
        result.update(user_daily=[], outbound_daily=[], history_scope='仅展示节点入站日累计与实例分钟增量；既有用户/出站历史账本保留。')
    return result


def alerts_for_xray(ctx, rows):
    return ctx.alerts.for_engine(rows, 'xray')
