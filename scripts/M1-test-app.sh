#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 安装 App 启动器 ====="
R 'install -Dm755 /tmp/dashboard/marble-monitor /usr/local/bin/marble-monitor'
R 'grep -c ozone-platform /usr/local/bin/marble-monitor'

echo
echo "===== 清理旧的 chromium 实例 ====="
R 'pkill -f "app=file:///run/marble-dashboard" 2>/dev/null; sleep 1'

echo
echo "===== 在 phosh 会话里以 marble 身份启动（完全 detach，不占 SSH）====="
R 'setsid sudo -u marble env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/10000/bus /usr/local/bin/marble-monitor </dev/null >/tmp/monitor.log 2>&1 &'
sleep 12

echo "  --- 进程 ---"
R 'pgrep -af "ozone-platform=wayland" 2>/dev/null | cut -c1-95 | head -3'
echo "  --- 日志（前 10 行）---"
R 'head -10 /tmp/monitor.log 2>/dev/null'

echo
echo "===== 截图（加超时，防止卡住）====="
R 'timeout 20 env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot-app.png 2>&1; echo "rc=$?"'
R 'ls -l /tmp/shot-app.png 2>/dev/null || echo "  无截图"'
