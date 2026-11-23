#!/usr/bin/env python3
"""Local recovery commands. Does not start the panel or collect traffic."""
import argparse
import hashlib
import json
import os
import secrets
import sqlite3
from pathlib import Path

from manager import atomic


def reset_password(config_dir, login_path):
    root = Path(config_dir)
    path = root / 'config.json'
    stat = path.stat()
    config = json.loads(path.read_text())
    password, salt = secrets.token_urlsafe(24), secrets.token_hex(16)
    config.update(salt=salt, password_hash=hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(salt), 600000).hex())
    atomic(path, json.dumps(config), stat.st_mode & 0o777)
    os.chown(path, stat.st_uid, stat.st_gid)
    settings = json.loads((root / 'settings.json').read_text())
    db = Path(settings['paths']['data_dir']) / 'stats.sqlite3'
    if db.exists():
        with sqlite3.connect(db, timeout=15) as conn:
            for table in ('sessions', 'failures'):
                if conn.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (table,)).fetchone():
                    conn.execute('DELETE FROM ' + table)
    atomic(login_path, '账号：' + config['username'] + '\n密码：' + password + '\n')


def main():
    parser = argparse.ArgumentParser(description='本机管理员恢复工具；保留节点、流量历史与订阅密钥')
    parser.add_argument('operation', choices=['reset-password'])
    parser.add_argument('--config-dir', default='/etc/sb-dashboard')
    args = parser.parse_args()
    if os.geteuid() != 0:
        raise SystemExit('请使用 sudo 或 root 执行')
    reset_password(args.config_dir, '/root/sb-dashboard-login.txt')
    import subprocess
    subprocess.run(['systemctl', 'restart', 'sb-dashboard'], check=True)
    print('管理员密码已重置，旧会话已撤销。使用 sudo cat /root/sb-dashboard-login.txt 查看新密码。')


if __name__ == '__main__':
    main()
