#!/bin/sh
PW="${MARBLE_PASSWORD:?set it in secrets.sh}"
R() { echo "$PW" | sudo -S sh -c "$*" 2>/dev/null; }

echo "===== 谁打开了 /dev/dri/card1 ====="
for p in $(R 'ls /proc | grep -E "^[0-9]+$"'); do
    if R "ls -l /proc/$p/fd 2>/dev/null | grep -q card1"; then
        cmd=$(R "tr '\\0' ' ' < /proc/$p/cmdline 2>/dev/null" | cut -c1-70)
        echo "  pid=$p $cmd"
    fi
done

echo
echo "===== /dev/dri/ 下的设备 ====="
R 'ls -l /dev/dri/'

echo
echo "===== 相机/GPU/显示相关的残留进程 ====="
R 'ps w 2>/dev/null | grep -E "phoc|phrog|cage|chromium|wayland|Xwayland|weston" | grep -v grep | cut -c1-90'

echo
echo "===== 当前活动 VT ====="
R 'fgconsole 2>/dev/null; cat /sys/class/tty/tty0/active 2>/dev/null'

echo
echo "===== DRM master 信息（debugfs）====="
R 'mount | grep -c debugfs'
R 'ls /sys/kernel/debug/dri/ 2>/dev/null'
R 'cat /sys/kernel/debug/dri/*/clients 2>/dev/null | head -20'

echo
echo "===== fbcon 是否还在用显示 ====="
R 'cat /sys/class/graphics/fb0/name 2>/dev/null'
R 'dmesg 2>/dev/null | grep -iE "fbcon|drm.*master|simpledrm" | tail -5'
