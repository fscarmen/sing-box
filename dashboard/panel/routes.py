"""HTTP layer. Every path lives under the configured base path; nothing assumes a host or port."""
import csv
import hmac
import io
import ipaddress
import json
import queue
import time
from pathlib import Path

from flask import Blueprint, Response, jsonify, make_response, redirect, request, send_from_directory, stream_with_context

from . import system
from .bans import canonical
from .store import RANGES
from .topology import rule_label
from . import xray_dashboard

ROOT = Path(__file__).resolve().parents[1]
STATIC = ROOT / 'static'
APP_DIST = STATIC / 'app'
PUBLIC_FILES = {'login.css', 'favicon.svg'}
CSP = ("default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; connect-src 'self'; "
       "font-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'")


def register(app, ctx):
    s = ctx.settings
    base = s.base_path
    bp = Blueprint('panel', __name__, url_prefix=base)
    cookie = s.get('site.cookie_name')

    def client_ip():
        # Nginx overwrites X-Dashboard-Client-IP with the TCP peer. Behind the CDN that peer is an
        # edge node, so the CDN-appended last X-Forwarded-For entry is trusted only with a valid origin header.
        trusted = request.remote_addr in ('127.0.0.1', '::1') and s.get('site.trust_proxy', True)
        peer = request.headers.get('X-Dashboard-Client-IP', request.remote_addr or '') if trusted else request.remote_addr or ''
        if trusted and _origin_verified(s):
            last = request.headers.get('X-Forwarded-For', '').split(',')[-1].strip()
            try:
                return str(ipaddress.ip_address(last))
            except ValueError:
                pass
        return peer

    def current_session():
        return ctx.auth.lookup(request.cookies.get(cookie, ''))

    def error(message, status):
        return jsonify(error=message), status

    def as_int(name, default, low=0, high=10 ** 9):
        try:
            return max(low, min(high, int(request.args.get(name, default))))
        except (TypeError, ValueError):
            return default

    @app.after_request
    def security(response):
        if not response.headers.get('Cache-Control'):
            response.headers['Cache-Control'] = 'private, no-store, no-cache, max-age=0'
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['Referrer-Policy'] = 'same-origin'
        response.headers['Content-Security-Policy'] = CSP
        return response

    @app.before_request
    def protect():
        path = request.path
        if request.endpoint and request.endpoint.startswith('subscriptions.'):
            # This GET-only blueprint checks its own independent download token.
            return None
        if path.startswith('/internal/'):
            if request.remote_addr not in ('127.0.0.1', '::1'):
                return '', 403
            return None
        if not path.startswith(base + '/') and path != base:
            return '', 404
        rel = path[len(base):]
        if rel in ('/login',) or rel.startswith('/static/') and rel.split('/')[-1] in PUBLIC_FILES:
            return None
        session = current_session()
        if not session:
            if rel.startswith('/api/'):
                return error('请重新登录', 401)
            return redirect(base + '/login')
        request.joysol_session = session
        if request.method not in ('GET', 'HEAD', 'OPTIONS'):
            if not hmac.compare_digest(request.headers.get('X-CSRF-Token', ''), session['csrf']):
                return error('请求验证失败', 403)
            if request.headers.get('Origin') != s.public_origin:
                return error('来源验证失败', 403)
        if not ctx.bans_enabled and rel == '/api/ban':
            return error('访问控制未启用；Xray 需在 settings.json 中设置 xray.access_control=true 后重启面板', 409)
        if not ctx.singbox_enabled and rel in ('/api/connections/close', '/api/probes/run', '/api/stream'):
            return error('sing-box 未启用；Xray 不提供关闭单连接与实时连接流', 409)
        return None

    # -- CDN origin gate (Nginx auth_request) ----------------------------------------------
    @app.route('/internal/gate')
    def gate():
        guard = request.headers.get('X-Origin-Guard', '')
        secret = s.secrets.get('origin_guard', '')
        if not secret or not hmac.compare_digest(guard, secret):
            return '', 403
        raw = request.headers.get('X-ESA-Client-IP', '').strip() or request.headers.get('X-Origin-XFF', '').split(',')[-1].strip()
        try:
            ip = str(ipaddress.ip_address(raw))
        except ValueError:
            return '', 403
        r = make_response('', 403 if ctx.bans.is_banned(ip) else 204)
        r.headers['X-Verified-Client-IP'] = ip
        return r

    @app.route('/internal/health')
    def internal_health():
        # Loopback only (see protect); used by the deploy script's post-switch check.
        xray = ctx.xray.snapshot(detail=False)
        primary = 'xray' if ctx.xray.instances else 'singbox'
        ok = all(i['connected'] for i in xray['instances']) if primary == 'xray' else ctx.health['connected']
        return jsonify(version=ctx.version, health=_health(ctx), schema=ctx.store.meta('schema_version', '1'),
                       base=base, gate=s.gate_enabled, inbounds=len(ctx.topology.describe()['inbounds']),
                       geo=sorted(ctx.geo.info()), migrations=ctx.store.migrations, xray=xray,
                       primary_engine=primary, ok=bool(ok))

    # -- pages -----------------------------------------------------------------------------
    def login_page(message='', status=200):
        html = (STATIC / 'login.html').read_text()
        html = html.replace('{{BASE}}', base).replace('{{TITLE}}', _escape(s.get('site.title')))
        html = html.replace('{{ERROR}}', _escape(message))
        r = make_response(html, status)
        r.headers['Content-Type'] = 'text/html; charset=utf-8'
        return r

    @bp.route('/login', methods=['GET', 'POST'])
    def login():
        if request.method == 'GET':
            return login_page()
        if request.headers.get('Origin') != s.public_origin:
            return error('来源验证失败', 403)
        ip = client_ip()
        if ctx.auth.throttled(ip):
            return login_page('尝试过多，请 15 分钟后重试。', 429)
        user = ctx.auth.check_password(request.form.get('username', ''), request.form.get('password', ''))
        if not user:
            ctx.auth.fail(ip)
            return login_page('用户名或密码错误，请重试。', 401)
        token, days = ctx.auth.create(ip, request.headers.get('User-Agent', ''), request.form.get('remember') == 'on', user)
        r = redirect(base + '/')
        r.set_cookie(cookie, token, max_age=days * 86400, secure=s.get('site.cookie_secure'), httponly=True, samesite='Strict', path='/')
        return r

    @bp.route('/logout', methods=['POST'])
    def logout():
        ctx.auth.revoke(token=request.cookies.get(cookie, ''))
        r = jsonify(ok=True)
        r.delete_cookie(cookie, secure=s.get('site.cookie_secure'), httponly=True, samesite='Strict', path='/')
        return r

    @bp.route('/')
    def index():
        if not (APP_DIST / 'index.html').exists():
            return 'Frontend bundle missing; run the web build.', 503
        return send_from_directory(APP_DIST, 'index.html')

    @bp.route('/assets/<path:name>')
    def assets(name):
        return _static_file(APP_DIST / 'assets', name, immutable=True)

    @bp.route('/static/<path:name>')
    def static_file(name):
        return _static_file(STATIC, name)

    # -- live --------------------------------------------------------------------------------
    @bp.route('/api/overview')
    def overview():
        totals = ctx.store.totals()
        frame = ctx.frame()
        topo = ctx.topology.describe()
        return jsonify(
            version=ctx.version, title=s.get('site.title'), timezone=s.get('site.timezone'), base=base,
            csrf=request.joysol_session['csrf'], user=request.joysol_session['user'] or s.secrets['username'], totals=totals, health=_health(ctx),
            gate={'enabled': s.gate_enabled, 'origin_verified': _origin_verified(s)},
            live={k: frame[k] for k in ('up', 'down', 'active', 'online_ips')},
            topology={'inbounds': topo['inbounds'], 'outbounds': topo['outbounds'], 'final': topo['final']},
            alerts=len([a for a in ctx.alerts.for_engine(ctx.alerts.open_alerts(), 'singbox') if not a['acked']]),
            alerts_xray=len([a for a in xray_dashboard.alerts_for_xray(ctx, ctx.alerts.open_alerts()) if not a['acked']]),
            features={'probes': ctx.singbox_enabled and bool(s.get('probes.enabled')), 'stream': ctx.singbox_enabled,
                      'bans': ctx.bans_enabled, 'xray_bans': ctx.xray_bans, 'management': bool(s.get('management.enabled', False)),
                      'client_rules': bool(s.get('management.enabled', False) and request.joysol_session['user'] == s.secrets['username'])}, xray=ctx.xray.snapshot(detail=False),
            primary_engine='xray' if ctx.xray.instances else 'singbox', singbox_enabled=ctx.singbox_enabled,
        )

    @bp.route('/api/xray')
    def xray_stats():
        return jsonify(xray_dashboard.present(ctx))

    @bp.route('/api/xray/details')
    def xray_details():
        span = request.args.get('range', '24h')
        span = span if span in ('24h', '7d', '30d') else '24h'
        return jsonify(xray_dashboard.details(ctx, span))

    @bp.route('/api/xray/network')
    def xray_network():
        return jsonify(engine='xray', interfaces=ctx.nic.interfaces(), current=ctx.nic.current(), live=ctx.nic.series_live(300),
                       scope='网卡收发为整台服务器，包含 Xray、其他服务和协议开销。Xray 载荷只取原生入站计数，不使用 sing-box 流量。')

    @bp.route('/api/xray/probes/run', methods=['POST'])
    def xray_probe():
        if not ctx.xray.instances:
            return error('未配置 Xray', 400)
        started = ctx.xray.probe_async()
        ctx.store.record('xray-probe', client_ip(), 'started' if started else 'already-running')
        return jsonify(ok=True, started=started)

    @bp.route('/api/live')
    def live():
        seconds = as_int('seconds', 300, 10, int(s.get('live.history_seconds')))
        return jsonify(frame=ctx.frame(), series=ctx.live.series(seconds))

    @bp.route('/api/stream')
    def stream():
        q = ctx.hub.subscribe()
        if q is None:
            return error('实时连接数已达上限', 503)

        def events():
            try:
                yield 'retry: 3000\n\n'
                yield 'event: frame\ndata: %s\n\n' % json.dumps(ctx.frame(), separators=(',', ':'))
                idle = 0
                while True:
                    try:
                        data = q.get(timeout=15)
                        idle = 0
                        yield 'event: frame\ndata: %s\n\n' % data
                    except queue.Empty:
                        idle += 1
                        yield ': keepalive\n\n'
                        if idle > 40:
                            return
            finally:
                ctx.hub.unsubscribe(q)
        r = Response(stream_with_context(events()), mimetype='text/event-stream')
        r.headers['X-Accel-Buffering'] = 'no'
        r.headers['Cache-Control'] = 'private, no-store, no-transform'
        return r

    @bp.route('/api/connections')
    def connections():
        rows = ctx.live.connections()
        ip = request.args.get('ip', '')
        if ip:
            rows = [r for r in rows if r['ip'] == ip]
        for r in rows:
            r['rule_label'] = rule_label(r.get('rule'))
        return jsonify(rows=rows, total=len(rows))

    @bp.route('/api/connections/close', methods=['POST'])
    def close_connection():
        body = request.get_json(silent=True) or {}
        cid = str(body.get('id', ''))[:80]
        if not cid:
            return error('缺少连接 ID', 400)
        ok = ctx.collector.close(cid) if ctx.collector else False
        ctx.store.record('close-connection', '', cid[:16])
        return jsonify(ok=ok)

    # -- ledgers -----------------------------------------------------------------------------
    @bp.route('/api/ips')
    def ips():
        frame = ctx.frame()
        bans = {b['ip']: b for b in ctx.bans.list()}
        rows = ctx.store.ip_totals()
        known = {r['ip'] for r in rows}
        for target in bans:
            if target not in known and '/' not in target:
                rows.append({'ip': target, 'connections': 0, 'upload': 0, 'download': 0, 'first_seen': 0, 'last_seen': 0})
        for r in rows:
            live_ip = frame['ips'].get(r['ip'], {})
            r.update(ctx.geo.brief(r['ip']))
            r.update(online=live_ip.get('online', 0), ru=round(live_ip.get('ru', 0)), rd=round(live_ip.get('rd', 0)),
                     total=r['upload'] + r['download'], banned=ctx.bans.is_banned(r['ip']),
                     ban_reason=bans.get(r['ip'], {}).get('reason', ''))
        return jsonify(rows=rows, total=len(rows))

    @bp.route('/api/history')
    def history():
        online = {}
        for conn in ctx.live.connections():
            key = (conn['ip'], conn['domain'], conn['protocol'], conn['inbound'])
            online[key] = online.get(key, 0) + 1
        result = ctx.store.history(
            ip=request.args.get('ip', ''), q=request.args.get('q', '')[:100], since=request.args.get('since', 'all'),
            sort=request.args.get('sort', 'last_seen'), direction=request.args.get('dir', 'desc'),
            limit=as_int('limit', 100, 1, 2000), offset=as_int('offset', 0), online=online)
        if s.get('management.enabled', False) and request.joysol_session['user'] == s.secrets['username']:
            from . import client_rules
            try:
                policy = client_rules.load(s.get('management.subscription_dir', str(s.data_dir / 'subscriptions')))
                for row in result['rows']:
                    row['client_rule_target'] = client_rules.candidate(row['domain'])
                    matched = client_rules.match_target(policy, row['domain'])
                    row['client_rule'] = ({k: matched[k] for k in ('id', 'action', 'type', 'target')} if matched else None)
            except (OSError, ValueError):
                result['client_rules_error'] = '客户端规则无法读取，请在代理规则页检查'
        return jsonify(result)

    @bp.route('/api/daily')
    def daily():
        result = ctx.store.daily(as_int('days', 30, 1, 400), request.args.get('ip', ''))
        for r in result['rows']:
            r.update(ctx.geo.brief(r['ip']))
        return jsonify(result)

    @bp.route('/api/series')
    def series():
        span = request.args.get('range', '24h')
        by = request.args.get('by', '')
        return jsonify(ctx.store.series(span if span in RANGES else '24h', by, request.args.get('ip', '')))

    @bp.route('/api/top')
    def top():
        by = request.args.get('by', 'domain')
        rows = ctx.store.top(request.args.get('range', '24h'), by, as_int('limit', 10, 1, 100), request.args.get('ip', ''),
                            request.args.get('outbound', '')[:80])
        for r in rows:
            if by == 'ip':
                r.update(ctx.geo.brief(r['k']))
            if by == 'rule':
                r['label'] = rule_label(r['k'])
        return jsonify(rows=rows)

    @bp.route('/api/topology')
    def topology():
        span = request.args.get('range', '24h')
        topo = ctx.topology.describe()
        flows = ctx.store.flows(span if span in RANGES else '24h')
        for f in flows:
            f['rule_label'] = rule_label(f.get('rule'))
            f['inbound_tag'] = f['inbound'].split('/')[-1]
        probes = ctx.prober.latest()
        server = probes.get('direct') or next((p for p in probes.values() if p['outbound'] in
                                               [o['tag'] for o in topo['outbounds'] if o['type'] == 'direct']), None)
        ips = {f['ip'] for f in flows}
        clients = {ip: ctx.geo.lookup(ip) for ip in ips}
        return jsonify(range=span, topology=topo, flows=flows, probes=probes, server=server,
                       clients={ip: _geo_public(g) for ip, g in clients.items()},
                       entry_host=s.public_host)

    @bp.route('/api/map')
    def geo_map():
        span = request.args.get('range', '7d')
        volume = ctx.store.bytes_by_ip(span if span in RANGES else None)
        frame = ctx.frame()
        points = []
        for ip, total in volume.items():
            g = ctx.geo.lookup(ip)
            if g['lat'] is None:
                continue
            points.append({'ip': ip, 'bytes': total, 'online': frame['ips'].get(ip, {}).get('online', 0), **_geo_public(g)})
        probes = ctx.prober.latest()
        return jsonify(range=span, clients=points, probes=probes, outbounds=ctx.topology.describe()['outbounds'])

    # -- management --------------------------------------------------------------------------
    @bp.route('/api/bans')
    def bans_list():
        rows = ctx.bans.list()
        for r in rows:
            r.update(ctx.geo.brief(r['ip'].split('/')[0]))
        return jsonify(rows=rows)

    @bp.route('/api/ban', methods=['POST'])
    def ban():
        body = request.get_json(silent=True) or {}
        action = body.get('action')
        reason = str(body.get('reason', ''))[:160]
        if action not in ('ban', 'unban'):
            return error('无效操作', 400)
        try:
            if action == 'ban':
                target, expires = ctx.bans.ban(body.get('ip', ''), reason, int(body.get('duration') or 0), client_ip())
                ids = ctx.live.ids_for(ctx.bans.matches(target))
                ctx.close_connections(ids)
                return jsonify(ok=True, target=target, expires=expires, closed=len(ids))
            target = str(body.get('ip', '')).strip()
            # Only entries already in the ban list reach the firewall.
            if target not in {b['ip'] for b in ctx.bans.list()}:
                target = canonical(target, 0, 0)
                if target not in {b['ip'] for b in ctx.bans.list()}:
                    return error('该地址不在封禁名单中', 404)
            ctx.bans.unban(target, client_ip())
            return jsonify(ok=True, target=target, closed=0)
        except ValueError as exc:
            return error(str(exc) if str(exc) else '请输入公网 IPv4 / IPv6 地址或网段', 400)
        except Exception:
            return error('封禁执行失败，请检查服务日志', 503)

    @bp.route('/api/audit')
    def audit():
        return jsonify(ctx.store.audit(as_int('limit', 100, 1, 500), as_int('offset', 0), request.args.get('action', '')[:40]))

    @bp.route('/api/sessions')
    def sessions():
        return jsonify(rows=ctx.auth.sessions(request.joysol_session['token_hash']))

    @bp.route('/api/sessions/revoke', methods=['POST'])
    def revoke():
        body = request.get_json(silent=True) or {}
        target = str(body.get('id', ''))[:16]
        if not target:
            return error('缺少会话', 400)
        ctx.auth.revoke(session_id='*' if body.get('all') else target, keep=request.joysol_session['token_hash'])
        ctx.store.record('revoke-session', client_ip(), 'all-others' if body.get('all') else target)
        return jsonify(ok=True)

    @bp.route('/api/alerts')
    def alerts():
        opened, recent = ctx.alerts.open_alerts(), ctx.alerts.recent(100)
        engine = request.args.get('engine')
        if engine not in (None, 'xray', 'singbox'):
            return error('未知监控来源', 400)
        opened, recent = ctx.alerts.for_engine(opened, engine), ctx.alerts.for_engine(recent, engine)
        return jsonify(open=opened, recent=recent, reachability=ctx.reachability.snapshot())

    @bp.route('/api/alerts/ack', methods=['POST'])
    def alerts_ack():
        body = request.get_json(silent=True) or {}
        engine = body.get('engine')
        if engine not in (None, 'xray', 'singbox'):
            return error('未知监控来源', 400)
        try:
            ok = ctx.alerts.ack(body.get('id'), engine)
        except (ValueError, TypeError):
            return error('告警编号无效', 400)
        if not ok:
            return error('当前监控来源中未找到该告警', 404)
        return jsonify(ok=True)

    @bp.route('/api/probes')
    def probes():
        return jsonify(latest=ctx.prober.latest(), history=ctx.prober.history(as_int('hours', 24, 1, 720)),
                       changes={o['tag']: ctx.prober.exit_changes(o['tag']) for o in ctx.topology.describe()['outbounds'] if o['probe']},
                       interval=s.get('probes.interval_seconds'), enabled=bool(s.get('probes.enabled')), running=ctx.prober.running,
                       error=ctx.prober.error)

    @bp.route('/api/probes/run', methods=['POST'])
    def probes_run():
        if ctx.prober.running:
            return jsonify(ok=False, running=True)
        results = ctx.prober.run()
        ctx.store.record('probe', client_ip(), '%d results' % len(results))
        return jsonify(ok=True, latest=ctx.prober.latest())

    @bp.route('/api/network')
    def network():
        span = request.args.get('range', '24h')
        span = span if span in RANGES and RANGES[span] <= 2592000 else '24h'
        seconds = RANGES[span]
        q = ctx.netq
        since = int(ctx.store.meta('nic_since', '0') or 0)
        # Ratios only make sense over the period both counters cover.
        today_from = max(ctx.store.day_start(), since)
        range_from = max(int(time.time()) - seconds, since)
        keys = q.quality_keys(seconds)
        for row in keys:
            if row['segment'] == 'client':
                row.update(ctx.geo.brief(row['key']))
            elif row['segment'] == 'upstream':
                row['label'] = ctx.topology.label('outbound', row['key'])
        return jsonify(
            range=span, interfaces=ctx.nic.interfaces(), current=ctx.nic.current(), live=ctx.nic.series_live(300),
            traffic=q.traffic(seconds), since=since,
            totals={'today': {**q.totals(today_from), 'from': today_from}, 'range': {**q.totals(range_from), 'from': range_from}},
            quality={'latest': ctx.quality.latest, 'series': q.quality_series(seconds), 'keys': keys,
                     'enabled': bool(s.get('network.quality_enabled')), 'interval': s.get('network.quality_interval_seconds'),
                     'edge_ports': s.get('network.edge_ports') or [], 'public_ports': ctx.topology.public_ports()})

    @bp.route('/api/system')
    def system_status():
        cert = system.certificate(ctx.cert_path())
        return jsonify(
            version=ctx.version, uptime=system.uptime(), started=int(ctx.health['started']),
            services=system.services(list(dict.fromkeys(list(s.get('alerts.services') or []) + [i['service'] for i in ctx.xray.instances]))),
            certificate=cert, disk=system.disk(str(s.data_dir)), database={'bytes': ctx.store.size(), 'migrations': ctx.store.migrations},
            singbox={'version': system.singbox_version(s.get('singbox.binary')), 'config': s.get('singbox.config_path'),
                     'api': s.get('singbox.api_address'), 'error': ctx.topology.error},
            geo=ctx.geo.info(), health=_health(ctx), streams=ctx.hub.count(),
            firewall={'chain': s.get('firewall.chain'), 'ports': sorted({port for _, port in ctx.public_endpoints()}),
                      'endpoints': [{'proto': proto, 'port': port} for proto, port in ctx.public_endpoints()],
                      'enabled': ctx.bans_enabled, 'xray': ctx.xray_bans},
            settings=s.public_view(), gate={'enabled': s.gate_enabled}, xray=ctx.xray.snapshot(detail=False),
            xray_runtimes=system.xray_runtimes(ctx.xray.instances))

    @bp.route('/api/prefs', methods=['GET', 'PUT'])
    def prefs():
        if request.method == 'GET':
            return jsonify(prefs=ctx.store.prefs(), effective={k: s.get(k) for k in sorted(_editable())})
        body = request.get_json(silent=True) or {}
        changes = {}
        for key, value in body.items():
            if key not in _editable():
                return error('不可修改的设置：' + key, 400)
            problem = _validate_pref(key, value)
            if problem:
                return error(problem, 400)
            changes[key] = value
        ctx.update_prefs(changes)
        ctx.store.record('prefs', client_ip(), ','.join(sorted(changes)))
        return jsonify(ok=True, prefs=ctx.store.prefs())

    @bp.route('/api/geo/<address>')
    def geo_lookup(address):
        try:
            ip = str(ipaddress.ip_address(address))
        except ValueError:
            return error('无效 IP', 400)
        return jsonify(ctx.geo.lookup(ip))

    @bp.route('/api/export/<kind>.csv')
    def export(kind):
        if kind == 'ips':
            data = ips().get_json()['rows']
            cols = ['ip', 'location', 'isp', 'asn', 'connections', 'upload', 'download', 'total', 'first_seen', 'last_seen', 'banned']
        elif kind == 'history':
            data = ctx.store.history(ip=request.args.get('ip', ''), q=request.args.get('q', '')[:100],
                                     since=request.args.get('since', 'all'), limit=2000)['rows']
            cols = ['ip', 'domain', 'protocol', 'inbound', 'outbounds', 'connections', 'upload', 'download', 'total', 'first_seen', 'last_seen']
        elif kind == 'daily':
            data = daily().get_json()['rows']
            cols = ['day', 'ip', 'location', 'isp', 'upload', 'download']
        elif kind == 'audit':
            data = ctx.store.audit(500, 0)['rows']
            cols = ['at', 'action', 'ip', 'detail']
        else:
            return error('未知导出类型', 404)
        out = io.StringIO()
        writer = csv.writer(out)
        writer.writerow(cols)
        for row in data:
            writer.writerow([_csv_cell(row.get(c, '')) for c in cols])
        r = make_response('﻿' + out.getvalue())
        r.headers['Content-Type'] = 'text/csv; charset=utf-8'
        r.headers['Content-Disposition'] = 'attachment; filename="joysol-%s-%s.csv"' % (kind, time.strftime('%Y%m%d-%H%M'))
        return r

    # -- compatibility -----------------------------------------------------------------------
    @bp.route('/api/data')
    def legacy_data():
        """v1 response shape for maintenance scripts."""
        rows = ips().get_json()['rows']
        hist = ctx.store.history(since=request.args.get('since', 'all'), ip=request.args.get('ip', ''), limit=2000)['rows']
        for h in hist:
            h['outbound'] = h.pop('outbounds', '')
        d = ctx.store.daily(30)
        return jsonify(esa_gate_enabled=s.gate_enabled, esa_origin_verified=_origin_verified(s), ips=rows, history=hist,
                       daily=d['days'], daily_ips=d['rows'], bans=ctx.bans.list(), health=_health(ctx),
                       tracking_since=ctx.store.totals()['tracking_since'], csrf=request.joysol_session['csrf'], history_limit=2000)

    from .management import register as register_management
    register_management(bp, ctx)
    app.register_blueprint(bp)

    @app.route(base)
    def bare():
        return redirect(base + '/')


def _editable():
    from .settings import EDITABLE
    return EDITABLE


def _validate_pref(key, value):
    if key in ('labels.inbounds', 'labels.outbounds', 'labels.xray'):
        if not isinstance(value, dict) or not all(isinstance(k, str) and isinstance(v, str) and len(v) <= 40 for k, v in value.items()):
            return '名称需为不超过 40 字的文本'
    elif key == 'entries':
        if not isinstance(value, dict) or not all(v in ('cdn', 'direct') for v in value.values()):
            return '入口类型只能是 cdn 或 direct'
    elif key in ('probes.enabled', 'network.quality_enabled', 'reachability.enabled'):
        if not isinstance(value, bool):
            return '需为开关值'
    else:
        if not isinstance(value, (int, float)) or isinstance(value, bool) or value < 0:
            return '需为非负数字'
        if key == 'probes.interval_seconds' and value < 60:
            return '探测间隔至少 60 秒'
        if key == 'network.quality_interval_seconds' and not 30 <= value <= 3600:
            return '采样间隔需在 30 到 3600 秒之间'
        if key == 'reachability.interval_seconds' and not 600 <= value <= 86400:
            return '公开大陆检测间隔需在 600 到 86400 秒之间'
        if key in ('reachability.failures', 'alerts.probe_failures') and (int(value) != value or not 0 <= value <= 100 or key == 'reachability.failures' and value == 0):
            return '连续失败轮数需为整数，国内检测 1–100，出口探测 0–100（0 关闭）'
    return ''


def _origin_verified(s):
    header = s.get('gate.origin_header')
    secret = s.secrets.get('origin_guard', '')
    return bool(secret) and hmac.compare_digest(request.headers.get(header, ''), secret)


def _health(ctx):
    h = ctx.health
    return {'connected': h['connected'], 'last_event': h['last_event'], 'last_error': h['last_error'], 'enabled': ctx.singbox_enabled}


def _geo_public(g):
    return {k: g[k] for k in ('location', 'isp', 'asn', 'lat', 'lon', 'country_code', 'precision', 'source')}


def _csv_cell(value):
    text = '' if value is None else str(value)
    # Spreadsheet formula injection guard.
    if text[:1] in ('=', '+', '-', '@', '\t', '\r'):
        text = "'" + text
    return text


def _escape(text):
    return str(text).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;')


def _static_file(folder, name, immutable=False):
    accepts = 'gzip' in request.headers.get('Accept-Encoding', '')
    target = (folder / name).resolve()
    if not str(target).startswith(str(folder.resolve()) + '/') or not target.is_file():
        return '', 404
    gz = target.with_name(target.name + '.gz')
    if accepts and gz.is_file():
        r = send_from_directory(folder, name + '.gz')
        r.headers['Content-Encoding'] = 'gzip'
        r.headers['Vary'] = 'Accept-Encoding'
        mimetype = {'.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml'}.get(target.suffix)
        if mimetype:
            r.headers['Content-Type'] = mimetype + ('; charset=utf-8' if target.suffix != '.svg' else '')
        r.headers.pop('Content-Disposition', None)
    else:
        r = send_from_directory(folder, name)
    r.headers['Cache-Control'] = 'private, max-age=31536000, immutable' if immutable else 'private, max-age=300'
    return r
