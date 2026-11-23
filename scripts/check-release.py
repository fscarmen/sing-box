#!/usr/bin/env python3
"""Check publishable sources without reading ignored runtime files or credentials."""
import re
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
required = ('bootstrap.sh', 'sing-box.sh', 'dashboard/app.py', 'dashboard/manager.py',
            'dashboard/core_download.py', 'dashboard/admin.py', 'dashboard/subscription_server.py',
            'dashboard/panel/subscriptions.py', 'dashboard/static/app/index.html',
            'dashboard/panel/client_rules.py',
            'BOOTSTRAP.md', 'docs/FIXED-SUBSCRIPTION.md', 'LICENSE',
            'dashboard/xray_manager.py', 'dashboard/xray_download.py', 'dashboard/xray_firewall.py',
            'dashboard/vendor/xray-install/install-release.sh', 'dashboard/vendor/xray-install/LICENSE',
            'dashboard/vendor/xray-install/SOURCE.json')
errors = [name + ': missing' for name in required if not (ROOT / name).is_file()]
vendor = ROOT / 'dashboard/vendor/xray-install'
try:
    source = json.loads((vendor / 'SOURCE.json').read_text())
    if (not re.fullmatch(r'[0-9a-f]{40}', source['commit'])
            or source['repository'] != 'https://github.com/XTLS/Xray-install'
            or hashlib.sha256((vendor / 'install-release.sh').read_bytes()).hexdigest() != source['sha256']):
        errors.append('Vendored Xray installer pin/checksum mismatch')
except (OSError, ValueError, KeyError):
    errors.append('Vendored Xray installer source record missing or invalid')
paths = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT).decode().split('\0')
for name in filter(None, paths):
    p = ROOT / name
    if not p.is_file():
        continue
    if p.is_symlink() or any(part in ('private', 'node_modules', '.venv', '__pycache__') for part in p.parts):
        errors.append(name + ': private/development file')
        continue
    if p.suffix in ('.key', '.pem', '.sqlite3', '.db') or p.name.startswith('.env'):
        errors.append(name + ': runtime credential/database file')
        continue
    data = p.read_bytes()
    if re.search(rb'/(?:etc|opt|var/lib)/sb-[a-z-]+-jp\b', data):
        errors.append(name + ': deployment-specific path')
    if re.search(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', data):
        errors.append(name + ': private key material')
html = (ROOT / 'dashboard/static/app/index.html').read_text()
for ref in re.findall(r'(?:src|href)="([^"]+)"', html):
    if ref.startswith('./assets/') and not (ROOT / 'dashboard/static/app' / ref[2:]).is_file():
        errors.append('frontend asset missing: ' + ref)
if errors:
    raise SystemExit('\n'.join(sorted(set(errors))))
print('Publishable source and frontend checks passed; ignored runtime files were excluded.')
