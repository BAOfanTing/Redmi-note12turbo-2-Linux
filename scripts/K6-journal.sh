#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== marble-screen-idle 最近 30 条 ====="
R 'journalctl -u marble-screen-idle -n 30 --no-pager'

echo
echo "===== 当前状态文件 ====="
R 'echo "now=$(date +%s)"; echo "act=$(cat /run/marble-dashboard/last-activity 2>/dev/null)"; echo "blanked_at=$(cat /run/marble-dashboard/blanked-at 2>/dev/null)"; echo "flag=$(ls /run/marble-dashboard/blanked 2>/dev/null || echo none)"; echo "tap=$(cat /run/marble-dashboard/power-tap)"'

echo
echo "===== 亮度当前值 ====="
cat /sys/class/backlight/ae94000.dsi.0/brightness

echo
echo "===== 有没有别的服务在改亮度 ====="
R 'systemctl list-units --type=service --state=running --no-legend | grep -iE "backlight|brightness|tuning"'
R 'grep -rl "brightness" /etc/systemd/system/ /usr/lib/systemd/system/ 2>/dev/null | head -5'
