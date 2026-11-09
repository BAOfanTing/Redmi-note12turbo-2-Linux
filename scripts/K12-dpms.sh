#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }
WL='XDG_RUNTIME_DIR=/run/marble-dashboard/xdg WAYLAND_DISPLAY=wayland-0'

echo "===== 确保 kiosk 在跑 ====="
R 'systemctl start marble-dashboard-kiosk'
sleep 8
echo "  kiosk: $(systemctl is-active marble-dashboard-kiosk)"
R 'ls -l /run/marble-dashboard/xdg/'

echo
echo "===== 列出输出 ====="
R "$WL wlr-randr 2>&1 | head -25"

OUT=$(R "$WL wlr-randr 2>/dev/null | head -1 | awk '{print \$1}'")
echo "  输出名 = ${OUT:-未取到}"

if [ -z "$OUT" ]; then echo "  取不到输出名，退出"; exit 1; fi

echo
echo "===== DPMS off ====="
R "$WL wlr-randr --output $OUT --off 2>&1 | head -3"
sleep 2
echo "  --- 采样 8 秒 ---"
i=0
while [ $i -lt 16 ]; do
    printf '    %s brightness=%s\n' "$(date +%H:%M:%S)" "$(cat /sys/class/backlight/ae94000.dsi.0/brightness)"
    sleep 0.5
    i=$((i+1))
done

echo
echo "===== 再列一次输出（看 Enabled 是否变 no）====="
R "$WL wlr-randr 2>&1 | head -12"

echo
echo "===== DPMS on 恢复 ====="
R "$WL wlr-randr --output $OUT --on 2>&1 | head -3"
sleep 2
echo -n "  brightness: "; cat /sys/class/backlight/ae94000.dsi.0/brightness
R "$WL wlr-randr 2>&1 | head -6"
