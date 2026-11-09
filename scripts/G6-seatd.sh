#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
S() { echo "$PW" | sudo -S "$@" 2>/dev/null; }

echo "===== 1. 安装并启�?seatd ====="
S apk add --no-cache seatd 2>&1 | tail -3
S systemctl enable --now seatd
sleep 2
echo "  seatd: $(systemctl is-active seatd) / $(systemctl is-enabled seatd)"
ls -l /run/seatd.sock 2>/dev/null

echo
echo "===== 2. 重启 kiosk ====="
S systemctl daemon-reload
S systemctl restart marble-dashboard-kiosk
sleep 10

echo "  kiosk: $(systemctl is-active marble-dashboard-kiosk)"

echo
echo "===== 3. kiosk 日志 ====="
S journalctl -u marble-dashboard-kiosk -n 20 --no-pager 2>/dev/null | tail -18

echo
echo "===== 4. 进程 ====="
ps w 2>/dev/null | grep -E 'chromium|cage' | grep -v grep | cut -c1-110 | head -8
