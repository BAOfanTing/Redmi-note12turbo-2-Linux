#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 相关工具可用性 ====="
for p in wlr-randr libdrm-tests kscreen wlrctl; do
    r=$(R apk search -x "$p" 2>/dev/null | head -1)
    [ -n "$r" ] && echo "  有: $r" || echo "  无: $p"
done

echo
echo "===== 安装 wlr-randr ====="
R 'apk add --no-cache wlr-randr 2>&1 | tail -3'

echo
echo "===== 列出 Wayland 输出 ====="
R 'XDG_RUNTIME_DIR=/run/marble-dashboard/xdg WAYLAND_DISPLAY=wayland-0 wlr-randr 2>&1 | head -20'

echo
echo "===== 尝试 DPMS off ====="
OUT=$(R 'XDG_RUNTIME_DIR=/run/marble-dashboard/xdg WAYLAND_DISPLAY=wayland-0 wlr-randr 2>/dev/null | head -1 | awk "{print \$1}"')
echo "  输出名: ${OUT:-未取到}"
R "XDG_RUNTIME_DIR=/run/marble-dashboard/xdg WAYLAND_DISPLAY=wayland-0 wlr-randr --output $OUT --off 2>&1 | head -5"
sleep 2
echo -n "  brightness: "; cat /sys/class/backlight/ae94000.dsi.0/brightness
echo "  --- 采样 6 秒 ---"
i=0
while [ $i -lt 12 ]; do
    printf '    %s brightness=%s\n' "$(date +%H:%M:%S)" "$(cat /sys/class/backlight/ae94000.dsi.0/brightness)"
    sleep 0.5
    i=$((i+1))
done

echo
echo "===== 恢复 DPMS on ====="
R "XDG_RUNTIME_DIR=/run/marble-dashboard/xdg WAYLAND_DISPLAY=wayland-0 wlr-randr --output $OUT --on 2>&1 | head -3"
sleep 1
echo -n "  brightness: "; cat /sys/class/backlight/ae94000.dsi.0/brightness
