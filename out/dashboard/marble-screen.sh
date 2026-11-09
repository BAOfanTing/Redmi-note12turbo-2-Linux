#!/bin/sh
# ============================================================================
# marble-screen.sh —— 屏幕开/关控制
#
#   marble-screen.sh off     熄屏
#   marble-screen.sh on      亮屏
#   marble-screen.sh status  查询状态
#
# 环境变量 BLANK_MODE：
#   dpms       用 wlr-randr 关掉 DRM 输出（**本机推荐**，真正关屏）
#   backlight  只写 /sys/class/backlight/*/brightness
#   kiosk      停掉 cage 释放 DRM
#   both       dpms + backlight
#
# ⚠️ 关于本机（marble / AMOLED）的实测结论：
#   只写 backlight/brightness = 0 是**无效**的 —— 这个面板的亮度是 DRM connector
#   属性，任何 DRM 提交（chromium 每 2 秒刷新页面就会提交）都会把它恢复成默认值
#   1842，实测 0.5 秒内就被改回。所以必须用 DPMS（wlr-randr --off）。
# ============================================================================
set -u

STATE_DIR=/run/marble-dashboard
SAVED="$STATE_DIR/brightness.saved"
FLAG="$STATE_DIR/blanked"
MODE="${BLANK_MODE:-dpms}"
KIOSK_UNIT="${KIOSK_UNIT:-marble-dashboard-kiosk.service}"
XDG_DIR="${XDG_DIR:-/run/marble-dashboard/xdg}"
FALLBACK_BRIGHTNESS="${FALLBACK_BRIGHTNESS:-45}"

mkdir -p "$STATE_DIR"

bl_dir() {
    for d in /sys/class/backlight/*; do
        [ -e "$d/brightness" ] || continue
        echo "$d"
        return 0
    done
    return 1
}

# 取 Wayland 输出名（默认 DSI-1）
wlr_out() {
    o=$(env XDG_RUNTIME_DIR="$XDG_DIR" WAYLAND_DISPLAY=wayland-0 \
        wlr-randr 2>/dev/null | head -1 | awk '{print $1}')
    [ -n "$o" ] && echo "$o" || echo "DSI-1"
}

do_dpms() {
    action="$1"
    if ! command -v wlr-randr >/dev/null 2>&1; then
        logger -t marble-screen "wlr-randr 未安装，跳过 dpms $action"
        return 1
    fi
    out=$(wlr_out)
    if env XDG_RUNTIME_DIR="$XDG_DIR" WAYLAND_DISPLAY=wayland-0 \
       wlr-randr --output "$out" "--$action" >/dev/null 2>&1; then
        logger -t marble-screen "dpms $action ($out)"
        return 0
    fi
    logger -t marble-screen "dpms $action 失败（kiosk 没在跑？）"
    return 1
}

bl_off() {
    d=$(bl_dir) || return 1
    max=$(cat "$d/max_brightness" 2>/dev/null || echo 0)
    cur=$(cat "$d/brightness" 2>/dev/null || echo 0)
    if [ "${cur:-0}" -gt 0 ] 2>/dev/null; then
        echo "$cur $max" > "$SAVED"
    fi
    echo 0 > "$d/brightness" 2>/dev/null || true
    logger -t marble-screen "backlight off ($d, was ${cur:-?}/$max)"
}

bl_on() {
    d=$(bl_dir) || return 1
    val=0; mx=0
    if [ -f "$SAVED" ]; then
        read -r val mx < "$SAVED" 2>/dev/null || { val=0; mx=0; }
    fi
    if [ "${val:-0}" -le 0 ] 2>/dev/null; then
        mx=$(cat "$d/max_brightness" 2>/dev/null || echo 0)
        [ "${mx:-0}" -gt 0 ] 2>/dev/null && val=$(( mx * FALLBACK_BRIGHTNESS / 100 ))
    fi
    [ "${val:-0}" -gt 0 ] 2>/dev/null && echo "$val" > "$d/brightness" 2>/dev/null
    logger -t marble-screen "backlight on ($d -> ${val:-?})"
}

do_off() {
    [ -f "$FLAG" ] && return 0
    case "$MODE" in
        dpms)      do_dpms off ;;
        backlight) bl_off ;;
        kiosk)     systemctl stop "$KIOSK_UNIT" 2>/dev/null || true ;;
        both)      do_dpms off; bl_off ;;
        *)         do_dpms off ;;
    esac
    : > "$FLAG"
}

do_on() {
    [ -f "$FLAG" ] || return 0
    case "$MODE" in
        dpms)      do_dpms on ;;
        backlight) bl_on ;;
        kiosk)     systemctl start "$KIOSK_UNIT" 2>/dev/null || true ;;
        both)      bl_on; do_dpms on ;;
        *)         do_dpms on ;;
    esac
    rm -f "$FLAG"
}

case "${1:-status}" in
    off)    do_off ;;
    on)     do_on ;;
    toggle) if [ -f "$FLAG" ]; then do_on; else do_off; fi ;;
    status)
        if [ -f "$FLAG" ]; then echo "blanked"; else echo "on"; fi
        d=$(bl_dir) || d=""
        if [ -n "$d" ]; then
            echo "backlight: $d = $(cat "$d/brightness" 2>/dev/null)/$(cat "$d/max_brightness" 2>/dev/null)"
        else
            echo "backlight: (none)"
        fi
        [ -f "$SAVED" ] && echo "saved: $(cat "$SAVED")"
        echo "mode: $MODE"
        if command -v wlr-randr >/dev/null 2>&1; then
            env XDG_RUNTIME_DIR="$XDG_DIR" WAYLAND_DISPLAY=wayland-0 \
                wlr-randr 2>/dev/null | grep -E '^(DSI|DPI)|Enabled:' | head -4
        fi
        ;;
    *)
        echo "用法: $0 {on|off|toggle|status}" >&2
        exit 1
        ;;
esac
