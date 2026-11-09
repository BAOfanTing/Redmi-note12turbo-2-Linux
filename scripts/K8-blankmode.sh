#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 把 BLANK_MODE 改成 both（停 cage + 写 brightness 0）====="
R 'mkdir -p /etc/systemd/system/marble-screen-idle.service.d'
R 'printf "[Service]\nEnvironment=IDLE_SEC=120\nEnvironment=BLANK_MODE=both\n" > /etc/systemd/system/marble-screen-idle.service.d/override.conf'
R 'cat /etc/systemd/system/marble-screen-idle.service.d/override.conf'

echo
echo "===== 重启 idle ====="
R 'systemctl daemon-reload'
R 'systemctl restart marble-screen-idle'
sleep 3
echo "  idle: $(systemctl is-active marble-screen-idle)"
echo "  kiosk: $(systemctl is-active marble-dashboard-kiosk)"

echo
echo "===== 手动验证一次熄屏（不用按电源键）====="
R '/usr/local/bin/marble-screen.sh off'
sleep 3
echo -n "  3 秒后 brightness = "; cat /sys/class/backlight/ae94000.dsi.0/brightness
echo -n "  kiosk 状态 = "; systemctl is-active marble-dashboard-kiosk

echo
echo "===== 采样 8 秒，看还会不会自己亮 ====="
i=0
while [ $i -lt 16 ]; do
    printf '  %s brightness=%s kiosk=%s\n' "$(date +%H:%M:%S)" \
        "$(cat /sys/class/backlight/ae94000.dsi.0/brightness 2>/dev/null)" \
        "$(systemctl is-active marble-dashboard-kiosk 2>/dev/null)"
    sleep 0.5
    i=$((i+1))
done

echo
echo "===== 恢复亮屏验证 ====="
R '/usr/local/bin/marble-screen.sh on'
sleep 6
echo -n "  brightness = "; cat /sys/class/backlight/ae94000.dsi.0/brightness
echo -n "  kiosk = "; systemctl is-active marble-dashboard-kiosk
echo -n "  cage 进程: "; pgrep -c -f '^/usr/sbin/cage' 2>/dev/null || echo 0

echo
echo "===== 日志 ====="
R 'journalctl -u marble-screen-idle -n 10 --no-pager | sed "s/.*marble-screen-idle.sh\[[0-9]*\]: //"'
