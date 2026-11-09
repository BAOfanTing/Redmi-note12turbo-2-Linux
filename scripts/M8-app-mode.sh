#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 杀掉 epiphany，检查 phoc ====="
R 'systemctl stop marble-monitor-test.service 2>/dev/null; pkill -f epiphany 2>/dev/null; sleep 2'
echo "  phoc 进程: $(R 'pgrep -af "usr/bin/phoc" 2>/dev/null | grep -v pgrep | wc -l')"
echo "  phoc 状态: $(R 'ps -o stat=,time= -p $(pgrep -f "usr/bin/phoc" | head -1) 2>/dev/null')"
echo "  greetd: $(systemctl is-active greetd)"
echo "  --- phoc 最近错误 ---"
R 'journalctl --since "-2min" --no-pager 2>/dev/null | grep -iE "phoc|Resource busy" | tail -6'

echo
echo "===== 尝试截图（30 秒超时）====="
R 'timeout 30 env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot-chk.png 2>&1; echo rc=$?; ls -l /tmp/shot-chk.png 2>/dev/null'

echo
echo "===== 用正确的 -a 参数启动 ====="
R 'systemctl reset-failed marble-monitor-test.service 2>/dev/null'
R 'systemd-run --uid=10000 --setenv=XDG_RUNTIME_DIR=/run/user/10000 --setenv=WAYLAND_DISPLAY=wayland-0 --setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/10000/bus --unit=marble-monitor-test /usr/sbin/epiphany -a file:///run/marble-dashboard/index.html'
sleep 15
echo "  单元: $(systemctl is-active marble-monitor-test 2>/dev/null)"
R 'journalctl -u marble-monitor-test -n 5 --no-pager 2>/dev/null | tail -5'
R 'pgrep -af "epiphany" 2>/dev/null | grep -v pgrep | cut -c1-80 | head -2'

echo
echo "===== 截图 ====="
R 'timeout 25 env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot-app4.png 2>&1; echo rc=$?; ls -l /tmp/shot-app4.png 2>/dev/null'
