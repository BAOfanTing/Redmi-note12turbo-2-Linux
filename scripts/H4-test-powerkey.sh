#!/usr/bin/env bash
# 验证 marble-screen-idle.sh 里的事件解析逻辑
set -o pipefail
T=$(mktemp -d)

python3 - "$T" <<'PY'
import struct, sys, os
t = sys.argv[1]

def ev(etype, code, value):
    # struct input_event (aarch64/64bit): timeval{int64,int64} + u16 type + u16 code + s32 value
    return struct.pack("<qqHHi", 0, 0, etype, code, value)

os.makedirs(t, exist_ok=True)
open(f"{t}/power.press",   "wb").write(ev(1, 116, 1))   # EV_KEY, KEY_POWER, 按下
open(f"{t}/power.release", "wb").write(ev(1, 116, 0))   # 松开
open(f"{t}/touch",         "wb").write(ev(3, 57, 500))  # EV_ABS, ABS_MT_TRACKING_ID
open(f"{t}/volup",         "wb").write(ev(1, 115, 1))   # EV_KEY, KEY_VOLUMEUP
PY

EV_KEY=1
KEY_POWER=116

check() {
    f="$1"; expect="$2"
    set -- $(od -An -tu2 -j16 -N4 "$f" 2>/dev/null)
    t="${1:-}"; c="${2:-}"
    v=$(od -An -td4 -j20 -N4 "$f" 2>/dev/null | tr -d ' ')
    kind="普通输入"
    if [ "$t" = "$EV_KEY" ] && [ "$c" = "$KEY_POWER" ]; then
        if [ "${v:-0}" = "1" ]; then kind="电源键按下 -> toggle"; else kind="电源键松开 -> 忽略"; fi
    fi
    printf '  %-16s type=%-2s code=%-4s value=%-3s => %s\n' \
        "$(basename "$f")" "${t:-?}" "${c:-?}" "${v:-?}" "$kind"
}

echo "=== 解析结果 ==="
for f in power.press power.release touch volup; do check "$T/$f"; done

echo
echo "=== 检查脚本语法 ==="
dash -n /mnt/e/Cache/shuaji/out/dashboard/marble-screen-idle.sh && echo "  dash: OK"
bash -n /mnt/e/Cache/shuaji/out/dashboard/marble-screen-idle.sh && echo "  bash: OK"

rm -rf "$T"
