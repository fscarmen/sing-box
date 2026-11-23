#!/usr/bin/env python3
"""End-to-end checks ONLY inside an explicitly disposable installer test container."""
import http.cookiejar
import json
import os
import ssl
import subprocess
import time
import urllib.request
from pathlib import Path
from urllib.parse import urlencode, urlsplit

if os.environ.get('SB_SMOKE_DISPOSABLE') != 'yes' or not Path('/.dockerenv').exists():
    raise SystemExit('Only run inside a disposable Docker container with SB_SMOKE_DISPOSABLE=yes')

origin = os.environ.get('SB_SMOKE_ORIGIN', 'https://127.0.0.1:18443')
jar = http.cookiejar.CookieJar()
context = ssl.create_default_context(cafile='/etc/sb-dashboard/tls.crt')
client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar), urllib.request.HTTPSHandler(context=context))


def get(name):
    return json.load(client.open(origin + '/monitor/api/' + name, timeout=20))


def login():
    jar.clear()
    password = Path('/root/sb-dashboard-login.txt').read_text().split('密码：', 1)[1].strip()
    for _ in range(40):
        try:
            client.open(urllib.request.Request(origin + '/monitor/login', data=urlencode({'username': 'admin', 'password': password}).encode(), headers={'Origin': origin})).read()
            return get('overview')['csrf']
        except OSError:
            time.sleep(.5)
    raise AssertionError('login unavailable')


csrf = login()


def task(operation, data=None):
    request = urllib.request.Request(origin + '/monitor/api/manage/' + operation, data=json.dumps(data or {}).encode(),
                                     headers={'Content-Type': 'application/json', 'Origin': origin, 'X-CSRF-Token': csrf})
    job_id = json.load(client.open(request, timeout=20))['job']['id']
    for _ in range(180):
        job = next(j for j in get('manage/status')['jobs'] if j['id'] == job_id)
        if job['state'] not in ('queued', 'running'):
            assert job['state'] == 'succeeded', {k: job.get(k) for k in ('operation', 'state', 'error')}
            return job
        time.sleep(1)
    raise AssertionError('task timeout')


def download(url, agent='Clash.Meta', gateway=False):
    if gateway:
        url = 'http://127.0.0.1:8308' + urlsplit(url).path
    elif urlsplit(url).netloc != urlsplit(origin).netloc:
        # A saved fixed domain is verified through this disposable server's HTTPS
        # listener; DNS/Cloudflare authorization are outside this local smoke test.
        url = origin + urlsplit(url).path
    request = urllib.request.Request(url, headers={'User-Agent': agent})
    with client.open(request, timeout=20) as response:
        assert response.status == 200
        return response.read().decode()


assert get('manage/status')['installed']
assert len(get('manage/status')['inbounds']) == 2
subs = get('manage/subscriptions')
auto = subs['links']['auto']
assert 'proxies:' in download(auto)
assert download(auto) == subs['files']['clash2']
assert download(auto, 'Shadowrocket') == subs['files']['shadowrocket']
assert download(auto, gateway=True) == subs['files']['clash2']
assert download(auto, 'Shadowrocket', gateway=True) == subs['files']['shadowrocket']
assert json.loads(download(subs['links']['sing-box']))['outbounds']
print('HTTPS login, independent token downloads and loopback gateway: OK', flush=True)

pid = Path('/run/sb-smoke/sing-box.pid').read_text()
task('subscription', {'origin': 'https://sub.example.test'})
new_subs = get('manage/subscriptions')
assert urlsplit(new_subs['links']['auto']).path == urlsplit(auto).path
assert new_subs['origin'] == 'https://sub.example.test'
assert Path('/run/sb-smoke/sing-box.pid').read_text() == pid
assert 'https://sub.example.test/sub/' in new_subs['files']['clash']
task('export')
subs = get('manage/subscriptions')
assert subs['links'] == new_subs['links']
assert download(subs['links']['auto'], gateway=True) == subs['files']['clash2']
print('Fixed origin, unchanged node process and stable token after shell export: OK', flush=True)

config = get('manage/config')
name = next(n for n in config['files'] if 'xtls-reality_inbounds' in n)
config['files'][name] = config['files'][name].replace('"listen_port":443', '"listen_port":14443')
job = task('apply', config)
assert any(i['port'] == 14443 for i in get('manage/status')['inbounds'])
assert '14443' in download(subs['links']['proxies'], gateway=True)
task('restore', {'backup': job['backup']})
assert any(i['port'] == 443 for i in get('manage/status')['inbounds'])
assert get('manage/subscriptions')['links'] == subs['links']
print('Live port edit, export synchronization and backup restore: OK', flush=True)

core_pid = Path('/run/sb-smoke/sing-box.pid').read_text()
config = json.loads(Path('/etc/sb-dashboard/config.json').read_text())
subprocess.run(['sb-dashboard-admin', 'reset-password'], check=True, stdout=subprocess.DEVNULL)
csrf = login()
assert json.loads(Path('/etc/sb-dashboard/config.json').read_text())['api_secret'] == config['api_secret']
assert Path('/run/sb-smoke/sing-box.pid').read_text() == core_pid
assert get('manage/subscriptions')['links'] == subs['links']
print('Password recovery with unchanged API secret, subscriptions and core: OK', flush=True)

for _ in range(40):
    if get('overview')['health']['connected']:
        break
    time.sleep(.5)
assert get('overview')['health']['connected']
print('Authenticated native telemetry after recovery: OK', flush=True)
