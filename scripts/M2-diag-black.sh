#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 进程 ====="
for p in greetd phoc phosh gnome-session chromium; do
    n=$(R "pgrep -af '$p' 2>/dev/null | grep -v pgrep | wc -l")
    printf '  %-14s %s\n' "$p" "$n"
done

echo
echo "===== greetd 是否在重启循环 ====="
R 'systemctl show greetd -p NRestarts -p ActiveState -p SubState'

echo
echo "===== 会话 ====="
R 'loginctl list-sessions --no-legend 2>/dev/null'

echo
echo "===== 显示状态 ====="
echo -n "  brightness: "; cat /sys/class/backlight/ae94000.dsi.0/brightness
R 'env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 wlr-randr 2>/dev/null | head -8 || echo "  wlr-randr 连不上"'

echo
echo "===== phosh 日志（最近崩溃/错误）====="
R 'journalctl -b --no-pager 2>/dev/null | grep -iE "phosh.*(error|crash|fail)|gnome-session.*(fail|error)|phoc.*(error|fail)" | tail -10'

echo
echo "===== chromium 日志 ====="
R 'tail -15 /tmp/monitor.log 2>/dev/null'
