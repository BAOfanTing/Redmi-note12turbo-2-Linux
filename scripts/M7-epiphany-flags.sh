#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 桌面是否正常（先截图）====="
R 'timeout 15 env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot-now.png 2>&1; ls -l /tmp/shot-now.png 2>/dev/null'

echo
echo "===== epiphany 参数 ====="
R 'epiphany --help 2>&1 | head -30'

echo
echo "===== 尝试 --new-window ====="
R 'systemctl reset-failed marble-monitor-test.service 2>/dev/null'
R 'systemd-run --uid=10000 --setenv=XDG_RUNTIME_DIR=/run/user/10000 --setenv=WAYLAND_DISPLAY=wayland-0 --setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/10000/bus --unit=marble-monitor-test /usr/sbin/epiphany --new-window file:///run/marble-dashboard/index.html'
sleep 15
echo "  单元: $(systemctl is-active marble-monitor-test 2>/dev/null)"
R 'journalctl -u marble-monitor-test -n 6 --no-pager 2>/dev/null | tail -6'
echo "  --- 进程 ---"
R 'pgrep -af epiphany 2>/dev/null | grep -v pgrep | cut -c1-80 | head -3'

echo
echo "===== 再截图 ====="
R 'timeout 15 env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot-app3.png 2>&1; ls -l /tmp/shot-app3.png 2>/dev/null'
