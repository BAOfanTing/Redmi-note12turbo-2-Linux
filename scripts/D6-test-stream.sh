#!/usr/bin/env bash
# 在 WSL 里用 Windows 的 adb 做二进制流式写入测试（16MiB，写入 pmos 起始处）
set -uo pipefail
ADB=/mnt/e/Cache/shuaji/tools/platform-tools/adb.exe
SRC=/mnt/e/Cache/shuaji/tmp/test16.bin
TMPWIN='E:\Cache\shuaji\tmp'
export TMP="$TMPWIN" TEMP="$TMPWIN"

ss=$((4096))
PMOS_SEEK_MB=13162          # 13801357312 / 1MiB

echo "=== 源文件 ==="
ls -l "$SRC"
sha_dev_src=$("$ADB" shell "su -c 'sha256sum /dev/null >/dev/null; echo ok'" 2>&1 | tr -d '\r')
echo "adb/su 连通: $sha_dev_src"

echo
echo "=== 流式写入 16MiB 到 LBA 3369472 (seek=${PMOS_SEEK_MB}MiB) ==="
"$ADB" shell -T "su -c 'dd of=/dev/block/sda bs=1M seek=${PMOS_SEEK_MB} conv=notrunc'" < "$SRC" 2>&1 | tr -d '\r'
echo "写 dd 退出码: $?"

echo
echo "=== flush ==="
"$ADB" shell "su -c 'blockdev --flushbufs /dev/block/sda'" 2>&1 | tr -d '\r'

echo
echo "=== 设备端读回并算 sha256 ==="
BACK=$("$ADB" shell "su -c 'dd if=/dev/block/sda bs=1M skip=${PMOS_SEEK_MB} count=16 2>/dev/null | sha256sum'" 2>&1 | tr -d '\r' | awk '{print $1}')
echo "设备端回读: $BACK"

echo
echo "=== 本地源 sha256 ==="
SRCH=$(sha256sum "$SRC" | awk '{print $1}')
echo "本地源    : $SRCH"

echo
if [ -n "$BACK" ] && [ "$BACK" = "$SRCH" ]; then
    echo "*** 传输无损 ✅ 可以写真实镜像 ***"
else
    echo "*** 不一致 ❌ 不要继续 ***"
fi
