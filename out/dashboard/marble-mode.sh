#!/bin/sh
# ============================================================================
# marble-mode.sh —— 在「服务器模式」和「平板模式」之间切换
#
#   marble-mode.sh server    无桌面：console + 状态面板 + 空闲熄屏（省电，默认）
#   marble-mode.sh tablet    图形桌面：phosh（可当平板用）
#   marble-mode.sh status    看当前状态
#
# 两种模式互斥：都要独占 DRM，所以切换时必须把另一边停掉。
# 切换后建议重启（图形会话涉及的 seat/logind 状态重启最干净）。
# ============================================================================
set -u

# ---- 面板 HTML 生成器（两种模式都常驻，App 靠它出数据）----
GEN_UNIT="marble-dashboard"
# ---- 只在服务器模式用的：全屏 kiosk + 电源键熄屏 ----
SCREEN_UNITS="marble-dashboard-kiosk marble-screen-idle"

log() { echo "[mode] $*"; }

do_server() {
    log "切换到【服务器模式】（无桌面 + 全屏面板）"
    for u in $TABLET_EXTRA $TABLET_UNITS; do
        systemctl disable --now "$u" 2>/dev/null || true
    done
    systemctl stop getty@tty7 2>/dev/null || true

    systemctl enable getty@tty1 2>/dev/null || true
    systemctl start getty@tty1 2>/dev/null || true
    systemctl start buffyboard 2>/dev/null || true

    systemctl enable "$GEN_UNIT" 2>/dev/null || true
    systemctl start "$GEN_UNIT" 2>/dev/null || true
    for u in $SCREEN_UNITS; do
        systemctl enable "$u" 2>/dev/null || true
    done
    systemctl start seatd 2>/dev/null || true
    sleep 2
    systemctl start marble-dashboard-kiosk 2>/dev/null || true
    systemctl start marble-screen-idle 2>/dev/null || true
    chvt 7 2>/dev/null || true
    log "完成。屏幕应显示全屏状态面板；SSH 正常。"
}

do_tablet() {
    log "切换到【平板模式】（phosh 图形桌面）"
    if [ ! -x /usr/libexec/phosh ] && ! command -v phosh-session >/dev/null 2>&1 \
       && ! command -v greetd >/dev/null 2>&1; then
        log "错误：phosh 未安装。先执行： sudo apk add postmarketos-ui-phosh"
        exit 1
    fi
    # 1) 停掉会独占 DRM 的东西：全屏 kiosk、熄屏守护、buffyboard、tty1 的 fbcon
    for u in $SCREEN_UNITS $TABLET_EXTRA; do
        systemctl disable --now "$u" 2>/dev/null || true
    done
    systemctl disable --now getty@tty1 2>/dev/null || true
    pkill -f '^/usr/sbin/cage' 2>/dev/null || true
    sleep 1

    # 2) HTML 生成器要留着跑（App 靠它刷新数据）
    systemctl enable "$GEN_UNIT" 2>/dev/null || true
    systemctl start "$GEN_UNIT" 2>/dev/null || true

    # 3) 清熄屏状态、恢复亮度
    rm -f /run/marble-dashboard/blanked
    BL=$(ls -d /sys/class/backlight/* 2>/dev/null | head -1)
    if [ -n "$BL" ] && [ -w "$BL/brightness" ]; then
        MX=$(cat "$BL/max_brightness" 2>/dev/null || echo 4095)
        echo $(( MX * 45 / 100 )) > "$BL/brightness" 2>/dev/null || true
    fi

    # 4) 起图形登录器 / 桌面
    systemctl enable greetd 2>/dev/null || true
    systemctl restart greetd 2>/dev/null || true
    sleep 2
    chvt 7 2>/dev/null || true
    log "完成。屏幕应出现 phosh 桌面。"
    log "（App 列表里有「Marble 状态面板」；若黑屏看： journalctl -u greetd -n 30）"
}

do_status() {
    echo "== 面板生成器（两种模式都应在跑）=="
    printf '  %-26s %-10s %s\n' "$GEN_UNIT" "$(systemctl is-active $GEN_UNIT 2>/dev/null)" "$(systemctl is-enabled $GEN_UNIT 2>/dev/null)"
    echo "== 服务器模式专用 =="
    for u in $SCREEN_UNITS; do
        printf '  %-26s %-10s %s\n' "$u" "$(systemctl is-active $u 2>/dev/null)" "$(systemctl is-enabled $u 2>/dev/null)"
    done
    echo "== 平板模式专用 =="
    for u in $TABLET_UNITS; do
        printf '  %-26s %-10s %s\n' "$u" "$(systemctl is-active $u 2>/dev/null)" "$(systemctl is-enabled $u 2>/dev/null)"
    done
    echo "== 判读 =="
    if systemctl is-active --quiet greetd 2>/dev/null; then
        echo "  当前：平板模式（phosh 在跑）"
    elif systemctl is-active --quiet marble-dashboard-kiosk 2>/dev/null; then
        echo "  当前：服务器模式（全屏面板在跑）"
    else
        echo "  当前：两者都没跑（纯 console）"
    fi
}

case "${1:-status}" in
    server) do_server ;;
    tablet) do_tablet ;;
    status) do_status ;;
    *)
        echo "用法: $0 {server|tablet|status}" >&2
        exit 1
        ;;
esac
