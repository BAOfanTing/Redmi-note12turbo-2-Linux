#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
S() { echo "$PW" | sudo -S "$@" 2>/dev/null; }

echo "===== /dev/input ====="
ls -l /dev/input/ 2>/dev/null

echo
echo "===== /sys/class/input ====="
ls -1 /sys/class/input/ 2>/dev/null

echo
echo "===== �?event 节点�?capabilities 路径 ====="
for e in /sys/class/input/event*; do
    [ -e "$e" ] || continue
    n=$(basename "$e")
    echo "--- $n ---"
    ls "$e/device/capabilities/" 2>/dev/null | tr '\n' ' '; echo
    printf '    key='; cat "$e/device/capabilities/key" 2>/dev/null | head -c 60; echo
    printf '    abs='; cat "$e/device/capabilities/abs" 2>/dev/null | head -c 60; echo
done

echo
echo "===== /proc/bus/input/devices ====="
cat /proc/bus/input/devices 2>/dev/null | head -40

echo
echo "===== 当前 XDG_RUNTIME_DIR ====="
echo "  [env] ${XDG_RUNTIME_DIR:-(unset)}"
ls -ld /run/user/0 2>/dev/null || echo "  /run/user/0 不存�?

echo
echo "===== cage / chromium 是否装了 ====="
command -v cage && cage --help 2>&1 | head -3
command -v chromium && ls -l $(command -v chromium)
