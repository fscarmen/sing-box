"""Layered configuration: built-in defaults < settings file < environment; secrets kept apart.

Nothing in this package hard-codes a domain, server address, port or sing-box tag.
Topology (inbounds/outbounds/rules) is read from the live sing-box config at runtime,
and the server's public address is discovered by probes.
"""
import copy
import json
import ipaddress
import os
from pathlib import Path
from urllib.parse import urlsplit

DEFAULTS = {
    'site': {
        # Public URL users open; the origin is used for CSRF/Origin checks.
        'public_url': 'http://127.0.0.1:8307',
        'base_path': '/monitor',
        'title': '网络节点监控',
        'timezone': 'Asia/Shanghai',
        'cookie_name': '__Host-joysol_session',
        'cookie_secure': True,
        'session_days_remember': 30,
        'session_days_default': 1,
    },
    'paths': {
        'data_dir': '/var/lib/joysol-dashboard',
        # Relative geo paths resolve against data_dir.
        'geo_dir': 'geo',
    },
    'singbox': {
        'enabled': True,
        'api_address': '127.0.0.1:8306',
        'config_path': '/etc/sing-box/config.json',
        'binary': '/usr/local/bin/sing-box',
        'subscribe_interval_ms': 1000,
    },
    # access_control: also ban on the public ports of Xray inbounds (needs firewall privileges; see docs/xray.md).
    'xray': {'instances': [], 'poll_seconds': 2, 'access_control': False, 'node_only': False},
    'gate': {
        # Enabled once the CDN origin header is verified; see docs/dashboard.md.
        'enabled': False,
        'origin_header': 'X-Joysol-Origin',
    },
    'firewall': {
        'chain': 'JOYSOL_NODE_BANS',
        # Empty list = derive from sing-box inbounds that listen on a non-loopback address.
        'ports': [],
        'min_prefix_v4': 16,
        'min_prefix_v6': 32,
    },
    'geo': {
        'ip2region_v4': 'ip2region_v4.xdb',
        'ip2region_v6': 'ip2region_v6.xdb',
        # Legacy DB-IP files live directly in data_dir.
        'city_mmdb': '../city.mmdb',
        'asn_mmdb': '../asn.mmdb',
        'cache_size': 4096,
    },
    'probes': {
        'enabled': True,
        'interval_seconds': 300,
        'timeout_seconds': 12,
        # Trace confirms the exit IP; media probes check HTTPS reachability only.
        'targets': [
            {'name': 'trace', 'url': 'https://www.cloudflare.com/cdn-cgi/trace'},
            {'name': 'Instagram', 'url': 'https://www.instagram.com/', 'kind': 'http'},
            {'name': 'YouTube', 'url': 'https://www.youtube.com/generate_204', 'kind': 'http'},
            {'name': 'Facebook', 'url': 'https://www.facebook.com/', 'kind': 'http'},
        ],
        # Outbound tags to skip; empty = probe every supported outbound.
        'skip': [],
    },
    'reachability': {'enabled': False, 'interval_seconds': 600, 'failures': 2, 'targets': [],
                     'resolver': '223.5.5.5', 'fallback_resolver': '119.29.29.29'},
    'live': {
        'history_seconds': 900,
        'top_connections': 60,
        'max_streams': 8,
    },
    'alerts': {
        'collector_down_seconds': 60,
        'probe_failures': 2,
        'cert_days': 14,
        'disk_percent': 85,
        # 0 disables the per-IP daily traffic alert.
        'ip_daily_bytes': 0,
        # 0 disables the per-user (Xray email) daily traffic alert.
        'xray_user_daily_bytes': 0,
        'services': ['sing-box.service', 'nginx.service'],
    },
    'network': {
        # Empty = interfaces with an IPv4 default route.
        'interfaces': [],
        # CDN origin ports (TLS behind the CDN); filled from the site profile at deploy time.
        'edge_ports': [],
        'quality_enabled': True,
        'quality_interval_seconds': 60,
        'quality_retention_days': 30,
        'minute_retention_days': 7,
        'proc_net_dev': '/proc/net/dev',
        'proc_route': '/proc/net/route',
        'boot_id_path': '/proc/sys/kernel/random/boot_id',
        'port_range_path': '/proc/sys/net/ipv4/ip_local_port_range',
    },
    'tls': {
        # Empty = /etc/letsencrypt/live/<public host>/fullchain.pem
        'cert_path': '',
    },
    # Display names; keys are sing-box tags. Unlisted tags are shown as-is.
    'labels': {'inbounds': {}, 'outbounds': {}, 'xray': {}},
    # Per-inbound entry kind override: "cdn" or "direct". Auto-detected otherwise.
    'entries': {},
}

# Values the panel UI may change at runtime (stored in the database, not the file).
EDITABLE = {
    'labels.inbounds', 'labels.outbounds', 'labels.xray', 'entries',
    'alerts.ip_daily_bytes', 'alerts.xray_user_daily_bytes', 'alerts.cert_days', 'alerts.disk_percent',
    'alerts.collector_down_seconds', 'alerts.probe_failures',
    'reachability.enabled', 'reachability.interval_seconds', 'reachability.failures',
    'probes.interval_seconds', 'probes.enabled',
    'network.quality_enabled', 'network.quality_interval_seconds',
}

ENV_OVERRIDES = {
    'JOYSOL_PUBLIC_URL': 'site.public_url',
    'JOYSOL_BASE_PATH': 'site.base_path',
    'JOYSOL_DATA_DIR': 'paths.data_dir',
    'JOYSOL_SINGBOX_API': 'singbox.api_address',
    'JOYSOL_SINGBOX_CONFIG': 'singbox.config_path',
}


def merge(base, extra):
    out = copy.deepcopy(base)
    for key, value in (extra or {}).items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            out[key] = merge(out[key], value)
        else:
            out[key] = copy.deepcopy(value)
    return out


def get_path(tree, dotted, default=None):
    node = tree
    for part in dotted.split('.'):
        if not isinstance(node, dict) or part not in node:
            return default
        node = node[part]
    return node


def set_path(tree, dotted, value):
    parts = dotted.split('.')
    node = tree
    for part in parts[:-1]:
        node = node.setdefault(part, {})
    node[parts[-1]] = value


class Settings:
    """Effective settings. `secrets` never leaves the server."""

    def __init__(self, values, secrets, sources):
        self.values = values
        self.secrets = secrets
        self.sources = sources
        self.overrides = {}

    def get(self, dotted, default=None):
        if dotted in self.overrides:
            return self.overrides[dotted]
        return get_path(self.values, dotted, default)

    def section(self, name):
        value = copy.deepcopy(self.values.get(name, {}))
        for key, override in self.overrides.items():
            if key.startswith(name + '.'):
                set_path(value, key[len(name) + 1:], override)
            elif key == name:
                value = copy.deepcopy(override)
        return value

    def apply_overrides(self, overrides):
        self.overrides = {k: v for k, v in overrides.items() if k in EDITABLE}

    @property
    def base_path(self):
        return '/' + self.get('site.base_path').strip('/')

    @property
    def public_origin(self):
        parts = urlsplit(self.get('site.public_url'))
        return parts.scheme + '://' + parts.netloc

    @property
    def public_host(self):
        return urlsplit(self.get('site.public_url')).hostname or ''

    @property
    def data_dir(self):
        return Path(self.get('paths.data_dir'))

    def data_path(self, value, under='paths.geo_dir'):
        path = Path(value)
        if path.is_absolute():
            return path
        return (self.data_dir / self.get(under) / path).resolve() if under else self.data_dir / path

    @property
    def gate_enabled(self):
        return bool(self.get('gate.enabled') or self.secrets.get('esa_gate_enabled'))

    def public_view(self):
        """Non-secret settings shown in the system page."""
        return {
            'values': merge(self.values, {}),
            'overrides': copy.deepcopy(self.overrides),
            'sources': self.sources,
            'editable': sorted(EDITABLE),
        }


def load(settings_path=None, secrets_path=None, environ=None):
    environ = os.environ if environ is None else environ
    config_dir = Path(environ.get('JOYSOL_CONFIG_DIR', '/etc/joysol-dashboard'))
    settings_path = Path(settings_path or environ.get('JOYSOL_DASHBOARD_SETTINGS', config_dir / 'settings.json'))
    # Secrets keep the historical file name so existing maintenance scripts keep working.
    secrets_path = Path(secrets_path or environ.get('JOYSOL_DASHBOARD_CONFIG', config_dir / 'config.json'))
    sources = []
    values = copy.deepcopy(DEFAULTS)
    secrets = json.loads(secrets_path.read_text())
    sources.append(str(secrets_path))
    # Legacy single-file deployments stored a few settings beside the secrets.
    legacy = {}
    if secrets.get('public_origin'):
        set_path(legacy, 'site.public_url', secrets['public_origin'])
    if 'data_dir' in secrets:
        set_path(legacy, 'paths.data_dir', secrets['data_dir'])
    if 'api_address' in secrets:
        set_path(legacy, 'singbox.api_address', secrets['api_address'])
    if 'esa_gate_enabled' in secrets:
        set_path(legacy, 'gate.enabled', bool(secrets['esa_gate_enabled']))
    values = merge(values, legacy)
    if settings_path.exists():
        values = merge(values, json.loads(settings_path.read_text()))
        sources.append(str(settings_path))
    for env, dotted in ENV_OVERRIDES.items():
        if environ.get(env):
            set_path(values, dotted, environ[env])
            sources.append('env:' + env)
    validate(values, secrets)
    return Settings(values, secrets, sources)


def validate(values, secrets):
    for key in ('reachability.resolver', 'reachability.fallback_resolver'):
        try:
            resolver = ipaddress.ip_address(get_path(values, key))
            if resolver.version != 4 or not resolver.is_global:
                raise ValueError('Resolver must be a public IPv4 address')
        except (ValueError, TypeError):
            raise ValueError(key + ' must be a public IPv4 address') from None
    enabled = get_path(values, 'singbox.enabled', True)
    if not isinstance(enabled, bool):
        raise ValueError('singbox.enabled must be a boolean')
    if not enabled and not get_path(values, 'xray.instances') and not get_path(values, 'management.enabled', False):
        raise ValueError('At least one monitoring engine must be configured')
    if not isinstance(get_path(values, 'xray.access_control', False), bool):
        raise ValueError('xray.access_control must be a boolean')
    if not isinstance(get_path(values, 'xray.node_only', False), bool):
        raise ValueError('xray.node_only must be a boolean')
    required = ('username', 'salt', 'password_hash') + (('api_secret',) if enabled else ())
    missing = [k for k in required if not secrets.get(k)]
    if missing:
        raise ValueError('secrets file is missing: ' + ', '.join(missing))
    url = urlsplit(get_path(values, 'site.public_url'))
    if url.scheme not in ('http', 'https') or not url.netloc:
        raise ValueError('site.public_url must be an absolute http(s) URL')
    base = get_path(values, 'site.base_path')
    if not isinstance(base, str) or not base.strip('/') or any(c in base for c in ' ?#'):
        raise ValueError('site.base_path must be a non-root path such as /monitor')
    if get_path(values, 'site.cookie_name', '').startswith('__Host-') and not get_path(values, 'site.cookie_secure'):
        raise ValueError('__Host- cookies require site.cookie_secure=true')
