#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 1. 尝试解锁会话 ====="
R 'loginctl unlock-sessions 2>&1; echo "rc=$?"'
R 'loginctl list-sessions --no-legend 2>/dev/null'
sleep 3

echo
echo "===== 2. 截图（看是否解锁 + 面板窗口）====="
R 'timeout 25 env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot-unlock.png 2>&1; echo rc=$?'
R 'ls -l /tmp/shot-unlock.png 2>/dev/null'

echo
echo "===== 3. epiphany 窗口状态 ====="
R 'pgrep -af epiphany 2>/dev/null | grep -v pgrep | cut -c1-80 | head -2'
R 'journalctl -u marble-monitor-app -n 4 --no-pager 2>/dev/null | tail -4'
