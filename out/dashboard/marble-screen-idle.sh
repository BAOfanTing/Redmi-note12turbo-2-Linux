#!/bin/sh
# ============================================================================
# marble-screen-idle.sh —— 屏幕管理器
#
#   * 空闲 IDLE_SEC 秒 → 自动熄屏
#   * 按【电源键】      → 手动切换 熄屏 / 亮屏
#   * 其它任何输入      → 亮屏（触摸、音量键…）
#
# 原理：直接读内核输入设备，阻塞读 24 字节 struct input_event（aarch64）。
#       event 布局：time(16B) + type(2B) + code(2B) + value(4B)
#       KEY_POWER 的 code = 116，EV_KEY = 1，按下时 value = 1
# 不依赖任何 Wayland / logind 空闲协议，compositor 挂了也照样工作。
# ============================================================================
set -u

STATE_DIR=/run/marble-dashboard
ACT="$STATE_DIR/last-activity"
FLAG="$STATE_DIR/blanked"
BLANKED_AT="$STATE_DIR/blanked-at"
TAP="$STATE_DIR/power-tap"
SCREEN=/usr/local/bin/marble-screen.sh
IDLE_SEC="${IDLE_SEC:-120}"
EV_KEY=1
KEY_POWER=116

# 背光设备（亮度看护用）
BL_DIR=""
for _d in /sys/class/backlight/*; do
    [ -e "$_d/brightness" ] && { BL_DIR="$_d"; break; }
done

log() { echo "[$(date '+%F %T')] $*"; }

mkdir -p "$STATE_DIR"
now=$(date +%s)
echo "$now" > "$ACT"
echo 0 > "$TAP"
rm -f "$FLAG" "$BLANKED_AT"

# ---------------------------------------------------------------- 枚举设备
list_devices() {
    for ev in /sys/class/input/event*; do
        [ -e "$ev" ] || continue
        # 设备节点在 /dev/input/ 下（第一版写成 /dev/ 是 bug）
        dev="/dev/input/$(basename "$ev")"
        [ -r "$dev" ] || continue

        cap=""
        [ -r "$ev/device/capabilities/key" ] && cap="$cap$(cat "$ev/device/capabilities/key" 2>/dev/null)"
        [ -r "$ev/device/capabilities/abs" ] && cap="$cap$(cat "$ev/device/capabilities/abs" 2>/dev/null)"

        sig=$(printf '%s' "$cap" | tr -d ' 0')
        [ -n "$sig" ] || continue
        echo "$dev"
    done
}

DEVS=$(list_devices)
if [ -z "$DEVS" ]; then
    log "错误：没有找到可读的输入设备。请确认以 root 运行且 /dev/input/event* 存在。"
    exit 1
fi
log "监视输入设备: $(echo "$DEVS" | tr '\n' ' ')"
log "空闲阈值 ${IDLE_SEC}s；电源键=切换熄屏"

PIDS=""
cleanup() {
    log "退出，清理监听进程"
    for p in $PIDS; do kill "$p" 2>/dev/null; done
    exit 0
}
trap cleanup INT TERM HUP

# ---------------------------------------------------------------- 监听
for dev in $DEVS; do
    (
        EVF="$STATE_DIR/.ev.$(basename "$dev")"
        while :; do
            if ! dd if="$dev" bs=24 count=1 of="$EVF" 2>/dev/null; then
                sleep 2
                continue
            fi
            [ -s "$EVF" ] || { sleep 1; continue; }

            # type(偏移16) code(偏移18) value(偏移20)
            set -- $(od -An -tu2 -j16 -N4 "$EVF" 2>/dev/null)
            t="${1:-}"; c="${2:-}"
            v=$(od -An -td4 -j20 -N4 "$EVF" 2>/dev/null | tr -d ' ')

            if [ "$t" = "$EV_KEY" ] && [ "$c" = "$KEY_POWER" ]; then
                # 只在"按下"那一下算一次（value=1），松开完全忽略：
                # 否则松开事件会被当成"普通输入"去刷新活动时间，把刚熄的屏又点亮
                if [ "${v:-0}" = "1" ]; then
                    n=$(cat "$TAP" 2>/dev/null || echo 0)
                    echo $((n + 1)) > "$TAP"
                fi
            else
                # 普通输入 → 记活动时间（用于亮屏 + 空闲计时）
                # 同时记下来源，排错时能知道是哪个设备"偷偷"唤醒屏幕
                echo "$(basename "$dev") type=$t code=$c value=${v:-?}" > "$STATE_DIR/last-event"
                date +%s > "$ACT"
            fi
            sleep 0.1
        done
    ) &
    PIDS="$PIDS $!"
done

# ---------------------------------------------------------------- 主循环
GRACE=15
sleep "$GRACE"
date +%s > "$ACT"
log "宽限期结束，开始空闲检测"

LAST_TAP=$(cat "$TAP" 2>/dev/null || echo 0)

while :; do
    now=$(date +%s)

    # ---- 电源键：切换熄屏/亮屏 ----
    cur_tap=$(cat "$TAP" 2>/dev/null || echo 0)
    if [ "$cur_tap" != "$LAST_TAP" ]; then
        LAST_TAP="$cur_tap"
        if [ -f "$FLAG" ]; then
            log "电源键 -> 亮屏"
            "$SCREEN" on || true
        else
            log "电源键 -> 熄屏"
            "$SCREEN" off || true
            # 关键：记录熄屏时刻，否则同一秒内的其它事件会立刻把屏点亮
            date +%s > "$BLANKED_AT"
        fi
        # 复位空闲计时，避免刚亮屏又被判为空闲
        date +%s > "$ACT"
        continue
    fi

    last=$(cat "$ACT" 2>/dev/null || echo "$now")
    case "$last" in ''|*[!0-9]*) last=$now ;; esac
    idle=$(( now - last ))

    if [ -f "$FLAG" ]; then
        # 熄屏状态下：只有"非电源键"的输入才唤醒（且要晚于熄屏时刻 3 秒）
        bat=$(cat "$BLANKED_AT" 2>/dev/null || echo 0)
        case "$bat" in ''|*[!0-9]*) bat=0 ;; esac
        if [ "$idle" -lt 2 ] && [ "$last" -gt $((bat + 3)) ]; then
            log "检测到输入[$(cat "$STATE_DIR/last-event" 2>/dev/null)]，亮屏"
            "$SCREEN" on || true
            date +%s > "$ACT"
        fi
        # 注意：不要再做"亮度看护"反复写 brightness=0。
        # 本机 AMOLED 的亮度是 DRM 属性，反复写只会在 0/1842 之间抖动（屏幕闪烁）。
        # 关屏靠 BLANK_MODE=dpms（wlr-randr --off），见 marble-screen.sh。
    else
        if [ "$idle" -ge "$IDLE_SEC" ]; then
            log "空闲 ${idle}s >= ${IDLE_SEC}s，熄屏"
            "$SCREEN" off || true
            date +%s > "$BLANKED_AT"
        fi
    fi

    sleep 1
done
