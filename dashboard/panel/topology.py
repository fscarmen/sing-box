"""Read the live sing-box configuration (read-only) and describe the node topology.

Inbounds, outbounds and route rules are discovered here, so new nodes or exits appear
in the panel without code changes. Upstream credentials stay inside this module.
"""
import ipaddress
import json
import os
import re
import threading

PROXY_TYPES = {'socks', 'http'}
LAYERED_TRANSPORTS = {'ws', 'httpupgrade', 'grpc', 'http'}
# Inbound types that listen on UDP (QUIC) instead of TCP.
UDP_TYPES = {'hysteria', 'hysteria2', 'tuic'}
MATCHER_NAMES = {
    'domain': '域名', 'domain_suffix': '域名后缀', 'domain_keyword': '域名关键字', 'domain_regex': '域名正则',
    'geosite': 'GeoSite', 'geoip': 'GeoIP', 'ip_cidr': 'IP 段', 'ip_is_private': '私网 IP', 'rule_set': '规则集',
    'inbound': '入站', 'network': '网络', 'protocol': '协议', 'port': '端口', 'source_ip_cidr': '来源 IP',
    'user': '用户', 'auth_user': '用户', 'clash_mode': '模式', 'process_name': '进程',
}
_RULE_ACTION = re.compile(r'=>\s*([a-z_-]+)(?:\(([^)]*)\))?\s*$')


def _loopback(listen):
    if not listen:
        return False
    if listen in ('localhost',):
        return True
    try:
        return ipaddress.ip_address(listen).is_loopback
    except ValueError:
        return False


def rule_label(raw):
    """Compact, stable label for a sing-box rule string (used as a topology node)."""
    raw = (raw or '').strip()
    if not raw:
        return '默认出口 (final)'
    match = _RULE_ACTION.search(raw)
    head = raw[:match.start()] if match else raw
    keys = []
    depth = 0
    token = ''
    for char in head:
        if char in '[(':
            depth += 1
        elif char in '])':
            depth -= 1
        elif char == '=' and depth == 0:
            name = token.strip().split(' ')[-1]
            if name and name not in keys:
                keys.append(name)
            token = ''
            continue
        if depth == 0 and char == ' ':
            token = ''
        else:
            token += char
    names = [MATCHER_NAMES.get(k, k) for k in keys if k not in ('inbound', 'network')]
    label = ' + '.join(names) or '规则'
    if match:
        action, target = match.group(1), (match.group(2) or '').strip()
        label += ' → ' + (target if action == 'route' and target else action)
    return label[:80]


class Topology:
    def __init__(self, settings):
        self.settings = settings
        self.path = settings.get('singbox.config_path')
        self.lock = threading.Lock()
        self.mtime = None
        self.error = ''
        self.inbounds, self.outbounds, self.rules, self.final = [], [], [], 'direct'
        self._credentials = {}
        self.refresh()

    def refresh(self):
        """Reload when the config file changed; cheap to call often."""
        if not self.settings.get('singbox.enabled'):
            return False
        try:
            mtime = os.stat(self.path).st_mtime
        except OSError as exc:
            self.error = type(exc).__name__
            return False
        if mtime == self.mtime:
            return False
        try:
            with open(self.path) as handle:
                config = json.load(handle)
        except (OSError, ValueError) as exc:
            self.error = type(exc).__name__
            return False
        with self.lock:
            self._parse(config)
            self.mtime = mtime
            self.error = ''
        return True

    def _parse(self, config):
        entries = self.settings.section('entries')
        labels = self.settings.section('labels')
        inbounds = []
        for item in config.get('inbounds', []):
            tag = item.get('tag') or item.get('type', '')
            transport = (item.get('transport') or {}).get('type', '')
            public = not _loopback(item.get('listen'))
            kind = entries.get(tag) or ('cdn' if not public and transport in LAYERED_TRANSPORTS else 'direct')
            inbounds.append({
                'tag': tag, 'type': item.get('type', ''), 'port': item.get('listen_port'), 'public': public,
                'network': 'udp' if item.get('type') in UDP_TYPES else 'tcp',
                'transport': transport or 'tcp', 'tls': bool((item.get('tls') or {}).get('enabled')),
                'reality': bool(((item.get('tls') or {}).get('reality') or {}).get('enabled')),
                'users': len(item.get('users', [])), 'entry': kind,
                'label': labels.get('inbounds', {}).get(tag) or tag,
            })
        outbounds = []
        credentials = {}
        for item in config.get('outbounds', []):
            tag = item.get('tag') or item.get('type', '')
            kind = item.get('type', '')
            probe = 'direct' if kind == 'direct' else 'proxy' if kind in PROXY_TYPES else ''
            if kind in ('block', 'dns'):
                continue
            outbounds.append({
                'tag': tag, 'type': kind, 'server': item.get('server', ''), 'port': item.get('server_port'),
                'detour': item.get('detour', ''), 'probe': probe,
                'label': labels.get('outbounds', {}).get(tag) or tag,
            })
            if probe == 'proxy':
                credentials[tag] = {
                    'type': kind, 'server': item.get('server', ''), 'port': int(item.get('server_port') or 0),
                    'username': item.get('username', ''), 'password': item.get('password', ''),
                    'tls': bool((item.get('tls') or {}).get('enabled')),
                    'sni': (item.get('tls') or {}).get('server_name') or item.get('server', ''),
                }
        route = config.get('route', {})
        rules = []
        for index, rule in enumerate(route.get('rules', [])):
            matchers = {}
            for key, value in rule.items():
                if key in ('action', 'outbound', 'invert'):
                    continue
                matchers[key] = len(value) if isinstance(value, list) else value
            rules.append({'index': index, 'action': rule.get('action', 'route'), 'outbound': rule.get('outbound', ''),
                          'matchers': matchers})
        self.inbounds, self.outbounds, self.rules = inbounds, outbounds, rules
        self.final = route.get('final') or (outbounds[0]['tag'] if outbounds else 'direct')
        self._credentials = credentials

    def describe(self):
        self.refresh()
        with self.lock:
            return {'inbounds': [dict(x) for x in self.inbounds], 'outbounds': [dict(x) for x in self.outbounds],
                    'rules': [dict(x) for x in self.rules], 'final': self.final, 'error': self.error}

    def proxy(self, tag):
        """Upstream credentials for probes; never serialised."""
        with self.lock:
            return dict(self._credentials[tag]) if tag in self._credentials else None

    def public_ports(self):
        return sorted({port for _, port in self.public_endpoints()})

    def public_endpoints(self):
        """(protocol, port) pairs of public inbounds; configured ports are taken as TCP."""
        configured = self.settings.get('firewall.ports') or []
        if configured:
            return sorted({('tcp', int(p)) for p in configured})
        with self.lock:
            return sorted({(x['network'], int(x['port'])) for x in self.inbounds if x['public'] and x['port']})

    def inbound(self, tag):
        with self.lock:
            return next((dict(x) for x in self.inbounds if x['tag'] == tag), None)

    def label(self, kind, tag):
        with self.lock:
            items = self.inbounds if kind == 'inbound' else self.outbounds
            return next((x['label'] for x in items if x['tag'] == tag), tag)
