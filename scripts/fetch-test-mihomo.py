#!/usr/bin/env python3
"""Download one verified official Mihomo test core; never install a service."""
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import re
import urllib.request

VERSION = '1.19.33'
arch = {'x86_64':'amd64-compatible','aarch64':'arm64'}.get(platform.machine())
if platform.system() != 'Linux' or not arch: raise SystemExit('Optional native test supports Linux amd64/arm64')
headers = {'User-Agent':'sing-box-dashboard-fixed-tests'}
if os.environ.get('GITHUB_TOKEN'): headers['Authorization']='Bearer '+os.environ['GITHUB_TOKEN']
req = urllib.request.Request('https://api.github.com/repos/MetaCubeX/mihomo/releases/tags/v'+VERSION,headers=headers)
with urllib.request.urlopen(req,timeout=30) as response:release=json.load(response)
name='mihomo-linux-'+arch+'-v'+VERSION+'.gz'
asset=next((a for a in release['assets'] if a['name']==name),{})
url='https://github.com/MetaCubeX/mihomo/releases/download/v'+VERSION+'/'+name
if asset.get('browser_download_url')!=url or not re.fullmatch(r'sha256:[0-9a-f]{64}',asset.get('digest','')):
    raise SystemExit('Official release asset cannot be verified')
limit=128*1024*1024
with urllib.request.urlopen(url,timeout=120) as response:archive=response.read(limit+1)
if len(archive)>limit or 'sha256:'+hashlib.sha256(archive).hexdigest()!=asset['digest']:
    raise SystemExit('Mihomo release SHA256 mismatch')
with gzip.GzipFile(fileobj=io.BytesIO(archive)) as source:binary=source.read(limit+1)
if not binary or len(binary)>limit:raise SystemExit('Invalid Mihomo test binary size')
destination=Path(__file__).resolve().parents[1]/'outputs'/('mihomo-v'+VERSION)
destination.parent.mkdir(exist_ok=True)
destination.write_bytes(binary);destination.chmod(0o755)
print('Verified optional Mihomo test binary: outputs/mihomo-v'+VERSION)
