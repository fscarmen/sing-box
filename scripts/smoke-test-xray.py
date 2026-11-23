#!/usr/bin/env python3
"""Xray deployment E2E; only run in an explicitly disposable Docker container."""
import http.cookiejar
import json
import os
import ssl
import time
import urllib.request
import urllib.error
from pathlib import Path
from urllib.parse import urlencode, urlsplit

if os.environ.get('SB_SMOKE_DISPOSABLE') != 'yes' or not Path('/.dockerenv').exists():
    raise SystemExit('Only for disposable Docker with SB_SMOKE_DISPOSABLE=yes')
origin = os.environ.get('SB_SMOKE_ORIGIN', 'https://127.0.0.1:18443')
context = ssl.create_default_context(cafile='/etc/sb-dashboard/tls.crt')
jar = http.cookiejar.CookieJar()
client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar), urllib.request.HTTPSHandler(context=context))
password = Path('/root/sb-dashboard-login.txt').read_text().split('密码：', 1)[1].strip()
client.open(urllib.request.Request(origin + '/monitor/login', data=urlencode({'username': 'admin', 'password': password}).encode(), headers={'Origin': origin})).read()


def get(path, engine=None):
    suffix = '?engine=' + engine if engine else ''
    for attempt in range(40):
        try:
            return json.load(client.open(origin + '/monitor/api/' + path + suffix, timeout=20))
        except urllib.error.HTTPError:
            raise
        except (urllib.error.URLError, ConnectionError):
            if attempt == 39: raise
            time.sleep(.5)


csrf = get('overview')['csrf']


def task(op, payload=None, engine='xray'):
    request = urllib.request.Request(origin + '/monitor/api/manage/' + op,
        data=json.dumps({**(payload or {}), 'engine': engine}).encode(),
        headers={'Content-Type': 'application/json', 'Origin': origin, 'X-CSRF-Token': csrf})
    job_id = json.load(client.open(request, timeout=20))['job']['id']
    for _ in range(300):
        job = next(j for j in get('manage/status', engine)['jobs'] if j['id'] == job_id)
        if job['state'] not in ('queued', 'running'):
            assert job['state'] == 'succeeded', {key: job.get(key) for key in ('engine', 'operation', 'state', 'error')}
            return job
        time.sleep(1)
    raise AssertionError('Xray task timed out')


def body(url, gateway=False, agent='Clash.Meta'):
    base = 'http://127.0.0.1:8308' if gateway else origin
    request = urllib.request.Request(base + urlsplit(url).path, headers={'User-Agent': agent})
    return client.open(request, timeout=20).read().decode()


assert not Path('/etc/sing-box/sing-box').exists(), 'fresh Xray test expects no sing-box'
state = get('manage/status', 'xray'); assert state['installed'] and state['service'] == 'active'
assert len(state['inbounds']) == 1
sub = get('manage/subscriptions', 'xray'); links = sub['links']
assert body(links['auto']) == sub['files']['clash2']
assert body(links['auto'], gateway=True) == sub['files']['clash2']
assert body(links['auto'], gateway=True, agent='Shadowrocket') == sub['files']['shadowrocket']
assert 'privateKey' not in json.dumps(sub)
print('Fresh non-root Xray, HTTPS login, core-specific subscriptions and loopback gateway: OK', flush=True)

pid = Path('/run/sb-smoke/xray.service.pid').read_text()
task('subscription', {'origin': 'https://sub.example.test'})
fixed = get('manage/subscriptions', 'xray')['links']
assert urlsplit(fixed['auto']).path == urlsplit(links['auto']).path
task('export')
assert get('manage/subscriptions', 'xray')['links'] == fixed
assert Path('/run/sb-smoke/xray.service.pid').read_text() == pid
config = get('manage/config', 'xray'); doc = json.loads(config['files']['config.json'])
original_port = doc['inbounds'][0]['port']
doc['inbounds'][0]['port'] = 10443
reality = doc['inbounds'][0]['streamSettings']['realitySettings']
reality['target'] = 'www.apple.com:443'; reality['serverNames'] = ['www.apple.com']
config['files']['config.json'] = json.dumps(doc)
job = task('apply', config)
assert any(i['port'] == 10443 for i in get('manage/status', 'xray')['inbounds'])
assert '10443' in body(fixed['auto'], gateway=True)
task('restore', {'backup': job['backup']})
assert any(i['port'] == original_port for i in get('manage/status', 'xray')['inbounds'])
assert get('manage/subscriptions', 'xray')['links'] == fixed
print('Fixed origin, stable tokens, port/SNI edit, config restore: OK', flush=True)

task('stop'); assert get('manage/status', 'xray')['service'] == 'inactive'
assert get('overview')['features']['management']
task('start'); task('upgrade', {'version': '26.10.21'})
assert get('manage/status', 'xray')['service'] == 'active'
assert get('manage/subscriptions', 'xray')['links'] == fixed
for _ in range(40):
    monitor = get('xray')
    if monitor.get('instances') and all(i.get('connected') for i in monitor['instances']): break
    time.sleep(.5)
assert get('overview')['primary_engine'] == 'xray'
assert any(i.get('connected') for i in get('xray')['instances']), get('xray')['instances']
print('Stop/start, verified native upgrade and Xray telemetry: OK', flush=True)

if os.environ.get('SB_SMOKE_DUAL') == 'yes':
    xray_pid = Path('/run/sb-smoke/xray.service.pid').read_text()
    task('install', {'server': '127.0.0.1', 'name': 'singbox', 'start_port': 11443, 'protocols': ['b', 'c']}, engine='singbox')
    assert get('manage/status', 'singbox')['installed']
    assert get('manage/status', 'xray')['service'] == 'active'
    assert Path('/run/sb-smoke/xray.service.pid').read_text() == xray_pid
    single = get('manage/subscriptions', 'singbox')
    assert single['links']['auto'] != fixed['auto']
    assert body(single['links']['auto'], gateway=True) == single['files']['clash2']
    assert body(fixed['auto'], gateway=True) == get('manage/subscriptions', 'xray')['files']['clash2']
    for _ in range(40):
        overview = get('overview')
        if overview['singbox_enabled'] and overview['health']['connected']: break
        time.sleep(.5)
    assert overview['singbox_enabled'] and overview['health']['connected']
    print('Both real cores coexist; independent subscriptions and live monitoring: OK', flush=True)
