#!/usr/bin/env bash
set -uo pipefail
D=/mnt/e/Cache/shuaji/out/dashboard

echo "=== 语法检查（sh -n，用 dash 和 busybox 各查一遍）==="
for f in marble-dashboard.sh marble-screen.sh marble-screen-idle.sh install-dashboard.sh; do
    printf '%-28s ' "$f"
    if dash -n "$D/$f" 2>/tmp/e1; then echo -n "dash:OK "; else echo -n "dash:FAIL "; cat /tmp/e1; fi
    if command -v busybox >/dev/null && busybox sh -n "$D/$f" 2>/tmp/e2; then echo "busybox:OK"; else echo "busybox:(skip/FAIL)"; cat /tmp/e2 2>/dev/null; fi
done

echo
echo "=== systemd 单元语法（忽略 ExecStart 不存在）==="
for u in marble-dashboard.service marble-dashboard-kiosk.service marble-screen-idle.service; do
    cp "$D/$u" /run/systemd/system/ 2>/dev/null || true
    printf '%-40s ' "$u"
    systemd-analyze verify "/run/systemd/system/$u" 2>&1 | grep -viE 'executable .* not found|Failed to prepare filename|command .* is not executable' | head -3
    echo "checked"
    rm -f "/run/systemd/system/$u"
done

echo
echo "=== 背光开关逻辑功能测试（用假 sysfs）==="
TMP=$(mktemp -d)
mkdir -p "$TMP/backlight/marble-bl"
echo 4096 > "$TMP/backlight/marble-bl/max_brightness"
echo 2048 > "$TMP/backlight/marble-bl/brightness"

# 生成一个把 /sys/class/backlight 指向假目录的副本
sed "s#/sys/class/backlight#$TMP/backlight#g; s#^STATE_DIR=.*#STATE_DIR=$TMP/state#" \
    "$D/marble-screen.sh" > "$TMP/screen.sh"
chmod +x "$TMP/screen.sh"
mkdir -p "$TMP/state"

echo "-- 初始 --"; sh "$TMP/screen.sh" status
echo "-- off --"; sh "$TMP/screen.sh" off 2>&1 | grep -v logger || true
echo "brightness 现在: $(cat "$TMP/backlight/marble-bl/brightness")"
echo "saved: $(cat "$TMP/state/brightness.saved" 2>/dev/null)"
echo "-- status --"; sh "$TMP/screen.sh" status
echo "-- on --"; sh "$TMP/screen.sh" on 2>&1 | grep -v logger || true
echo "brightness 恢复为: $(cat "$TMP/backlight/marble-bl/brightness")  (期望 2048)"
echo "-- 重复 off 应该幂等 --"; sh "$TMP/screen.sh" off >/dev/null 2>&1; sh "$TMP/screen.sh" off >/dev/null 2>&1
echo "brightness: $(cat "$TMP/backlight/marble-bl/brightness")  (期望 0)"

echo
echo "=== 验证：sed 替换是否留下 logger 调用（busybox 有 logger，OK）==="
grep -c 'logger' "$D/marble-screen.sh"

rm -rf "$TMP"
