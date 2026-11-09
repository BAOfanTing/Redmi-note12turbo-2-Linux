#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== epiphany 安装状态 ====="
echo "  单元: $(systemctl is-active epiphany-install 2>/dev/null) / $(systemctl is-failed epiphany-install 2>/dev/null)"
R 'journalctl -u epiphany-install -n 4 --no-pager 2>/dev/null | tail -4'
echo -n "  epiphany 可执行: "; R 'command -v epiphany || echo 缺失'

echo
echo "===== 用 epiphany 打开面板（detach）====="
R 'pkill -f "epiphany" 2>/dev/null; sleep 1'
R 'setsid sudo -u marble env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/10000/bus /usr/local/bin/marble-monitor </dev/null >/tmp/monitor2.log 2>&1 &'
sleep 15

echo "  --- 进程 ---"
R 'pgrep -af "epiphany" 2>/dev/null | grep -v pgrep | cut -c1-90 | head -3'
echo "  --- 日志 ---"
R 'head -8 /tmp/monitor2.log 2>/dev/null'

echo
echo "===== phoc 有没有再报 Resource busy ====="
R 'journalctl --since "-40s" --no-pager 2>/dev/null | grep -c "Resource busy"'

echo
echo "===== 截图 ====="
R 'timeout 20 env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot-app2.png 2>&1; ls -l /tmp/shot-app2.png 2>/dev/null'
