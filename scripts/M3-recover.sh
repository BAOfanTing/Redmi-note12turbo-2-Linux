#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 1. 杀掉抢 DRM 的 chromium ====="
R 'pkill -f "ozone-platform" 2>/dev/null; pkill -f "/usr/lib/chromium/chromium" 2>/dev/null'
sleep 3
echo "  chromium 进程数: $(R 'pgrep -af chromium 2>/dev/null | grep -v pgrep | wc -l')"

echo
echo "===== 2. 谁还占着 card1 ====="
for p in $(R 'ls /proc | grep -E "^[0-9]+$"'); do
    if R "ls -l /proc/$p/fd 2>/dev/null | grep -q card1"; then
        cmd=$(R "tr '\\0' ' ' < /proc/$p/cmdline 2>/dev/null" | cut -c1-60)
        echo "  pid=$p $cmd"
    fi
done

echo
echo "===== 3. phoc 是否还在报错 ====="
R 'journalctl -u greetd --since "-30s" --no-pager 2>/dev/null | grep -c "Resource busy"'

echo
echo "===== 4. 截图看桌面是否恢复 ====="
sleep 3
R 'timeout 20 env XDG_RUNTIME_DIR=/run/user/10000 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot-recover.png 2>&1; ls -l /tmp/shot-recover.png 2>/dev/null'
