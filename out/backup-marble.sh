#!/system/bin/sh
# ============================================================================
# 备份 marble 的关键分区（persist / modemst1 / modemst2 / fsg）
#
# 这四个分区保存 IMEI 与射频校准数据。刷机前必须先备份，否则一旦损坏，
# 手机会变成"能开机但无信号"的半砖，且无法通过任何公开手段恢复。
#
# 用法（在手机上以 root 执行）：
#     adb shell su -c "sh /data/local/tmp/backup-marble.sh"
#     adb shell su -c "sh /data/local/tmp/backup-marble.sh /sdcard/marble-backup"
#
# 默认输出到 /data/local/tmp/marble-backup（root 可写、adb pull 也能直接读）。
#
# 说明：本脚本是纯 POSIX sh，兼容 Android 的 mksh / toybox sh，
#       不使用 bash 的关联数组、不做 GNU 专有选项。
# ============================================================================

OUT="${1:-/data/local/tmp/marble-backup}"
STAMP=$(date +%Y%m%d-%H%M%S)
DEST="$OUT/$STAMP"

echo "=============================================================="
echo " marble 关键分区备份"
echo " 输出目录: $DEST"
echo "=============================================================="

# root 检查
if [ "$(id -u)" != "0" ]; then
    echo "错误：需要 root 权限。请用 su 运行。" >&2
    exit 1
fi

mkdir -p "$DEST" || {
    echo "错误：无法创建目录 $DEST" >&2
    exit 1
}
chmod 700 "$OUT" "$DEST" 2>/dev/null

# ---------------------------------------------------------------- 定位分区
# 依次尝试常见路径，找到第一个存在的
find_part() {
    name="$1"
    for p in \
        "/dev/block/by-name/$name" \
        "/dev/block/platform/soc/1d84000.ufshc/by-name/$name" \
        "/dev/block/platform/soc/by-name/$name" \
        "/dev/block/bootdevice/by-name/$name" ; do
        [ -e "$p" ] && { echo "$p"; return 0; }
    done
    # 兜底：扫所有 by-name 目录
    for d in /dev/block/*/by-name /dev/block/*/*/by-name; do
        [ -e "$d/$name" ] && { echo "$d/$name"; return 0; }
    done
    return 1
}

# ---------------------------------------------------------------- 备份循环
fail=0
for name in persist modemst1 modemst2 fsg; do
    dev=$(find_part "$name")
    if [ -z "$dev" ]; then
        echo "!! 找不到分区 $name"
        fail=1
        continue
    fi

    echo ""
    echo ">>> $name  <-  $dev"
    # toybox dd 不支持 status=progress，这里用普通 dd（进度会打印到 stderr）
    if dd if="$dev" of="$DEST/$name.img" bs=1048576 2>&1 | tail -3; then
        :
    else
        echo "!! dd 失败: $name"
        fail=1
        continue
    fi
    sync

    # 校验大小（块设备上 ls 看不到真实大小，优先用 blockdev）
    srcsz=""
    if command -v blockdev >/dev/null 2>&1; then
        srcsz=$(blockdev --getsize64 "$dev" 2>/dev/null)
    fi
    dstsz=$(ls -l "$DEST/$name.img" 2>/dev/null | awk '{print $5}')
    echo "    备份大小: ${dstsz:-?} 字节"
    if [ -n "$srcsz" ] && [ "$srcsz" -gt 0 ] 2>/dev/null; then
        echo "    分区大小: $srcsz 字节"
        if [ "$srcsz" != "$dstsz" ]; then
            echo "    警告：大小不一致！请检查 dd 输出"
            fail=1
        fi
    fi
done

# ---------------------------------------------------------------- 校验和
echo ""
echo ">>> 生成校验和 ..."
cd "$DEST" || exit 1
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum ./*.img > SHA256SUMS.txt 2>/dev/null
    cat SHA256SUMS.txt
else
    echo "（本机没有 sha256sum，跳过；到电脑上再算）"
    : > SHA256SUMS.txt
fi

# ---------------------------------------------------------------- 设备信息
echo ""
echo ">>> 记录设备信息 ..."
{
    echo "# marble 备份信息"
    echo "时间: $(date '+%Y-%m-%d %H:%M:%S %z')"
    if [ -r /proc/device-tree/model ]; then
        printf '型号: '; tr -d '\0' < /proc/device-tree/model; echo
    fi
    echo "内核: $(uname -r)"
    echo
    echo "## 四个分区的实际路径与大小"
    for name in persist modemst1 modemst2 fsg; do
        p=$(find_part "$name")
        if [ -n "$p" ]; then
            sz="?"
            if command -v blockdev >/dev/null 2>&1; then
                sz=$(blockdev --getsize64 "$p" 2>/dev/null)
            fi
            echo "$name -> $p  (${sz:-?} 字节)"
        else
            echo "$name -> 未找到"
        fi
    done
    echo
    echo "## /dev/block/by-name 全量"
    ls -l /dev/block/by-name/ 2>/dev/null
} > "$DEST/device-info.txt" 2>&1

echo
echo "=============================================================="
# 关键：目录默认是 700（root only），而 `adb pull` 以 shell 用户运行会读不到，
# 报 "0 files pulled"。这里放开到 755/644 才能直接 pull。
chmod 755 "$OUT" "$DEST" 2>/dev/null
chmod 644 "$DEST"/* 2>/dev/null

if [ "$fail" != "0" ]; then
    echo " 警告：有分区未能备份，请看上面的输出！" >&2
    echo " 目录: $DEST"
    echo "=============================================================="
    exit 2
fi

echo " 备份完成: $DEST"
echo ""
echo " 拉到电脑（在 Windows / Linux 命令行执行）："
echo "     adb pull $DEST ./marble-backup"
echo ""
echo " 恢复方法（仅在分区损坏时）："
echo "     dd if=persist.img  of=/dev/block/by-name/persist"
echo "     dd if=modemst1.img of=/dev/block/by-name/modemst1"
echo "     dd if=modemst2.img of=/dev/block/by-name/modemst2"
echo "     dd if=fsg.img     of=/dev/block/by-name/fsg"
echo ""
echo " 请把该目录复制到三个地方（电脑 / 网盘 / U 盘）。总共只有约 56MB。"
echo "=============================================================="
