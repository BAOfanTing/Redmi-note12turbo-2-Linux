#!/bin/sh
# 抓取所有输入设备的原始事件，用于判断电源键到底有没有上报/被谁截走
DUR="${1:-300}"
OUT=/tmp/ev.log
: > "$OUT"

for dev in /dev/input/event*; do
    [ -r "$dev" ] || continue
    (
        TMPF="/tmp/.ev.$(basename "$dev")"
        while :; do
            if ! dd if="$dev" bs=24 count=1 of="$TMPF" 2>/dev/null; then
                sleep 1
                continue
            fi
            [ -s "$TMPF" ] || { sleep 1; continue; }
            set -- $(od -An -tu2 -j16 -N4 "$TMPF" 2>/dev/null)
            t="${1:-?}"; c="${2:-?}"
            v=$(od -An -td4 -j20 -N4 "$TMPF" 2>/dev/null | tr -d ' ')
            echo "$(date +%H:%M:%S) $(basename "$dev") type=$t code=$c value=${v:-?}" >> "$OUT"
        done
    ) &
done

sleep "$DUR"
kill $(jobs -p) 2>/dev/null
echo "$(date +%H:%M:%S) --- 抓取结束 ---" >> "$OUT"
