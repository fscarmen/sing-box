#!/usr/bin/env python3
"""Fetch the pinned official Xray test core, verify SHA256, do not install a service."""
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import urllib.request
import zipfile

VERSION = '26.10.21'
arch = {'x86_64': '64', 'aarch64': 'arm64-v8a'}.get(platform.machine())
if platform.system() != 'Linux' or not arch:
    raise SystemExit('This optional native test download supports Linux amd64/arm64')
headers = {'User-Agent': 'sing-box-dashboard-fixed-tests'}
if os.environ.get('GITHUB_TOKEN'):
    headers['Authorization'] = 'Bearer ' + os.environ['GITHUB_TOKEN']
request = urllib.request.Request('https://api.github.com/repos/XTLS/Xray-core/releases/tags/v' + VERSION, headers=headers)
with urllib.request.urlopen(request, timeout=30) as response:
    release = json.load(response)
name = 'Xray-linux-' + arch + '.zip'
asset = next(a for a in release['assets'] if a['name'] == name)
url = 'https://github.com/XTLS/Xray-core/releases/download/v' + VERSION + '/' + name
if asset.get('browser_download_url') != url or not asset.get('digest', '').startswith('sha256:'):
    raise SystemExit('Release does not provide a verifiable official asset')
with urllib.request.urlopen(url, timeout=120) as response:
    archive = response.read(128 * 1024 * 1024 + 1)
if len(archive) > 128 * 1024 * 1024 or 'sha256:' + hashlib.sha256(archive).hexdigest() != asset['digest']:
    raise SystemExit('Official Xray SHA256 mismatch')
destination = Path(__file__).resolve().parents[1] / 'outputs' / 'xray-v26.10.21'
destination.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(io.BytesIO(archive)) as source:
    info = source.getinfo('xray')
    if info.file_size > 128 * 1024 * 1024:
        raise SystemExit('Test binary is too large')
    destination.write_bytes(source.read(info))
destination.chmod(0o755)
print('Verified optional Xray test binary: outputs/xray-v' + VERSION)
