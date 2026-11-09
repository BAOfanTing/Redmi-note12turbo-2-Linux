#!/usr/bin/env bash
set -uo pipefail
D=/mnt/e/Cache/shuaji/out/dashboard
TMP=$(mktemp -d)

# 造假设备树：event0=电源键(EV_KEY)，event1=触摸屏(EV_ABS)，event2=纯设备(无能力位)
mkdir -p "$TMP/sys/class/input/event0/device/capabilities" \
         "$TMP/sys/class/input/event1/device/capabilities" \
         "$TMP/sys/class/input/event2/device/capabilities"
echo "10000000000000000000000000000000000000000000000000000000000 0 0 0" \
    > "$TMP/sys/class/input/event0/device/capabilities/key"
echo "0" > "$TMP/sys/class/input/event0/device/capabilities/abs"
echo "0" > "$TMP/sys/class/input/event1/device/capabilities/key"
echo "2608000000000000000000000000000000000000000" \
    > "$TMP/sys/class/input/event1/device/capabilities/abs"
echo "0" > "$TMP/sys/class/input/event2/device/capabilities/key"
echo "0" > "$TMP/sys/class/input/event2/device/capabilities/abs"

# 假的 /dev 节点
mkdir -p "$TMP/dev"
: > "$TMP/dev/input-event0"; : > "$TMP/dev/input-event1"; : > "$TMP/dev/input-event2"

# 抽出 list_devices 函数体，替换路径后单独测试
sed -n '/^list_devices()/,/^}/p' "$D/marble-screen-idle.sh" \
  | sed "s#/sys/class/input#$TMP/sys/class/input#g; s#/dev/\$(basename \"\$ev\")#$TMP/dev/input-\$(basename \"\$ev\")#" \
  > "$TMP/fn.sh"
# 上面 sed 对 dev 路径替换可能不匹配，改用更直接的办法：在函数前定义变量覆盖
cat > "$TMP/run.sh" <<'RUN'
SYSROOT="$1"
DEVROOT="$2"
list_devices() {
    for ev in "$SYSROOT"/event*; do
        [ -e "$ev" ] || continue
        dev="$DEVROOT/input-$(basename "$ev")"
        [ -r "$dev" ] || { echo "SKIP(not readable): $dev" >&2; continue; }

        cap=""
        [ -r "$ev/device/capabilities/key" ] && cap="$cap$(cat "$ev/device/capabilities/key" 2>/dev/null)"
        [ -r "$ev/device/capabilities/abs" ] && cap="$cap$(cat "$ev/device/capabilities/abs" 2>/dev/null)"

        sig=$(printf '%s' "$cap" | tr -d ' 0')
        [ -n "$sig" ] || continue

        echo "$dev"
    done
}
list_devices
RUN

echo "=== list_devices 结果（期望：只列出 event0 和 event1，不含 event2）==="
sh "$TMP/run.sh" "$TMP/sys/class/input" "$TMP/dev"

echo
echo "=== 检查 tr -d ' 0' 的裁剪效果 ==="
for s in "1000 0 0" "0" "" "2608"; do
    printf '  in=[%-12s] -> sig=[%s]\n' "$s" "$(printf '%s' "$s" | tr -d ' 0')"
done

rm -rf "$TMP"
