#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 清理旧实例 ====="
R 'pkill -f epiphany 2>/dev/null; systemctl reset-failed marble-monitor-test.service 2>/dev/null; sleep 1'
echo "  epiphany 进程: $(R 'pgrep -af epiphany 2>/dev/null | grep -v pgrep | wc -l')"

echo
echo "===== 用 systemd-run 以 marble(uid 10000) 身份启动 App ====="
R 'systemd-run --uid=10000 --setenv=XDG_RUNTIME_DIR=/run/user/10000 --setenv=WAYLAND_DISPLAY=wayland-0 --setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/10000/bus --unit=marble-monitor-test /usr/local/bin/marble-monitor'
sleep 18

echo "  单元: $(systemctl is-active marble-monitor-test 2>/dev/null)"
echo "  --- 进程 ---"
R 'pgrep -af epiphany 2>/dev/null | grep -v pgrep | cut -c1-90 | head -3'
echo "  --- 日志 ---"
R 'journalctl -u marble-monitor-test -n 8 --no-pager 2>/dev/null | tail -8'

echo
echo "===== phoc 是否报 Resource busy（近 40 秒）====="
R 'journalctl --since "-40s" --no-pager 2>/dev/null | grep -c "Resource busy"'

echo
echo "===== 截图 ====="
R 'timeout 20 env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot-app2.png 2>&1; ls -l /tmp/shot-app2.png 2>/dev/null'
