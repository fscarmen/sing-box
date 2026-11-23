"""One client routing policy, compiled into client-specific subscription formats.

This never edits the VPS route or downloads external rule providers. Published
node snapshots remain immutable; one atomic policy revision covers both cores.
"""
import copy
import hashlib
import ipaddress
import json
import re
from pathlib import Path
from urllib.parse import urlsplit

import yaml

RULE_FILE = 'client-rules.json'
EXTRA_FORMATS = ('shadowrocket.conf', 'rules-clash', 'rules-sing-box', 'rules-v2rayn.json')
ACTIONS = ('proxy', 'direct', 'reject')
TYPES = ('domain', 'domain_suffix', 'domain_keyword', 'ip_cidr')
EMPTY = {'rules': [], 'default_action': 'inherit'}
CAPABILITIES = [
    {'client': 'Clash Meta / Mihomo', 'format': 'clash2', 'mode': 'subscription', 'message': '更新完整配置订阅即可同步规则；仅更新节点提供者不会更新规则。使用规则模式并检查本地覆写。'},
    {'client': 'sing-box', 'format': 'sing-box', 'mode': 'subscription', 'message': '更新并重新加载完整 JSON 配置即可同步规则。'},
    {'client': 'Shadowrocket', 'format': 'shadowrocket.conf', 'mode': 'remote-config', 'message': '节点订阅不携带规则。首次在“配置”中添加并启用此远程配置，后续更新远程配置；仅更新首页节点订阅无效。PROXY 使用客户端当前选择的节点。'},
    {'client': 'v2rayN', 'format': 'rules-v2rayn.json', 'mode': 'import', 'message': '节点订阅不携带路由；需单独导入路由 JSON，是否支持订阅路由以客户端版本为准。'},
    {'client': 'Throne / 其他节点订阅', 'format': '', 'mode': 'nodes-only', 'message': 'URI 节点订阅不能覆盖本地路由；可在支持完整 sing-box 配置的客户端导入 JSON。'},
]


def revision(policy):
    return hashlib.sha256(json.dumps(policy, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


def normalize_target(kind, value):
    if not isinstance(value, str) or not value.strip() or len(value) > 300:
        raise ValueError('请输入有效的目标')
    value = value.strip()
    if kind == 'ip_cidr':
        try:
            if '%' in value: raise ValueError
            return str(ipaddress.ip_network(value, strict=False))
        except ValueError:
            raise ValueError('IP / CIDR 格式错误')
    if kind == 'domain_keyword':
        if not re.fullmatch(r'[A-Za-z0-9_.-]{1,100}', value):
            raise ValueError('域名关键词仅支持字母、数字、点、下划线与连字符')
        return value.lower()
    if kind not in ('domain', 'domain_suffix'):
        raise ValueError('不支持的规则类型')
    value = value.lstrip('.') if kind == 'domain_suffix' else value
    try:
        value = value.rstrip('.').encode('idna').decode().lower()
    except UnicodeError:
        raise ValueError('域名格式错误')
    if len(value) > 253 or not re.fullmatch(r'(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', value):
        raise ValueError('请输入域名，不含 URL、端口、通配符或路径')
    try:
        ipaddress.ip_address(value)
    except ValueError:
        return value
    raise ValueError('IP 地址请选择 IP / CIDR 类型')


def candidate(value):
    """A history destination may be a host:port or [IPv6]:port, never a source IP."""
    if not isinstance(value, str): return None
    text = value.strip().rstrip('.')
    try:
        ip = ipaddress.ip_address(text)
        return {'type': 'ip_cidr', 'target': str(ip) + ('/32' if ip.version == 4 else '/128')}
    except ValueError:
        pass
    if text.startswith('[') or text.count(':') == 1:
        try:
            url = urlsplit('//' + text)
            if url.username or url.password or url.path or url.query or url.fragment:
                return None
            if url.port is not None:
                text = url.hostname or ''
        except ValueError:
            return None
    try:
        ip = ipaddress.ip_address(text)
        return {'type': 'ip_cidr', 'target': str(ip) + ('/32' if ip.version == 4 else '/128')}
    except ValueError:
        try: return {'type': 'domain', 'target': normalize_target('domain', text)}
        except ValueError: return None


def validate(value):
    if not isinstance(value, dict) or value.get('default_action', 'inherit') not in ('inherit',) + ACTIONS:
        raise ValueError('默认策略无效')
    rows = value.get('rules', [])
    if not isinstance(rows, list) or len(rows) > 2000:
        raise ValueError('规则应为列表，最多 2000 条')
    result, ids, targets = [], set(), set()
    for row in rows:
        if not isinstance(row, dict): raise ValueError('规则必须是对象')
        key, kind, action = row.get('id', ''), row.get('type'), row.get('action')
        if not isinstance(key, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', key) or key in ids:
            raise ValueError('规则编号无效或重复')
        ids.add(key)
        if action not in ACTIONS: raise ValueError('规则动作无效')
        target = normalize_target(kind, row.get('target'))
        if (kind, target) in targets: raise ValueError('同类型目标规则重复，请编辑已有规则')
        targets.add((kind, target))
        enabled = row.get('enabled', True)
        if type(enabled) is not bool: raise ValueError('启用状态必须为布尔值')
        note = row.get('note', '')
        if not isinstance(note, str) or len(note) > 200 or any(ord(c) < 32 for c in note):
            raise ValueError('备注最多 200 字，不含控制字符')
        result.append({'id': key, 'type': kind, 'target': target, 'action': action, 'enabled': enabled, 'note': note})
    return {'rules': result, 'default_action': value.get('default_action', 'inherit')}


def load(directory):
    path = Path(directory) / RULE_FILE
    if not path.exists(): return copy.deepcopy(EMPTY)
    # Fail closed on a corrupted policy, rather than silently dropping user rules.
    return validate(json.loads(path.read_text()))


def active(policy):
    return policy['default_action'] != 'inherit' or any(r['enabled'] for r in policy['rules'])


def fresh_tag(existing, seed):
    name, index = seed, 0
    while name in existing:
        index += 1; name = seed + '-' + str(index)
    return name


def clash_document(text, policy):
    value = yaml.safe_load(text)
    if not isinstance(value, dict): raise ValueError('Clash 配置顶层不是对象')
    groups, nodes = value.get('proxy-groups') or [], value.get('proxies') or []
    if not isinstance(groups, list) or not isinstance(nodes, list): raise ValueError('Clash 节点或策略组格式错误')
    names = [n['name'] for n in nodes if isinstance(n, dict) and n.get('name') and n.get('type') not in ('direct', 'reject')]
    if any(not isinstance(name, str) for name in names):
        raise ValueError('Clash 数字节点名需要使用引号')
    providers_config = value.get('proxy-providers') or {}
    if not isinstance(providers_config, dict): raise ValueError('Clash 节点提供者格式错误')
    providers = list(providers_config.keys())
    existing = set(names + [g.get('name') for g in groups if isinstance(g, dict)])
    proxy = fresh_tag(existing, '面板代理')
    needed = any(r['enabled'] and r['action'] == 'proxy' for r in policy['rules']) or policy['default_action'] == 'proxy'
    if needed:
        if not names and not providers: raise ValueError('Clash 配置没有可用节点或节点提供者')
        group = {'name': proxy, 'type': 'select'}
        if names: group['proxies'] = names
        if providers: group['use'] = providers
        value['proxy-groups'] = groups + [group]
    targets = {'proxy': proxy, 'direct': 'DIRECT', 'reject': 'REJECT'}
    custom = []
    for r in policy['rules']:
        if not r['enabled']: continue
        kind = {'domain': 'DOMAIN', 'domain_suffix': 'DOMAIN-SUFFIX', 'domain_keyword': 'DOMAIN-KEYWORD', 'ip_cidr': 'IP-CIDR'}[r['type']]
        if r['type'] == 'ip_cidr' and ':' in r['target']: kind = 'IP-CIDR6'
        custom.append(','.join((kind, r['target'], targets[r['action']])) + (',no-resolve' if r['type'] == 'ip_cidr' else ''))
    base = value.get('rules') or []
    if not isinstance(base, list) or any(not isinstance(r, str) for r in base): raise ValueError('Clash rules 必须为字符串列表')
    if policy['default_action'] != 'inherit':
        base = [r for r in base if r.split(',', 1)[0].strip().upper() != 'MATCH']
        base.append('MATCH,' + targets[policy['default_action']])
    value['rules'] = custom + base
    value['mode'] = 'rule'
    return value


def clash_text(text, policy):
    """Replace routing AST nodes only; retain scalar spelling in credentials.

    A whole-document safe_load/dump would turn an unquoted password 001234
    into an octal integer, or on/off into booleans. Nodes and provider URLs
    must keep their original YAML scalar values and alias relationships.
    """
    value = clash_document(text, policy)
    tree = yaml.compose(text, Loader=yaml.SafeLoader)
    def replace(key, data):
        node = yaml.compose(yaml.safe_dump({key: data}, allow_unicode=True, sort_keys=False), Loader=yaml.SafeLoader).value[0]
        for index, (existing, _) in enumerate(tree.value):
            if existing.value == key:
                tree.value[index] = (existing, node[1])
                return
        tree.value.append(node)
    old_groups = next((node for key, node in tree.value if key.value == 'proxy-groups'), None)
    count = len(old_groups.value) if isinstance(old_groups, yaml.SequenceNode) else 0
    if len(value.get('proxy-groups', [])) > count:
        added = yaml.compose(yaml.safe_dump(value['proxy-groups'][count:], allow_unicode=True, sort_keys=False), Loader=yaml.SafeLoader)
        if old_groups is None:
            replace('proxy-groups', value['proxy-groups'])
        elif isinstance(old_groups, yaml.SequenceNode):
            old_groups.value.extend(added.value)
        else:
            raise ValueError('Clash 策略组格式错误')
    replace('rules', value['rules'])
    replace('mode', value['mode'])
    return yaml.serialize(tree, Dumper=yaml.SafeDumper, allow_unicode=True)


def singbox_document(text, policy):
    value = json.loads(text)
    if not isinstance(value, dict): raise ValueError('sing-box 配置顶层不是对象')
    outbounds = value.get('outbounds') or []
    if not isinstance(outbounds, list): raise ValueError('sing-box outbounds 必须为列表')
    tags = {o.get('tag') for o in outbounds if isinstance(o, dict)}
    proxy_outs = [o for o in outbounds if isinstance(o, dict) and o.get('tag') and o.get('type') not in ('direct', 'block', 'dns')]
    route = value.setdefault('route', {})
    if not isinstance(route, dict): raise ValueError('sing-box route 必须是对象')
    proxy = next((o['tag'] for o in proxy_outs if o['tag'] == route.get('final')), None)
    proxy = proxy or next((o['tag'] for o in proxy_outs if o.get('type') == 'selector'), None) or next((o['tag'] for o in proxy_outs), None)
    direct = next((o['tag'] for o in outbounds if isinstance(o, dict) and o.get('type') == 'direct' and o.get('tag')), None)
    if any(r['enabled'] and r['action'] == 'direct' for r in policy['rules']) or policy['default_action'] == 'direct':
        if not direct:
            direct = fresh_tag(tags, 'panel-direct')
            outbounds.append({'type': 'direct', 'tag': direct}); value['outbounds'] = outbounds
    def action(name):
        if name == 'reject': return {'action': 'reject'}
        tag = proxy if name == 'proxy' else direct
        if not tag: raise ValueError('sing-box 配置没有可用的代理出站')
        return {'action': 'route', 'outbound': tag}
    custom = [{r['type']: [r['target']], **action(r['action'])} for r in policy['rules'] if r['enabled']]
    base = route.get('rules') or []
    if not isinstance(base, list) or any(not isinstance(r, dict) for r in base): raise ValueError('sing-box route.rules 必须为对象列表')
    # Keep leading sniff/DNS infrastructure before destination rules.
    prefix = 0
    while prefix < len(base) and base[prefix].get('action') in ('sniff', 'hijack-dns', 'resolve'):
        prefix += 1
    if policy['default_action'] != 'inherit':
        base = [r for r in base if not (set(r) <= {'action', 'outbound'} and r.get('action', 'route') in ('route', 'reject'))]
        prefix = 0
        while prefix < len(base) and base[prefix].get('action') in ('sniff', 'hijack-dns', 'resolve'): prefix += 1
        if policy['default_action'] == 'reject':
            base.append({'action': 'reject'})
        else:
            route['final'] = action(policy['default_action'])['outbound']
    route['rules'] = base[:prefix] + custom + base[prefix:]
    return value


def shadowrocket(policy, url=''):
    lines = ['# Managed client rules; PROXY uses the selected Shadowrocket node.', '[General]']
    if url: lines.append('update-url = ' + url)
    lines += ['', '[Rule]']
    for row in policy['rules']:
        if not row['enabled']: continue
        kind = {'domain': 'DOMAIN', 'domain_suffix': 'DOMAIN-SUFFIX', 'domain_keyword': 'DOMAIN-KEYWORD', 'ip_cidr': 'IP-CIDR'}[row['type']]
        if row['type'] == 'ip_cidr' and ':' in row['target']: kind = 'IP-CIDR6'
        lines.append(','.join((kind, row['target'], {'proxy': 'PROXY', 'direct': 'DIRECT', 'reject': 'REJECT'}[row['action']])) + (',no-resolve' if row['type'] == 'ip_cidr' else ''))
    final = {'inherit': 'PROXY', 'proxy': 'PROXY', 'direct': 'DIRECT', 'reject': 'REJECT'}[policy['default_action']]
    lines.extend(('FINAL,' + final, ''))
    return '\n'.join(lines)


def v2rayn(policy):
    rows = []
    for r in policy['rules']:
        if not r['enabled']: continue
        match = {'ip': [r['target']]} if r['type'] == 'ip_cidr' else {'domain': [{'domain': 'full:', 'domain_suffix': 'domain:', 'domain_keyword': ''}[r['type']] + r['target']]}
        rows.append({**match, 'outboundTag': {'proxy': 'proxy', 'direct': 'direct', 'reject': 'block'}[r['action']], 'enabled': True, 'remarks': r['note'] or r['target']})
    if policy['default_action'] != 'inherit':
        rows.append({'port': '0-65535', 'outboundTag': {'proxy': 'proxy', 'direct': 'direct', 'reject': 'block'}[policy['default_action']], 'enabled': True, 'remarks': '面板默认策略'})
    return rows


def render(name, text, policy, url=''):
    if name == 'shadowrocket.conf': return shadowrocket(policy, url)
    if name == 'rules-v2rayn.json': return json.dumps(v2rayn(policy), ensure_ascii=False, indent=2) + '\n'
    if name == 'rules-clash':
        # Rule-only preview uses a placeholder proxy policy, never node credentials.
        doc = clash_document('proxies: [{name: PROXY, type: socks5}]\nrules: []', policy)
        rules = [r.replace('面板代理', 'PROXY') for r in doc['rules']]
        return yaml.safe_dump({'rules': rules}, allow_unicode=True, sort_keys=False)
    if name == 'rules-sing-box':
        base = json.dumps({'outbounds': [{'type': 'socks', 'tag': 'PROXY'}]})
        return json.dumps({'route': singbox_document(base, policy)['route']}, ensure_ascii=False, indent=2) + '\n'
    if not active(policy): return text
    if name in ('clash', 'clash2'):
        return clash_text(text, policy)
    if name == 'sing-box': return json.dumps(singbox_document(text, policy), ensure_ascii=False, indent=2) + '\n'
    return text


def rules_only(name, text):
    """Expose routing only; do not return proxy credentials or provider URLs."""
    if name in ('clash', 'clash2'):
        doc = yaml.safe_load(text)
        if not isinstance(doc, dict): raise ValueError('Clash 配置顶层不是对象')
        return {'rules': doc.get('rules') or [], 'default': next((r for r in reversed(doc.get('rules') or []) if isinstance(r, str) and r.upper().startswith('MATCH,')), ''), 'mode': doc.get('mode', 'rule')}
    if name == 'sing-box':
        doc = json.loads(text)
        if not isinstance(doc, dict): raise ValueError('sing-box 配置顶层不是对象')
        route = doc.get('route') or {}
        if not isinstance(route, dict): raise ValueError('sing-box route 必须是对象')
        return {'rules': route.get('rules') or [], 'default': route.get('final', ''), 'mode': 'route'}
    if name == 'shadowrocket.conf': return {'rules': text.split('[Rule]\n', 1)[1].splitlines(), 'default': text.rstrip().splitlines()[-1], 'mode': 'remote-config'}
    return {'rules': json.loads(text), 'default': '', 'mode': 'import'}


def match_target(policy, value):
    inferred = candidate(value)
    if not inferred: return None
    for row in policy['rules']:
        if not row['enabled']: continue
        if row['type'] == 'ip_cidr' and inferred['type'] == 'ip_cidr':
            hit = ipaddress.ip_network(inferred['target']).network_address in ipaddress.ip_network(row['target'])
        elif inferred['type'] == 'domain':
            name, target = inferred['target'], row['target']
            hit = ((row['type'] == 'domain' and name == target)
                   or (row['type'] == 'domain_suffix' and (name == target or name.endswith('.' + target)))
                   or (row['type'] == 'domain_keyword' and target in name))
        else: hit = False
        if hit: return row
    return None
