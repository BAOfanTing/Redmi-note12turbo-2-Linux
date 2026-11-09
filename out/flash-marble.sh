#!/usr/bin/env bash
# ============================================================================
# 刷机主脚本：把 pmbootstrap 生成的镜像刷入 marble（在 Linux PC 上执行）
#
# 步骤概要（完整说明见 手册.md）：
#   1. 手机上：关机 -> 音量下+电源 进入 fastboot
#   2. 本脚本第 1 步：确认已解锁、刷入 U-Boot 到 boot_b、切 slot B
#   3. 手机重启 -> U-Boot 菜单 -> Enable USB mass storage
#   4. 本脚本第 2 步：检查磁盘、写入镜像、扩展分区
#
# 环境要求：Linux PC（本项目的构建机即满足），需要 fastboot 与
#   python3、e2fsprogs、util-linux、cryptsetup、udevadm、wipefs、blkid
# ============================================================================
set -euo pipefail

# ------------------------- 可配置变量 -------------------------------------
WORK_DIR="${1:-/home/baofanting/marble-build/work}"
BOOT_IMG="${BOOT_IMG:-$WORK_DIR/chroot_native/home/pmos/rootfs/xiaomi-marble-boot.img}"
ROOT_IMG="${ROOT_IMG:-$WORK_DIR/chroot_native/home/pmos/rootfs/xiaomi-marble-root.img}"
UBOOT_IMG="${UBOOT_IMG:-$WORK_DIR/boot-uboot.img}"
LAYOUT="${LAYOUT:-single}"          # single | dual
PMOS_SIZE="${PMOS_SIZE:-64G}"       # dual 布局时 pmos 分区大小
DRY_RUN="${DRY_RUN:-0}"             # 1 = 只打印计划不写入

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

log() { printf '\033[1;32m[flash]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[flash ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

command -v fastboot >/dev/null || die "缺少 fastboot，请安装 android-tools-fastboot"
command -v python3 >/dev/null || die "缺少 python3"

# ------------------------- 第 1 步：fastboot 刷 U-Boot --------------------
step1_fastboot() {
    log "=== 第 1 步：fastboot 刷入 U-Boot 到 boot_b ==="
    [ -f "$UBOOT_IMG" ] || die "找不到 U-Boot 镜像: $UBOOT_IMG（先下载 boot-uboot.img 放到 out/）"

    fastboot devices || die "fastboot 无法看到设备，请确认已进入 fastboot 并连接 USB"
    fastboot getvar current-slot || true
    fastboot getvar current-slot || die "无法读取当前 slot（小米要求查两次）"
    fastboot getvar unlocked 2>/dev/null || true

    log "写入 U-Boot 到 boot_b ..."
    fastboot flash boot_b "$UBOOT_IMG"
    log "切换活动 slot 到 B ..."
    fastboot set_active b
    log "重启到 U-Boot ..."
    fastboot reboot

    cat <<'EOF'

手机现在会重启进入 U-Boot（倒计时 5 秒）。
按住音量下进入菜单，选择 "Enable USB mass storage"，
把手机内部存储导出为 U 盘，然后回到本脚本执行第 2 步：
    sudo $0 --step2
EOF
}

# ------------------------- 第 2 步：写入镜像 ------------------------------
step2_install() {
    log "=== 第 2 步：写入 pmOS 镜像 ==="
    [ -f "$BOOT_IMG" ] || die "找不到 boot 镜像: $BOOT_IMG"
    [ -f "$ROOT_IMG" ] || die "找不到 root 镜像: $ROOT_IMG"

    log "boot: $BOOT_IMG ($(stat -c %s "$BOOT_IMG" 2>/dev/null) 字节)"
    log "root: $ROOT_IMG ($(stat -c %s "$ROOT_IMG" 2>/dev/null) 字节)"
    log "layout: $LAYOUT"

    # 使用维护者的 marble-install 脚本（从 u-boot-marble 仓库获取）
    INSTALL="$SCRIPT_DIR/marble-install"
    if [ ! -f "$INSTALL" ]; then
        log "下载 marble-install 脚本 ..."
        curl -fL --retry 3 -o "$INSTALL" \
            https://raw.githubusercontent.com/iLtanaka/u-boot-marble/main/scripts/marble-install
        chmod +x "$INSTALL"
    fi

    log "=== 检查导出的磁盘 ==="
    "$INSTALL" list || true

    DRY=""
    [ "$DRY_RUN" = "1" ] && DRY="--dry-run"

    # shellcheck disable=SC2086
    "$INSTALL" install \
        --layout "$LAYOUT" \
        --pmos-size "$PMOS_SIZE" \
        --boot-img "$BOOT_IMG" \
        --root-img "$ROOT_IMG" \
        --backup-dir "$SCRIPT_DIR/backup-gpt" \
        $DRY

    log "=== 刷机完成 ==="
    cat <<'EOF'
在手机上按任意键退出大容量存储模式，然后选择 "Boot Nura"（或等待倒计时）。
若 root 用了 LUKS 加密，解锁时会在触摸屏上输入密码。

后续更新内核/系统：pmbootstrap install --split 重新生成镜像，
再运行 sudo $0 --step2 --layout reinstall
EOF
}

# ------------------------- 参数解析 ---------------------------------------
case "${1:-}" in
    --step1) step1_fastboot ;;
    --step2) step2_install ;;
    -h|--help)
        echo "用法: $0 [--step1|--step2]"
        echo "  --step1  在 fastboot 模式刷 U-Boot 到 boot_b"
        echo "  --step2  在 U-Boot USB mass storage 模式下写入镜像"
        echo "环境变量: BOOT_IMG ROOT_IMG UBOOT_IMG LAYOUT PMOS_SIZE DRY_RUN"
        ;;
    *)
        step1_fastboot
        ;;
esac
