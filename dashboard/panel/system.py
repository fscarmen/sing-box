"""Host status for the system page and alerts: services, certificate, disk, versions."""
import os
import re
import shutil
import subprocess
import time
from datetime import datetime, timezone

_cache = {}


def _cached(key, ttl, fn):
    hit = _cache.get(key)
    if hit and time.time() - hit[0] < ttl:
        return hit[1]
    value = fn()
    _cache[key] = (time.time(), value)
    return value


def _run(args, timeout=5):
    try:
        out = subprocess.run(args, capture_output=True, timeout=timeout)
        return out.returncode, out.stdout.decode(errors='replace').strip()
    except (OSError, subprocess.SubprocessError):
        return -1, ''


def services(names):
    def check():
        result = {}
        for name in names:
            code, out = _run(['systemctl', 'is-active', name])
            result[name] = out or ('unknown' if code < 0 else 'inactive')
        return result
    return _cached('services:' + ','.join(names), 15, check)


def certificate(path):
    def check():
        if not path or not os.path.exists(path):
            return {'path': path, 'found': False}
        code, out = _run(['openssl', 'x509', '-enddate', '-noout', '-in', path])
        if code != 0 or '=' not in out:
            return {'path': path, 'found': True, 'error': '无法读取证书'}
        text = out.split('=', 1)[1].strip()
        try:
            expires = datetime.strptime(text, '%b %d %H:%M:%S %Y %Z').replace(tzinfo=timezone.utc)
        except ValueError:
            return {'path': path, 'found': True, 'error': text}
        return {'path': path, 'found': True, 'expires': int(expires.timestamp()),
                'days_left': round((expires.timestamp() - time.time()) / 86400, 1)}
    return _cached('cert:' + str(path), 600, check)


def disk(path):
    usage = shutil.disk_usage(path)
    return {'total': usage.total, 'used': usage.used, 'free': usage.free, 'percent': round(usage.used * 100 / usage.total, 1)}


def singbox_version(binary):
    def check():
        code, out = _run([binary, 'version'])
        return out.splitlines()[0] if code == 0 and out else ''
    return _cached('singbox-version', 3600, check)


def uptime():
    try:
        with open('/proc/uptime') as handle:
            return int(float(handle.read().split()[0]))
    except (OSError, ValueError):
        return 0


def xray_runtimes(instances):
    def inspect():
        rows = []
        for instance in instances:
            code, pid = _run(['systemctl', 'show', '--value', '-p', 'MainPID', instance['service']])
            version = ''
            if code == 0 and pid.isdigit() and int(pid) > 0:
                try:
                    binary = os.readlink('/proc/' + pid + '/exe')
                except OSError:
                    status, command = _run(['systemctl', 'show', '--value', '-p', 'ExecStart', instance['service']])
                    match = re.search(r'\bpath=([^ ;]+)', command) if status == 0 else None
                    binary = match.group(1) if match else ''
                if binary:
                    status, text = _run([binary, 'version'])
                    if status == 0 and text.startswith('Xray '):
                        version = text.splitlines()[0]
            rows.append({'id': instance['id'], 'label': instance.get('label', instance['id']), 'service': instance['service'],
                         'version': version, 'config': instance['config_path'], 'api': instance['api_address']})
        return rows
    return _cached('xray-runtimes:' + ','.join(i['service'] + ':' + i['config_path'] for i in instances), 30, inspect)
