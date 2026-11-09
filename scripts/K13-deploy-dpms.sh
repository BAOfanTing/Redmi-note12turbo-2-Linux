#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 1. 装新版脚本 + 设 BLANK_MODE=dpms ====="
R 'install -Dm755 /tmp/dashboard/marble-screen.sh /usr/local/bin/marble-screen.sh'
R 'install -Dm755 /tmp/dashboard/marble-screen-idle.sh /usr/local/bin/marble-screen-idle.sh'
R 'mkdir -p /etc/systemd/system/marble-screen-idle.service.d'
R 'printf "[Service]\nEnvironment=IDLE_SEC=120\nEnvironment=BLANK_MODE=dpms\n" > /etc/systemd/system/marble-screen-idle.service.d/override.conf'
R 'systemctl daemon-reload'
R 'rm -f /run/marble-dashboard/blanked /run/marble-dashboard/blanked-at'
R 'systemctl restart marble-screen-idle'
R 'systemctl start marble-dashboard-kiosk'
sleep 8
echo "  kiosk: $(systemctl is-active marble-dashboard-kiosk)"
echo "  idle : $(systemctl is-active marble-screen-idle)"

echo
echo "===== 2. 手动熄屏（BLANK_MODE=dpms）====="
R 'env BLANK_MODE=dpms /usr/local/bin/marble-screen.sh off'
sleep 2
echo "  --- wlr-randr Enabled 应为 no ---"
R 'env XDG_RUNTIME_DIR=/run/marble-dashboard/xdg WAYLAND_DISPLAY=wayland-0 wlr-randr 2>/dev/null | head -6'
echo "  --- 采样 8 秒：brightness 不应再抖动（因为没有看护了）---"
i=0
while [ $i -lt 16 ]; do
    printf '    %s brightness=%s\n' "$(date +%H:%M:%S)" "$(cat /sys/class/backlight/ae94000.dsi.0/brightness)"
    sleep 0.5
    i=$((i+1))
done

echo
echo "===== 3. 亮屏 ====="
R 'env BLANK_MODE=dpms /usr/local/bin/marble-screen.sh on'
sleep 2
R 'env XDG_RUNTIME_DIR=/run/marble-dashboard/xdg WAYLAND_DISPLAY=wayland-0 wlr-randr 2>/dev/null | head -6'
echo "  --- 状态 ---"
R '/usr/local/bin/marble-screen.sh status'

echo
echo "===== 4. 日志 ====="
R 'journalctl -u marble-screen-idle -n 6 --no-pager | sed "s/.*marble-screen-idle.sh\[[0-9]*\]: //"'
