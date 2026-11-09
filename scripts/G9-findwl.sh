#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
S() { echo "$PW" | sudo -S "$@" 2>/dev/null; }

CAGE=$(pgrep -f '^/usr/sbin/cage' | head -1)
echo "cage pid = $CAGE"

echo
echo "===== cage 的环境变�?====="
S tr '\0' '\n' < /proc/$CAGE/environ 2>/dev/null | grep -iE 'XDG_RUNTIME_DIR|WAYLAND_DISPLAY|LIBSEAT|WLR' 

echo
echo "===== /run 下所�?wayland socket ====="
find /run -maxdepth 4 -name 'wayland-*' 2>/dev/null
for d in /run/user/*; do [ -d "$d" ] && ls -la "$d" 2>/dev/null | head -5; done

echo
echo "===== /run/marble-dashboard 内容 ====="
ls -la /run/marble-dashboard/ 2>/dev/null

echo
echo "===== 有没�?wayland-0 在别�?====="
ls -la /tmp | grep -i wayland
S ls -la /run/user/0 2>/dev/null || echo "  /run/user/0 不存�?

echo
echo "===== chromium �?WAYLAND_DISPLAY ====="
CH=$(pgrep -f 'chromium --ozone-platform-hint' | head -1)
echo "chromium pid = $CH"
S tr '\0' '\n' < /proc/$CH/environ 2>/dev/null | grep -iE 'WAYLAND|XDG_RUNTIME'
