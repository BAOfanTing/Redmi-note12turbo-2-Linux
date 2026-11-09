#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 最近 40 条 idle 日志 ====="
R 'journalctl -u marble-screen-idle -n 40 --no-pager | sed "s/.*marble-screen-idle.sh\[[0-9]*\]: //"'

echo
echo "===== 各类事件计数（最近 10 分钟）====="
echo -n "  电源键切换次数: "; R 'journalctl -u marble-screen-idle --since "-10min" --no-pager | grep -c "电源键 ->"'
echo -n "  输入唤醒次数  : "; R 'journalctl -u marble-screen-idle --since "-10min" --no-pager | grep -c "检测到输入"'
echo -n "  亮度被外部改  : "; R 'journalctl -u marble-screen-idle --since "-10min" --no-pager | grep -c "亮度被外部改"'

echo
echo "===== 最后一次触发唤醒的设备/键码 ====="
R 'cat /run/marble-dashboard/last-event 2>/dev/null || echo "(无记录)"'

echo
echo "===== 当前状态 ====="
R 'echo "act=$(cat /run/marble-dashboard/last-activity)"; echo "bat=$(cat /run/marble-dashboard/blanked-at)"; echo "now=$(date +%s)"; echo "flag=$(ls /run/marble-dashboard/blanked 2>/dev/null || echo none)"; echo "tap=$(cat /run/marble-dashboard/power-tap)"'
echo -n "  亮度: "; cat /sys/class/backlight/ae94000.dsi.0/brightness

echo
echo "===== 采样 6 秒亮度变化（每 0.5 秒）====="
i=0
while [ $i -lt 12 ]; do
    printf '  %s  brightness=%s  flag=%s\n' "$(date +%H:%M:%S)" \
        "$(cat /sys/class/backlight/ae94000.dsi.0/brightness 2>/dev/null)" \
        "$(ls /run/marble-dashboard/blanked 2>/dev/null >/dev/null && echo blanked || echo on)"
    sleep 0.5
    i=$((i+1))
done
