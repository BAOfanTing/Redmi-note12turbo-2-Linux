#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
S() { echo "$PW" | sudo -S "$@" 2>/dev/null; }

echo "===== daemon-reload + 重启服务 ====="
S systemctl daemon-reload
S systemctl restart marble-dashboard-kiosk
S systemctl restart marble-screen-idle
sleep 8

echo
echo "===== 状�?====="
for u in marble-dashboard marble-dashboard-kiosk marble-screen-idle; do
    printf '  %-26s %s\n' "$u" "$(systemctl is-active $u 2>/dev/null)"
done

echo
echo "===== kiosk 日志 ====="
S journalctl -u marble-dashboard-kiosk -n 20 --no-pager 2>/dev/null | tail -20

echo
echo "===== idle 日志 ====="
S journalctl -u marble-screen-idle -n 12 --no-pager 2>/dev/null | tail -12

echo
echo "===== 进程 ====="
ps w 2>/dev/null | grep -E 'chromium|cage|marble-screen' | grep -v grep | cut -c1-120 | head -6
