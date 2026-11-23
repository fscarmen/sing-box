"""Public mainland HTTPS vantage points. Never submit subscription tokens or bodies."""
import copy
import json
import re
import threading
import time
import urllib.error
import urllib.request

API = 'https://api.globalping.io/v1'
ISPS = {'telecom': ('电信', 4134), 'unicom': ('联通', 4837), 'mobile': ('移动', 9808)}
# Only explicitly safe public resources may be sent to a public measurement archive.
SAFE_PATHS = {'/', '/monitor/login', '/favicon.ico'}


class ProviderError(Exception):
    """Only status/type metadata leaves an API error, never its body or submitted target."""
    def __init__(self, code, error_type='', retry_after=0):
        self.code = int(code)
        self.retry_after = min(3600, max(0, int(retry_after)))
        self.error_type = error_type if isinstance(error_type, str) and re.fullmatch(r'[a-zA-Z0-9_.:-]{1,80}', error_type or '') else ''
        reason = {400: '请求未被接受', 404: '测量任务暂不可用', 422: '探测点暂缺或请求不可调度',
                  429: '请求受限', 500: '平台内部错误', 502: '平台网关错误', 503: '平台暂不可用', 504: '平台网关超时'}.get(self.code, '响应异常')
        super().__init__('Globalping HTTP %d（%s）%s' % (self.code, reason, ' · ' + self.error_type if self.error_type else ''))


def public_target(target):
    host = target.get('host', '')
    path = target.get('path', '/')
    if not re.fullmatch(r'(?=.{1,253}$)[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?', host) or '.' not in host:
        raise ValueError('Public DNS hostname required')
    if path not in SAFE_PATHS:
        raise ValueError('Only a token-free public health path may be shared')
    return host, path


def api(path, payload=None):
    body = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(API + path, body, {'Content-Type': 'application/json', 'User-Agent': 'vps-dashboard/2.5.2'})
    # No inherited proxy, cookies, credentials, or arbitrary API destination.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(request, timeout=15) as response:
            raw = response.read(2_000_001)
    except urllib.error.HTTPError as exc:
        try:
            data = json.loads(exc.read(8192))
            error_type = data.get('error', {}).get('type', '')
        except (ValueError, AttributeError):
            error_type = ''
        retry = exc.headers.get('Retry-After', '') if exc.headers else ''
        raise ProviderError(exc.code, error_type, int(retry) if str(retry).isdigit() else 0) from None
    if len(raw) > 2_000_000:
        raise ValueError('Measurement response too large')
    return json.loads(raw)


def classify(data, asn, city=''):
    matches = [r for r in data.get('results', []) if r.get('probe', {}).get('country') == 'CN'
               and str(r.get('probe', {}).get('asn')) == str(asn)]
    if not matches:
        return {'ok': None, 'error': '该运营商大陆节点暂不可用'}
    row = matches[0]
    result, probe = row.get('result', {}), row['probe']
    if city and str(probe.get('city', '')).casefold() != city.casefold():
        return {'ok': None, 'error': '故障城市未获得匹配探测点', 'stage': 'probe'}
    status = result.get('status')
    if status not in ('finished', 'failed'):
        return {'ok': None, 'error': '公开探测节点离线或未完成'}
    code = result.get('statusCode')
    # A received 403/404 proves transport reachability but not a working endpoint.
    # TLS must be trusted and the exact safe endpoint must return 2xx.
    ok = status == 'finished' and isinstance(code, int) and 200 <= code < 300 and (result.get('tls') or {}).get('authorized') is True
    reason, stage = 'DNS、连接、TLS 或请求失败', 'request'
    raw = str(result.get('rawOutput', '')).lower().rsplit('error:', 1)[-1]
    if status == 'failed' and ('dns' in raw or 'resol' in raw):
        reason, stage = 'DNS 解析超时或失败', 'dns'
    elif status == 'failed' and ('tls' in raw or 'ssl' in raw or 'certificate' in raw):
        reason, stage = 'TLS 握手超时或证书失败', 'tls'
    elif status == 'failed' and ('download' in raw or 'response' in raw):
        reason, stage = '响应下载超时或中断', 'download'
    elif isinstance(code, int):
        reason = 'HTTP %d' % code
        stage = 'http'
        if 200 <= code < 300 and (result.get('tls') or {}).get('authorized') is not True:
            reason, stage = 'TLS 证书未通过校验', 'tls'
        elif status == 'failed':
            reason, stage = '已收到 HTTP %d，但请求未完整完成' % code, 'download'
    elif 'resolve' in raw:
        reason, stage = 'DNS 解析失败', 'dns'
    elif 'timed out' in raw or 'timeout' in raw:
        reason, stage = '连接或请求超时', 'timeout'
    elif 'certificate' in raw or 'ssl' in raw:
        reason = 'TLS 连接或证书校验失败'
    elif 'connect' in raw:
        reason, stage = '连接失败', 'tcp'
    return {'ok': ok, 'http_status': code, 'city': str(probe.get('city', ''))[:60], 'asn': asn, 'stage': '' if ok else stage,
            'total_ms': result.get('timings', {}).get('total'),
            'error': '' if ok else reason}


class Reachability:
    def __init__(self, settings, store, stop):
        self.settings, self.store, self.stop = settings, store, stop
        self.lock = threading.RLock()
        self.running = False
        try:
            self.state = json.loads(store.meta('mainland_https', '{}'))
        except (ValueError, TypeError):
            self.state = {}

    def snapshot(self):
        with self.lock:
            result = copy.deepcopy(self.state)
            result.update(enabled=bool(self.settings.get('reachability.enabled')), running=self.running,
                          interval=self.settings.get('reachability.interval_seconds'),
                          failures=self.settings.get('reachability.failures'),
                          resolver=self.settings.get('reachability.resolver'),
                          fallback_resolver=self.settings.get('reachability.fallback_resolver'),
                          scope='公开大陆节点检测入口 HTTPS；不提交订阅令牌，不代表完整订阅下载或代理协议握手。',
                          provider='Globalping', subscription_configured=False)
            return result

    def start_if_due(self):
        with self.lock:
            interval = max(600, int(self.settings.get('reachability.interval_seconds')))
            changed = self.state.get('resolvers') != self._resolvers()
            if not self.settings.get('reachability.enabled') or not self.settings.get('reachability.targets') or self.running or time.time() < self.state.get('retry_at', 0) or (not changed and time.time() - self.state.get('at', 0) < interval):
                return False
            self.running = True
        threading.Thread(target=self.run, name='mainland-https', daemon=True).start()
        return True

    def _resolvers(self):
        return [self.settings.get('reachability.resolver'), self.settings.get('reachability.fallback_resolver')]

    def commit(self, rows, provider_error='', retry_after=0):
        now = int(time.time())
        with self.lock:
            old = self.state
            previous = {r['key']: r for r in old.get('rows', [])}
            threshold = max(1, int(self.settings.get('reachability.failures')))
            interval = max(600, int(self.settings.get('reachability.interval_seconds')))
            for row in rows:
                before = previous.get(row['key'], {})
                failed_city = before.get('failed_city') or (before.get('city', '') if before.get('alarm') or before.get('failures') else '')
                if failed_city and row['ok'] is True and row.get('city', '').casefold() != failed_city.casefold():
                    row.update(ok=None, error='其他城市通过，上次故障城市尚未确认恢复', stage='probe')
                same_city = not before.get('city') or not row.get('city') or before['city'].casefold() == row['city'].casefold()
                contiguous = now - old.get('at', 0) <= interval * 3 and same_city
                row['failures'] = (before.get('failures', 0) if contiguous else 0) + 1 if row['ok'] is False else 0
                row['alarm'] = (row['failures'] >= threshold or before.get('alarm', False)) if row['ok'] is not True else False
                row['failed_city'] = '' if row['ok'] is True else failed_city or (row.get('city', '') if row['ok'] is False else '')
                row['at'] = now
            provider_error = provider_error or ('大陆运营商节点缺失、离线或未完成' if any(r['ok'] is None for r in rows) else '')
            errors = old.get('provider_failures', 0) + 1 if provider_error else 0
            self.state = {'at': now, 'rows': rows, 'provider_error': provider_error, 'provider_failures': errors,
                          'resolvers': self._resolvers(),
                          'retry_at': now + min(3600, max(0, int(retry_after)))}
            with self.store.write() as c:
                c.execute('INSERT OR REPLACE INTO meta VALUES(?,?)', ('mainland_https', json.dumps(self.state)))

    def _create(self, host, path, asn, city, resolver, previous=''):
        location = {'magic': previous, 'limit': 1} if previous else {'country': 'CN', 'asn': asn, 'limit': 1}
        if city and not previous:
            location['city'] = city
        created = api('/measurements', {'type': 'http', 'target': host, 'locations': [location],
            'measurementOptions': {'protocol': 'HTTPS', 'ipVersion': 4, 'resolver': resolver,
                                   'request': {'method': 'GET', 'path': path}}})
        mid = created.get('id', '')
        if not re.fullmatch(r'[a-zA-Z0-9_-]{1,100}', mid):
            raise ValueError('Invalid measurement ID')
        return mid

    def _read(self, mid, asn, city):
        for _ in range(16):
            if self.stop.wait(2):
                return None
            data = api('/measurements/' + mid)
            if data.get('status') != 'in-progress':
                return classify(data, asn, city)
        return {'ok': None, 'error': '公开检测任务未完成', 'stage': 'provider'}

    def run(self):
        rows, errors, retry_after = [], [], 0
        previous = {r['key']: r for r in self.snapshot().get('rows', [])}
        resolver = self.settings.get('reachability.resolver')
        fallback = self.settings.get('reachability.fallback_resolver')
        try:
            for target in self.settings.get('reachability.targets') or []:
                host, path = public_target(target)
                jobs = {}
                for isp, (label, asn) in ISPS.items():
                    key = target['id'] + ':' + isp
                    old = previous.get(key, {})
                    city = old.get('failed_city') or (old.get('city', '') if old.get('alarm') or old.get('failures') else '')
                    base = {'key': key, 'target': target['id'], 'label': target['label'], 'isp': label, 'city': city, 'resolver': resolver}
                    try:
                        mid = self._create(host, path, asn, city, resolver)
                        jobs[key] = (base, asn, mid, city)
                    except Exception as exc:
                        reason = str(exc) if isinstance(exc, ProviderError) else type(exc).__name__
                        errors.append(reason); retry_after = max(retry_after, getattr(exc, 'retry_after', 0))
                        rows.append({**base, 'ok': None, 'error': reason, 'stage': 'provider'})
                for key, (base, asn, mid, city) in jobs.items():
                    try:
                        result = self._read(mid, asn, city)
                        if result is None:
                            return
                        # Confirm a DNS failure once on the same public probe, without changing target or TLS rules.
                        if result.get('stage') == 'dns' and fallback and fallback != resolver:
                            fallback_city = result.get('city') or city
                            next_id = self._create(host, path, asn, fallback_city, fallback, previous=mid)
                            retried = self._read(next_id, asn, fallback_city)
                            if retried is None:
                                return
                            result = {**retried, 'dns_fallback_used': True, 'initial_error': result['error']}
                            base['resolver'] = fallback
                        rows.append({**base, **result})
                    except Exception as exc:
                        reason = str(exc) if isinstance(exc, ProviderError) else type(exc).__name__
                        errors.append(reason); retry_after = max(retry_after, getattr(exc, 'retry_after', 0))
                        rows.append({**base, 'ok': None, 'error': reason, 'stage': 'provider'})
            self.commit(rows, '；'.join(dict.fromkeys(errors)), retry_after)
        except Exception as exc:
            known = {r['key'] for r in rows}
            rows.extend(dict(r, ok=None, error='检测服务异常，状态未知') for key, r in previous.items() if key not in known)
            self.commit(rows, str(exc) if isinstance(exc, ProviderError) else type(exc).__name__)
        finally:
            with self.lock:
                self.running = False
