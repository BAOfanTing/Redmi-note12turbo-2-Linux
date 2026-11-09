#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
S() { echo "$PW" | sudo -S "$@" 2>/dev/null; }

echo "===== 安装 grim ====="
S apk add --no-cache grim 2>&1 | tail -2

echo
echo "===== cage �?wayland socket ====="
ls -l /run/marble-dashboard/xdg/ 2>/dev/null

echo
echo "===== 截屏 ====="
for sock in wayland-0 wayland-1; do
    [ -S "/run/marble-dashboard/xdg/$sock" ] || continue
    echo "  �?$sock ..."
    S env XDG_RUNTIME_DIR=/run/marble-dashboard/xdg WAYLAND_DISPLAY=$sock grim /tmp/shot.png
    if [ -s /tmp/shot.png ]; then
        echo "  成功: $(ls -l /tmp/shot.png | awk '{print $5}') 字节"
        S chmod 644 /tmp/shot.png
        break
    else
        echo "  失败"
    fi
done

ls -l /tmp/shot.png 2>/dev/null || echo "  没有截到�?
