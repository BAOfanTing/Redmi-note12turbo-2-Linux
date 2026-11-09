#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 截屏 ====="
R 'XDG_RUNTIME_DIR=/run/marble-dashboard/xdg WAYLAND_DISPLAY=wayland-0 grim /tmp/shot.png; echo "rc=$?"'
R 'ls -l /tmp/shot.png; chmod 644 /tmp/shot.png'

echo
echo "===== 屏幕尺寸 / 分辨率确�?====="
R 'XDG_RUNTIME_DIR=/run/marble-dashboard/xdg WAYLAND_DISPLAY=wayland-0 grim -t png -s 1.0 /tmp/shot2.png; ls -l /tmp/shot2.png 2>/dev/null'

echo
echo "===== 当前亮度 ====="
cat /sys/class/backlight/ae94000.dsi.0/brightness 2>/dev/null
echo "  (max $(cat /sys/class/backlight/ae94000.dsi.0/max_brightness 2>/dev/null))"
