#!/usr/bin/env bash
# Re-establish this listener after reboot; never flush rules or change SSH.
set -euo pipefail
PORT=${1:?panel port required}
[[ "$PORT" =~ ^[0-9]+$ ]] && ((PORT >= 1024 && PORT <= 65535))
if command -v ufw >/dev/null && ufw status | head -1 | grep -q 'Status: active'; then
  ufw allow "$PORT/tcp" comment sb-dashboard
elif command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1; then
  firewall-cmd --permanent --add-port="$PORT/tcp"
  firewall-cmd --add-port="$PORT/tcp"
else
  iptables -w 5 -C INPUT -p tcp --dport "$PORT" -m comment --comment sb-dashboard -j ACCEPT 2>/dev/null || \
    iptables -w 5 -I INPUT 1 -p tcp --dport "$PORT" -m comment --comment sb-dashboard -j ACCEPT
  if ip6tables -w 5 -L INPUT >/dev/null 2>&1; then
    ip6tables -w 5 -C INPUT -p tcp --dport "$PORT" -m comment --comment sb-dashboard -j ACCEPT 2>/dev/null || \
      ip6tables -w 5 -I INPUT 1 -p tcp --dport "$PORT" -m comment --comment sb-dashboard -j ACCEPT
  fi
fi
