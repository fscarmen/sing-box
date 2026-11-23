#!/usr/bin/env python3
"""Reconcile only this installer's ACCEPT rules; keep SSH, bans and other rules."""
import argparse
import json
import shutil
import subprocess
from pathlib import Path

COMMENT = 'sb-dashboard-xray'


def run(args, required=True):
    result = subprocess.run(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
    if required and result.returncode:
        raise RuntimeError('Xray firewall operation failed')
    return result.returncode == 0


def reconcile(config, state, remove=False):
    # This helper deliberately supports the managed TCP Reality protocol only.
    ports = set() if remove else {int(i['port']) for i in json.loads(Path(config).read_text()).get('inbounds', [])
                                 if i.get('protocol') == 'vless'}
    if any(not 100 <= p <= 65535 for p in ports):
        raise ValueError('Invalid Xray firewall port')
    state = Path(state)
    previous = set(json.loads(state.read_text())) if state.exists() else set()
    ufw = shutil.which('ufw')
    firewalld = shutil.which('firewall-cmd')
    if ufw and run([ufw, 'status'], False):
        result = subprocess.run([ufw, 'status'], capture_output=True, text=True, timeout=10)
        ufw = ufw if 'Status: active' in result.stdout else None
    if ufw:
        for port in sorted(ports):
            run([ufw, 'allow', str(port) + '/tcp', 'comment', COMMENT])
        # UFW rules may be shared with an operator rule; do not delete by port.
    elif firewalld and run([firewalld, '--state'], False):
        for port in sorted(ports):
            for permanence in ([], ['--permanent']):
                run([firewalld] + permanence + ['--add-rich-rule=rule family="ipv4" port port="%d" protocol="tcp" accept' % port])
                run([firewalld] + permanence + ['--add-rich-rule=rule family="ipv6" port port="%d" protocol="tcp" accept' % port])
        # Retain shared firewalld allows; this never flushes an operator's rules.
    else:
        for binary in ('iptables', 'ip6tables'):
            executable = shutil.which(binary)
            if not executable or not run([executable, '-w', '5', '-L', 'INPUT'], False):
                if binary == 'iptables':
                    raise RuntimeError('IPv4 firewall unavailable')
                continue
            for port in sorted(ports):
                rule = ['INPUT', '-p', 'tcp', '--dport', str(port), '-m', 'comment', '--comment', COMMENT, '-j', 'ACCEPT']
                if not run([executable, '-w', '5', '-C'] + rule, False):
                    # Keep the configured panel ban chain ahead of this allow,
                    # while placing it before common terminal DROP rules.
                    settings = Path('/etc/sb-dashboard/settings.json')
                    chain = (json.loads(settings.read_text()).get('firewall', {}).get('chain', 'JOYSOL_NODE_BANS')
                             if settings.exists() else 'JOYSOL_NODE_BANS')
                    listing = subprocess.run([executable, '-w', '5', '-S', 'INPUT'], capture_output=True, text=True, check=True, timeout=10)
                    rules = [line for line in listing.stdout.splitlines() if line.startswith('-A INPUT ')]
                    position = 1 + max((index + 1 for index, line in enumerate(rules) if ('-j ' + chain) in line), default=0)
                    run([executable, '-w', '5', '-I', 'INPUT', str(position)] + rule[1:])
            for port in sorted(previous - ports):
                rule = ['INPUT', '-p', 'tcp', '--dport', str(port), '-m', 'comment', '--comment', COMMENT, '-j', 'ACCEPT']
                while run([executable, '-w', '5', '-C'] + rule, False):
                    run([executable, '-w', '5', '-D'] + rule)
    state.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    state.write_text(json.dumps(sorted(ports)))
    state.chmod(0o600)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', default='/usr/local/etc/xray/config.json')
    parser.add_argument('--state', default='/var/lib/sb-manager/xray-firewall.json')
    parser.add_argument('--remove', action='store_true')
    args = parser.parse_args()
    reconcile(args.config, args.state, args.remove)
