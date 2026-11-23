"""Condition-based alerts: opened once per key, resolved automatically when the condition clears.

Optional webhook (secrets: alert_webhook_url) receives a JSON POST for newly opened alerts.
"""
import json
import hashlib
import logging
import threading
import time
import urllib.request

from . import system

log = logging.getLogger(__name__)


class Alerts:
    def __init__(self, ctx):
        self.ctx = ctx
        self.webhook = ctx.settings.secrets.get('alert_webhook_url', '')

    def open_alerts(self):
        rows = self.ctx.store.reader().execute('SELECT * FROM alerts WHERE resolved=0 ORDER BY opened DESC').fetchall()
        return [dict(r) for r in rows]

    def recent(self, limit=100):
        rows = self.ctx.store.reader().execute('SELECT * FROM alerts ORDER BY opened DESC LIMIT ?', (limit,)).fetchall()
        return [dict(r) for r in rows]

    def for_engine(self, rows, engine):
        services = {i['service'] for i in self.ctx.xray.instances}
        if engine == 'xray':
            services.update(n for n in (self.ctx.settings.get('alerts.services') or []) if 'nginx' in n)
            return [r for r in rows if r['key'].startswith(('xray:', 'reachability:')) or r['key'] in ('cert', 'disk')
                    or r['key'] in {'service:' + s for s in services}]
        if engine == 'singbox':
            return [r for r in rows if not r['key'].startswith('xray:') and r['key'] not in {'service:' + s for s in services}]
        return rows

    def ack(self, alert_id=None, engine=None):
        with self.ctx.store.write() as c:
            if engine:
                rows = [dict(r) for r in c.execute('SELECT * FROM alerts WHERE resolved=0')]
                ids = [r['id'] for r in self.for_engine(rows, engine)]
                if alert_id and int(alert_id) not in ids:
                    return False
                c.executemany('UPDATE alerts SET acked=1 WHERE id=?', [(int(alert_id),)] if alert_id else [(i,) for i in ids])
            elif alert_id:
                c.execute('UPDATE alerts SET acked=1 WHERE id=?', (int(alert_id),))
            else:
                c.execute('UPDATE alerts SET acked=1 WHERE resolved=0')
        return True

    def evaluate(self):
        found = {}
        ctx, s = self.ctx, self.ctx.settings
        health = ctx.health
        down_for = time.time() - (health.get('last_event', 0) / 1000 or health['started'])
        if ctx.singbox_enabled and not health.get('connected') and down_for >= int(s.get('alerts.collector_down_seconds')):
            found['collector'] = ('collector', 'critical', '内核事件采集中断 %d 秒：%s' % (down_for, health.get('last_error') or '未知原因'))
        if hasattr(ctx, 'xray'):
            for instance in ctx.xray.snapshot()['instances']:
                age = time.time() - (instance['last_success'] or health['started'])
                if not instance['connected'] and age >= int(s.get('alerts.collector_down_seconds')):
                    found['xray:' + instance['id']] = ('collector', 'critical', instance['label'] + ' Xray 采集中断：' + instance['error'])
        self._xray_media(found)
        self._singbox_media(found)
        self._mainland(found)
        cert = system.certificate(ctx.cert_path())
        days = int(s.get('alerts.cert_days'))
        if cert.get('days_left') is not None and cert['days_left'] < days:
            found['cert'] = ('cert', 'warning', 'TLS 证书 %.1f 天后到期' % cert['days_left'])
        usage = system.disk(str(s.data_dir))
        if usage['percent'] >= float(s.get('alerts.disk_percent')):
            found['disk'] = ('disk', 'warning', '数据盘已用 %.1f%%' % usage['percent'])
        for name, state in system.services(list(s.get('alerts.services') or [])).items():
            if state != 'active':
                found['service:' + name] = ('service', 'critical', '服务 %s 状态 %s' % (name, state))
        threshold = int(s.get('alerts.ip_daily_bytes') or 0)
        if ctx.singbox_enabled and threshold > 0:
            day = ctx.store.day()
            for r in ctx.store.reader().execute('SELECT ip,upload+download b FROM daily WHERE day=? AND upload+download>=?', (day, threshold)):
                found['quota:%s:%s' % (day, r['ip'])] = ('quota', 'warning', '%s 今日流量超过阈值' % r['ip'])
        self._xray_quota(found)
        self._sync(found)

    def _xray_quota(self, found):
        ctx = self.ctx
        threshold = int(ctx.settings.get('alerts.xray_user_daily_bytes') or 0)
        if threshold <= 0 or not ctx.xray.ledger or ctx.settings.get('xray.node_only'):
            return
        day = ctx.store.day()
        for row in ctx.xray.ledger.user_day_totals(day):
            if row['total'] >= threshold:
                key = 'xray:quota:%s:%s' % (day, hashlib.sha256((row['instance'] + '\x1f' + row['email']).encode()).hexdigest()[:24])
                found[key] = ('quota', 'warning', 'Xray 用户 %s 今日流量超过阈值' % row['email'])

    def _xray_media(self, found):
        ctx, s = self.ctx, self.ctx.settings
        limit = int(s.get('alerts.probe_failures'))
        if not s.get('probes.enabled') or limit <= 0 or not ctx.xray.ledger:
            return
        interval = int(s.get('probes.interval_seconds'))
        health = ctx.xray.ledger.probe_health(limit, interval)
        snapshot = ctx.xray.snapshot(detail=False)
        labels = {n['instance'] + ':' + n['outbound']: n['label'] for n in snapshot['nodes'] if n['probe']}
        self._media(found, 'xray', labels, health)
        if snapshot['probe_error']:
            found['xray:probe-worker'] = ('monitor', 'warning', 'Xray 出口探测任务异常：' + snapshot['probe_error'])

    def _singbox_media(self, found):
        ctx, s = self.ctx, self.ctx.settings
        limit = int(s.get('alerts.probe_failures'))
        if not ctx.singbox_enabled or not s.get('probes.enabled') or limit <= 0:
            return
        interval = int(s.get('probes.interval_seconds'))
        health = ctx.prober.probe_health(limit, interval)
        labels = {o['tag']: o['label'] for o in ctx.prober.outbounds()}
        if not labels or not s.get('probes.targets'):
            return
        self._media(found, 'singbox', labels, health)
        current = {r['key']: r for r in self.open_alerts()}
        targets = {t['name'] for t in (s.get('probes.targets') or [])}
        for tag, label in labels.items():
            states = health.get(tag, {})
            key = 'probe:' + tag  # keep the legacy whole-exit alert identity
            fresh = targets and all(t in states and time.time() - states[t]['at'] <= max(120, interval * 3) for t in targets)
            if fresh and all(not states[t]['ok'] and states[t]['failures'] >= limit for t in targets):
                found[key] = ('probe', 'warning', '出口 %s 连续 %d 轮探测失败' % (label, limit))
            elif key in current and (not fresh or not any(states[t]['ok'] for t in targets)):
                old = current[key]; found[key] = (old['kind'], old['level'], old['message'])
            changes = ctx.prober.exit_changes(tag, 2)
            if len(changes) == 2 and time.time() - changes[-1]['at'] < 86400:
                found['exit:%s:%s' % (tag, changes[-1]['exit_ip'])] = (
                    'exit', 'info', '出口 %s 的公网地址已变化：%s → %s' % (label, changes[0]['exit_ip'], changes[1]['exit_ip']))
        if ctx.prober.error:
            found['singbox:probe-worker'] = ('monitor', 'warning', 'sing-box 出口探测任务异常：' + ctx.prober.error)

    def _media(self, found, engine, labels, health):
        ctx, s = self.ctx, self.ctx.settings
        limit = int(s.get('alerts.probe_failures'))
        interval = int(s.get('probes.interval_seconds'))
        targets = {t['name'] for t in (s.get('probes.targets') or [])}
        current = {r['key']: r for r in self.open_alerts()}
        now = time.time()
        for outbound, label in labels.items():
            for name in targets:
                result = health.get(outbound, {}).get(name)
                key = engine + ':media:' + hashlib.sha256((outbound + '\x1f' + name).encode()).hexdigest()[:24]
                stale = not result or now - result['at'] > max(120, interval * 3)
                if stale:
                    if key in current:
                        old = current[key]
                        found[key] = (old['kind'], old['level'], old['message'])
                    if result or now - ctx.health['started'] > max(120, interval * 3):
                        found[engine + ':probe-stale:' + hashlib.sha256(outbound.encode()).hexdigest()[:24]] = (
                            'monitor', 'warning', label + ' 出口探测数据缺失或过期，媒体状态未知')
                elif not result['ok'] and result['failures'] >= limit:
                    found[key] = ('media', 'warning', '%s · %s 连续 %d 轮探测失败：%s' % (label, name, result['failures'], result['error'] or 'HTTPS 不可达'))
                elif not result['ok'] and key in current:
                    old = current[key]
                    found[key] = (old['kind'], old['level'], old['message'])

    def _mainland(self, found):
        status = self.ctx.reachability.snapshot()
        if not status['enabled']:
            return
        threshold = max(1, int(status['failures']))
        for row in status.get('rows', []):
            if row['alarm']:
                place = row.get('failed_city') or row.get('city') or '抽样探测点'
                message = '%s · 国内%s（%s）入口 HTTPS 持续失败：%s' % (row['label'], row['isp'], place, row['error'])
                if row['ok'] is None:
                    message = '%s · 国内%s（%s）上次入口故障尚未确认恢复，本轮检测未知：%s' % (row['label'], row['isp'], place, row['error'])
                found['reachability:' + row['key']] = ('reachability', 'warning', message)
        if status.get('provider_failures', 0) >= threshold:
            found['reachability:provider'] = ('monitor', 'warning', '公开大陆检测服务持续异常，部分检测结果未知：' + status.get('provider_error', ''))
        if status.get('at') and time.time() - status['at'] > max(1800, int(status['interval']) * 3):
            found['reachability:stale'] = ('monitor', 'warning', '国内入口检测数据过期，当前可达性未知')

    def _sync(self, found):
        now = int(time.time())
        opened = []
        with self.ctx.store.write() as c:
            current = {r['key']: r['id'] for r in c.execute('SELECT id,key FROM alerts WHERE resolved=0')}
            for key, (kind, level, message) in found.items():
                if key in current:
                    c.execute('UPDATE alerts SET message=? WHERE id=?', (message, current[key]))
                else:
                    c.execute('INSERT INTO alerts(key,kind,level,message,opened) VALUES(?,?,?,?,?)', (key, kind, level, message, now))
                    opened.append({'kind': kind, 'level': level, 'message': message})
            for key, alert_id in current.items():
                if key not in found:
                    c.execute('UPDATE alerts SET resolved=? WHERE id=?', (now, alert_id))
        if opened and self.webhook:
            threading.Thread(target=self._notify, args=(opened,), daemon=True).start()

    def _notify(self, items):
        title = self.ctx.settings.get('site.title')
        for item in items:
            body = json.dumps({'title': title, 'level': item['level'], 'kind': item['kind'], 'message': item['message'],
                               'text': '[%s] %s' % (title, item['message'])}).encode()
            try:
                request = urllib.request.Request(self.webhook, data=body, headers={'Content-Type': 'application/json'})
                urllib.request.urlopen(request, timeout=10).read(256)
            except Exception as exc:
                log.warning('Alert webhook failed: %s', type(exc).__name__)
