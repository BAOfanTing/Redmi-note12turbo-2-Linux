#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 清理状态 ====="
R 'rm -f /run/marble-dashboard/blanked /run/marble-dashboard/blanked-at /run/marble-dashboard/last-event'
R 'systemctl restart marble-screen-idle'
sleep 2

echo "===== 用 BLANK_MODE=both 手动熄屏 ====="
R 'env BLANK_MODE=both /usr/local/bin/marble-screen.sh off'
sleep 2
echo "  kiosk: $(systemctl is-active marble-dashboard-kiosk)"
echo "  cage 进程数: $(pgrep -f '^/usr/sbin/cage' | wc -l)"
echo -n "  brightness: "; cat /sys/class/backlight/ae94000.dsi.0/brightness

echo
echo "===== 采样 10 秒，确认不再自己亮 ====="
i=0
while [ $i -lt 20 ]; do
    printf '  %s brightness=%-5s kiosk=%-10s cage=%s\n' "$(date +%H:%M:%S)" \
        "$(cat /sys/class/backlight/ae94000.dsi.0/brightness 2>/dev/null)" \
        "$(systemctl is-active marble-dashboard-kiosk 2>/dev/null)" \
        "$(pgrep -f '^/usr/sbin/cage' | wc -l)"
    sleep 0.5
    i=$((i+1))
done

echo
echo "===== 恢复亮屏 ====="
R 'env BLANK_MODE=both /usr/local/bin/marble-screen.sh on'
sleep 8
echo "  kiosk: $(systemctl is-active marble-dashboard-kiosk)"
echo "  cage 进程数: $(pgrep -f '^/usr/sbin/cage' | wc -l)"
echo -n "  brightness: "; cat /sys/class/backlight/ae94000.dsi.0/brightness
echo -n "  chromium 进程数: "; pgrep -c -f 'chromium' 2>/dev/null || echo 0
