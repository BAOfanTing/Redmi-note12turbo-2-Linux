#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 1. 清理 + 重启图形会话 ====="
R 'systemctl stop marble-monitor-test.service 2>/dev/null; pkill -9 -f epiphany 2>/dev/null; pkill -9 -f chromium 2>/dev/null'
R 'systemctl restart greetd'
echo "  等待 30 秒..."
sleep 30
echo "  greetd: $(systemctl is-active greetd)"
echo "  phoc: $(R 'pgrep -af "usr/bin/phoc" 2>/dev/null | grep -v pgrep | wc -l') 个"
echo "  phosh: $(R 'pgrep -af "/usr/libexec/phosh" 2>/dev/null | grep -v pgrep | wc -l') 个"

echo
echo "===== 2. 截图（验证桌面恢复）====="
R 'timeout 25 env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot-base.png 2>&1; echo rc=$?'
R 'ls -l /tmp/shot-base.png 2>/dev/null'

echo
echo "===== 3. 启动面板窗口（epiphany --new-window）====="
R 'systemd-run --uid=10000 --setenv=XDG_RUNTIME_DIR=/run/user/10000 --setenv=WAYLAND_DISPLAY=wayland-0 --setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/10000/bus --unit=marble-monitor-app /usr/sbin/epiphany --new-window file:///run/marble-dashboard/index.html'
sleep 20
echo "  单元: $(systemctl is-active marble-monitor-app 2>/dev/null)"
R 'journalctl -u marble-monitor-app -n 6 --no-pager 2>/dev/null | tail -6'
R 'pgrep -af epiphany 2>/dev/null | grep -v pgrep | cut -c1-70 | head -2'

echo
echo "===== 4. 再截图 ====="
R 'timeout 25 env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot-panel.png 2>&1; echo rc=$?'
R 'ls -l /tmp/shot-panel.png 2>/dev/null'
