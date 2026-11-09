#!/bin/sh
# ============================================================================
# 在 marble（postmarketOS/Nura, console UI）上安装状态面板
#
#   sudo ./install-dashboard.sh                # 装面板 + 空闲熄屏
#   sudo IDLE_SEC=300 ./install-dashboard.sh   # 空闲 5 分钟熄屏
#   sudo ./install-dashboard.sh --no-idle      # 只装面板，屏幕常亮
#   sudo ./install-dashboard.sh --remove       # 全部卸载
#
# 装完效果：
#   * 屏幕全屏显示深色状态面板（CPU/内存/温度/电池/网络/服务），每 2 秒刷新
#   * 空闲 IDLE_SEC 秒后自动熄屏，按电源键 / 触摸屏幕立刻亮起
#   * 电源键不再触发关机（避免误按把服务器关掉）
#   * SSH 与所有服务完全不受影响，面板挂了也不影响服务器
# ============================================================================
set -eu

REMOVE=0
IDLE=1
for a in "$@"; do
    case "$a" in
        --remove)  REMOVE=1 ;;
        --no-idle) IDLE=0 ;;
        -h|--help)
            sed -n '3,16p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "未知参数: $a" >&2; exit 1 ;;
    esac
done

IDLE_SEC="${IDLE_SEC:-120}"
# dpms = 用 wlr-randr 关 DRM 输出（本机 AMOLED 唯一有效的关屏方式）
BLANK_MODE="${BLANK_MODE:-dpms}"

say() { printf '\033[1;32m[dashboard]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[dashboard]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[dashboard ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "请用 sudo 运行"

# ------------------------------------------------------------------ 卸载
if [ "$REMOVE" = "1" ]; then
    say "停用并移除面板与空闲熄屏"
    systemctl disable --now marble-screen-idle.service 2>/dev/null || true
    systemctl disable --now marble-dashboard-kiosk.service 2>/dev/null || true
    systemctl disable --now marble-dashboard.service 2>/dev/null || true
    rm -f /etc/systemd/system/marble-dashboard.service \
          /etc/systemd/system/marble-dashboard-kiosk.service \
          /etc/systemd/system/marble-screen-idle.service \
          /usr/local/bin/marble-dashboard.sh \
          /usr/local/bin/marble-screen.sh \
          /usr/local/bin/marble-screen-idle.sh
    rm -f /etc/systemd/logind.conf.d/99-marble-powerkey.conf
    rm -rf /run/marble-dashboard
    systemctl daemon-reload
    systemctl restart systemd-logind 2>/dev/null || true
    systemctl start getty@tty7.service 2>/dev/null || true
    say "已移除（cage/cog 包保留，可 apk del cage cog）"
    exit 0
fi

# ------------------------------------------------------------------ 依赖
say "1/7 安装 cage + chromium + seatd + wlr-randr"
# 注1：pmOS 仓库里没有 cog（WPE WebKit kiosk 浏览器），netsurf 虽小但不支持
#      CSS grid / JS，面板会渲染错。所以用 chromium。
# 注2：cage 需要 libseat 提供 seat；本机 libseat 只有 logind/seatd/noop 后端，
#      系统服务不属于带 seat 的 logind 会话，所以必须跑 seatd。
# 注3：wlr-randr 用来关 DRM 输出（本机 AMOLED 只有 DPMS 才能真正关屏）。
if ! apk add --no-cache cage chromium seatd wlr-randr; then
    die "安装失败。检查网络/DNS：apk update 是否正常？"
fi

# seatd 包不带 systemd 单元，用我们自己的
install -Dm644 seatd.service /etc/systemd/system/seatd.service
systemctl daemon-reload
systemctl enable --now seatd.service 2>/dev/null || true
sleep 1
[ -S /run/seatd.sock ] && say "seatd 已就绪 (/run/seatd.sock)" || warn "seatd socket 未出现，cage 可能起不来"

# ------------------------------------------------------------------ 脚本
say "2/7 安装脚本"
install -Dm755 marble-dashboard.sh    /usr/local/bin/marble-dashboard.sh
install -Dm755 marble-screen.sh       /usr/local/bin/marble-screen.sh
install -Dm755 marble-screen-idle.sh  /usr/local/bin/marble-screen-idle.sh
install -Dm755 marble-mode.sh         /usr/local/bin/marble-mode.sh
install -Dm755 marble-monitor         /usr/local/bin/marble-monitor
# phosh 应用列表里的图标入口（平板模式下点图标即可打开面板）
install -Dm644 marble-monitor.desktop /usr/share/applications/marble-monitor.desktop
install -Dm644 marble-monitor.svg \
    /usr/share/icons/hicolor/scalable/apps/marble-monitor.svg
command -v gtk-update-icon-cache >/dev/null 2>&1 && \
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database /usr/share/applications 2>/dev/null || true

# ------------------------------------------------------------------ 单元
say "3/7 安装 systemd 单元"
install -Dm644 marble-dashboard.service       /etc/systemd/system/marble-dashboard.service
install -Dm644 marble-dashboard-kiosk.service /etc/systemd/system/marble-dashboard-kiosk.service
install -Dm644 marble-screen-idle.service     /etc/systemd/system/marble-screen-idle.service

# ------------------------------------------------------------------ 电源键
say "4/7 让电源键不再关机（改为唤醒屏幕）"
mkdir -p /etc/systemd/logind.conf.d
install -Dm644 99-marble-powerkey.conf /etc/systemd/logind.conf.d/99-marble-powerkey.conf

# ------------------------------------------------------------------ tty7
say "5/7 让出 tty7（DRM 不能被 fbcon 占用）"
systemctl disable --now getty@tty7.service 2>/dev/null || true

# ------------------------------------------------------------------ 调参
if [ "$IDLE" = "1" ]; then
    say "6/7 配置空闲熄屏：${IDLE_SEC}s / BLANK_MODE=${BLANK_MODE}"
    mkdir -p /etc/systemd/system/marble-screen-idle.service.d
    cat > /etc/systemd/system/marble-screen-idle.service.d/override.conf <<EOF
[Service]
Environment=IDLE_SEC=$IDLE_SEC
Environment=BLANK_MODE=$BLANK_MODE
EOF
else
    say "6/7 跳过空闲熄屏（保持常亮）"
    systemctl disable marble-screen-idle.service 2>/dev/null || true
fi

# ------------------------------------------------------------------ 启动
say "7/7 生成首帧并启用"
mkdir -p /run/marble-dashboard
/usr/local/bin/marble-dashboard.sh || true
systemctl daemon-reload
systemctl enable --now marble-dashboard.service
sleep 2
systemctl enable --now marble-dashboard-kiosk.service
if [ "$IDLE" = "1" ]; then
    systemctl enable --now marble-screen-idle.service
fi

cat <<EOF

==============================================================
 安装完成

 面板文件     : /run/marble-dashboard/index.html
 熄屏控制     : marble-screen.sh {on|off|toggle|status}
 空闲设置     : ${IDLE_SEC}s 熄屏（改 /etc/systemd/system/marble-screen-idle.service.d/override.conf 后 daemon-reload + restart）
 电源键       : 已改为「忽略」，短按只唤醒屏幕，不会关机
 硬件强关     : 长按电源键仍可强制断电（PMIC 级，不受软件影响）

 检查状态：
   systemctl status marble-dashboard marble-dashboard-kiosk marble-screen-idle
   journalctl -u marble-screen-idle -n 50
   marble-screen.sh status
   marble-screen.sh off     # 手动熄屏
   marble-screen.sh on      # 手动亮屏

 电脑上看同一个面板：
   apk add busybox-extras
   busybox httpd -f -p 8081 -h /run/marble-dashboard
   → http://<手机IP>:8081/

⚠️ 如果熄屏后屏幕其实还亮着（AMOLED 无背光，写 brightness=0 可能无效）：
   sudo sed -i 's/^Environment=BLANK_MODE=.*/Environment=BLANK_MODE=kiosk/' \\
        /etc/systemd/system/marble-screen-idle.service.d/override.conf
   sudo systemctl daemon-reload && sudo systemctl restart marble-screen-idle
   （kiosk 模式会停掉 cage 释放 DRM，熄得更彻底，代价是唤醒慢 2~3 秒）

⚠️ AMOLED 烧屏：面板已用深色背景 + 低亮度。空闲熄屏本身就能显著缓解烧屏。
==============================================================
EOF
