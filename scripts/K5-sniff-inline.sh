#!/bin/sh
# 抓 20 秒所有输入设备事件，并做汇总，找出"自己亮"的元凶
DUR=20
OUT=/tmp/ev.log
: > "$OUT"

for dev in /dev/input/event*; do
    [ -r "$dev" ] || continue
    (
        TMPF="/tmp/.ev.$(basename "$dev")"
        while :; do
            if ! dd if="$dev" bs=24 count=1 of="$TMPF" 2>/dev/null; then
                sleep 1; continue
            fi
            [ -s "$TMPF" ] || { sleep 1; continue; }
            set -- $(od -An -tu2 -j16 -N4 "$TMPF" 2>/dev/null)
            t="${1:-?}"; c="${2:-?}"
            v=$(od -An -td4 -j20 -N4 "$TMPF" 2>/dev/null | tr -d ' ')
            echo "$(basename "$dev") type=$t code=$c value=${v:-?}" >> "$OUT"
        done
    ) &
done

sleep "$DUR"
kill $(jobs -p) 2>/dev/null

echo "=== 设备名对照 ==="
grep -E '^N: Name=|^H: Handlers=' /proc/bus/input/devices | paste - - 2>/dev/null | sed 's/\t/  /'

echo
echo "=== 20 秒内事件统计（按设备+type+code）==="
sort "$OUT" 2>/dev/null | uniq -c | sort -rn | head -20

echo
echo "=== 总事件数 ==="
wc -l < "$OUT"

echo
echo "=== 前 15 条原始事件 ==="
head -15 "$OUT"
