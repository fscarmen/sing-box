#!/usr/bin/env python3
"""Shared client routing E2E in an explicitly disposable installed Docker only."""
import hashlib
import http.cookiejar
import json
import os
from pathlib import Path
import ssl
import subprocess
import time
import urllib.error
import urllib.request
from urllib.parse import urlencode, urlsplit
import yaml

if os.environ.get('SB_SMOKE_DISPOSABLE') != 'yes' or not Path('/.dockerenv').exists():
    raise SystemExit('Only for disposable Docker with SB_SMOKE_DISPOSABLE=yes')
origin = os.environ.get('SB_SMOKE_ORIGIN', 'https://127.0.0.1:18443')
context = ssl.create_default_context(cafile='/etc/sb-dashboard/tls.crt')
jar = http.cookiejar.CookieJar()
client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar), urllib.request.HTTPSHandler(context=context))
password = Path('/root/sb-dashboard-login.txt').read_text().split('密码：', 1)[1].strip()
client.open(urllib.request.Request(origin + '/monitor/login', data=urlencode({'username':'admin','password':password}).encode(), headers={'Origin':origin})).read()

def get(path, engine=None):
    return json.load(client.open(origin + '/monitor/api/' + path + ('?engine=' + engine if engine else ''), timeout=30))
csrf = get('overview')['csrf']

def task(operation, payload=None, engine='singbox'):
    req = urllib.request.Request(origin + '/monitor/api/manage/' + operation, data=json.dumps({**(payload or {}),'engine':engine}).encode(),
        headers={'Origin':origin,'X-CSRF-Token':csrf,'Content-Type':'application/json'})
    job_id = json.load(client.open(req,timeout=30))['job']['id']
    for _ in range(180):
        job = next(j for j in get('manage/status')['jobs'] if j['id']==job_id)
        if job['state'] not in ('queued','running'):
            assert job['state']=='succeeded', {k:job.get(k) for k in ('operation','state','error')}
            return job
        time.sleep(.5)
    raise AssertionError('rules job timed out')

def public(url, agent='Clash.Meta', gateway=True):
    base = 'http://127.0.0.1:8308' if gateway else origin
    req = urllib.request.Request(base + urlsplit(url).path, headers={'User-Agent':agent})
    with urllib.request.urlopen(req,context=context,timeout=30) as response:
        return response.read().decode(), response.headers['X-Client-Rules-Revision']

cores = ('singbox','xray')
for engine in cores: assert get('manage/status',engine)['service']=='active'
links = {engine:get('manage/subscriptions',engine)['links'] for engine in cores}
pids = {name:subprocess.check_output(['systemctl','show','--value','-p','MainPID',name+'.service']).decode().strip() for name in ('xray','sing-box')}
configs = {name:hashlib.sha256(Path(name).read_bytes()).hexdigest() for name in ('/usr/local/etc/xray/config.json', '/etc/sing-box/conf/09_dashboard_api.json')}
original = get('manage/rules')
policy = {'default_action':'inherit','rules':[
    {'id':'smoke-direct','type':'domain','target':'api.client-rule.example','action':'direct','enabled':True,'note':'disposable E2E'},
    {'id':'smoke-proxy','type':'domain_suffix','target':'proxy-rule.example','action':'proxy','enabled':True},
    {'id':'smoke-reject','type':'ip_cidr','target':'2001:db8::/32','action':'reject','enabled':True}]}
task('rules-save',{'policy':policy,'revision':original['revision']})
current = get('manage/rules'); assert current['policy']['rules'][0]['target']=='api.client-rule.example'
for engine in cores:
    assert get('manage/subscriptions',engine)['links']==links[engine]
    body, revision = public(links[engine]['auto'])
    assert yaml.safe_load(body)['rules'][0]=='DOMAIN,api.client-rule.example,DIRECT'
    assert revision==current['revision']
    https_body, _ = public(links[engine]['auto'],gateway=False)
    assert body==https_body
    node_only, _ = public(links[engine]['auto'],agent='Shadowrocket')
    assert node_only==get('manage/subscriptions',engine)['files']['shadowrocket']
    shadow, _ = public(links[engine]['shadowrocket.conf'])
    assert '[Rule]' in shadow and 'DOMAIN,api.client-rule.example,DIRECT' in shadow
    single, _ = public(links[engine]['sing-box'])
    parsed = json.loads(single)
    assert any(r.get('domain')==['api.client-rule.example'] and r.get('action')=='route' for r in parsed['route']['rules'])
    file = Path('/tmp/smoke-client-rules-'+engine+'.json');file.write_text(single);file.chmod(0o600)
    check = subprocess.run(['/etc/sing-box/sing-box','check','-c',str(file)],capture_output=True,timeout=30)
    assert check.returncode==0, check.stderr.decode()
assert all(subprocess.check_output(['systemctl','show','--value','-p','MainPID',name+'.service']).decode().strip()==pid for name,pid in pids.items())
assert all(hashlib.sha256(Path(name).read_bytes()).hexdigest()==digest for name,digest in configs.items())
print('HTTPS/admin publication, both unchanged tokens, both gateway formats and unchanged VPS routes/PIDs: OK',flush=True)
for engine in cores: task('export',engine=engine)
assert get('manage/rules')['revision']==current['revision']
for engine in cores:
    assert get('manage/subscriptions',engine)['links']==links[engine]
    assert yaml.safe_load(public(links[engine]['auto'])[0])['rules'][0]=='DOMAIN,api.client-rule.example,DIRECT'
print('Shared rules persist through both actual exporters; native sing-box client configs validate: OK',flush=True)
task('rules-save',{'policy':original['policy'],'revision':current['revision']})
assert get('manage/rules')['revision']==original['revision']
print('Restoring previous rule policy restores original client routing: OK',flush=True)
