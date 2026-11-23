"""Joysol node panel: application factory and background workers."""
import logging
import os
import threading
import time

from flask import Flask

from . import settings as settings_mod
from .alerts import Alerts
from .reachability import Reachability
from .auth import Auth
from .bans import Bans, Firewall
from .geo import Geo
from .live import Hub, Live
from .netstats import NetworkQueries, Nic, Quality
from .probes import Prober
from .store import Store
from .topology import Topology
from .xray import Monitor as XrayMonitor, public_endpoints as xray_endpoints

log = logging.getLogger(__name__)
VERSION = '2.5.3'


class Context:
    """Everything a request handler or worker needs; built once per process."""

    def __init__(self, settings, firewall_runner=None, start_workers=True):
        self.settings = settings
        self.version = VERSION
        self.health = {'connected': False, 'last_event': 0, 'last_error': '等待内核事件', 'started': time.time()}
        self.singbox_enabled = bool(settings.get('singbox.enabled'))
        if not self.singbox_enabled:
            self.health['last_error'] = 'sing-box 未启用'
        self.live = Live(settings.get('live.history_seconds'), settings.get('live.top_connections'))
        self.hub = Hub(settings.get('live.max_streams'))
        self.stop = threading.Event()
        self.collector = None
        self.store = Store(settings, self.live, on_banned=self._close_banned)
        settings.apply_overrides(self.store.prefs())
        self.topology = Topology(settings)
        self.geo = Geo(settings)
        self.xray_bans = bool(settings.get('xray.access_control') and settings.get('xray.instances'))
        # Access control covers sing-box node ports, and Xray public node ports when enabled.
        self.bans_enabled = self.singbox_enabled or self.xray_bans
        firewall = Firewall(settings.get('firewall.chain'), self.public_endpoints, firewall_runner)
        self.bans = Bans(self.store, firewall, settings)
        self.store.is_banned = self.bans.is_banned
        self.auth = Auth(settings, self.store)
        self.prober = Prober(settings, self.topology, self.store, self.geo)
        self.xray = XrayMonitor(settings, self.store.day, self.stop)
        self.reachability = Reachability(settings, self.store, self.stop)
        self.alerts = Alerts(self)
        self.nic = Nic(settings, self.store)
        self.quality = Quality(settings, self.store, self.topology)
        self.netq = NetworkQueries(self.store)
        self.pruned = 0
        if start_workers:
            self.start()

    def cert_path(self):
        return self.settings.get('tls.cert_path') or '/etc/letsencrypt/live/%s/fullchain.pem' % self.settings.public_host

    def update_prefs(self, changes):
        for key, value in changes.items():
            self.store.set_pref(key, value)
        self.settings.apply_overrides(self.store.prefs())
        self.topology.mtime = None
        self.topology.refresh()

    def public_endpoints(self):
        found = set(self.topology.public_endpoints()) if self.singbox_enabled or self.settings.get('firewall.ports') else set()
        if self.xray_bans and not self.settings.get('firewall.ports'):
            for instance in self.settings.get('xray.instances'):
                try:
                    found.update(xray_endpoints(instance))
                except (OSError, ValueError):
                    log.error('Xray inbound ports unavailable for %s', instance['id'])
        return sorted(found)

    def close_connections(self, ids):
        if self.collector:
            for cid in ids:
                self.collector.close(cid)

    def _close_banned(self, ids):
        threading.Thread(target=self.close_connections, args=(ids,), daemon=True).start()

    def start(self):
        from .collector import Collector
        if self.bans_enabled:
            self.bans.enforce_all()
        if self.singbox_enabled:
            self.collector = Collector(self)
            threading.Thread(target=self.collector.run, name='collector', daemon=True).start()
        if self.xray.instances:
            threading.Thread(target=self.xray.run, name='xray-stats', daemon=True).start()
        threading.Thread(target=self._ticker, name='ticker', daemon=True).start()
        threading.Thread(target=self._maintenance, name='maintenance', daemon=True).start()

    def frame(self):
        frame = self.live.frame()
        frame['health'] = {'connected': self.health['connected'], 'last_event': self.health['last_event']}
        frame['nic'] = self.nic.current()
        return frame

    def _ticker(self):
        # One frame per second to every stream subscriber.
        while not self.stop.wait(1.0):
            try:
                self.nic.sample()
            except Exception:
                log.exception('interface sample failed')
            if self.hub.count():
                try:
                    self.hub.publish(self.frame())
                except Exception:
                    log.exception('frame publish failed')

    def _maintenance(self):
        self.stop.wait(5)
        while not self.stop.is_set():
            for job in (self.topology.refresh, self._expire_bans, self._probe_if_due, self.reachability.start_if_due, self._quality_if_due, self._prune,
                        self.alerts.evaluate):
                try:
                    job()
                except Exception:
                    log.exception('maintenance job %s failed', getattr(job, '__name__', job))
            self.stop.wait(30)

    def _quality_if_due(self):
        if self.quality.due():
            self.quality.run()

    def _expire_bans(self):
        if self.bans_enabled:
            self.bans.expire()

    def _prune(self):
        if time.time() - self.pruned >= 3600:
            self.pruned = time.time()
            self.netq.prune(int(self.settings.get('network.quality_retention_days')), int(self.settings.get('network.minute_retention_days')))

    def _probe_if_due(self):
        if self.singbox_enabled and self.prober.due():
            threading.Thread(target=self.prober.run, name='probe', daemon=True).start()


def create_app(settings=None, firewall_runner=None, start_workers=None):
    settings = settings or settings_mod.load()
    if start_workers is None:
        start_workers = not os.environ.get('JOYSOL_TEST')
    ctx = Context(settings, firewall_runner, start_workers)
    app = Flask(__name__, static_folder=None)
    app.config.update(MAX_CONTENT_LENGTH=2 * 1024 * 1024, JSON_AS_ASCII=False, JSON_SORT_KEYS=False)
    app.extensions['joysol'] = ctx
    from .routes import register
    register(app, ctx)
    if settings.get('management.enabled', False):
        from .subscriptions import register as register_subscriptions
        register_subscriptions(app, settings.get('management.subscription_dir', str(settings.data_dir / 'subscriptions')))
    return app
