#!/usr/bin/env bash
# 把 root.img 转成 Android sparse，并验证往返一致
set -uo pipefail
cd /mnt/e/Cache/shuaji || exit 1

echo "=== 原始 root.img ==="
ls -l out/xiaomi-marble-root.img
sha256sum out/xiaomi-marble-root.img

echo
echo "=== 转 sparse（块大小 1MiB）==="
if ! img2simg out/xiaomi-marble-root.img tmp/root.simg 1048576; then
    echo "带块大小失败，回退默认"
    img2simg out/xiaomi-marble-root.img tmp/root.simg
fi
ls -l tmp/root.simg

echo
echo "=== 往返验证：simg2img 还原后应和原文件完全一致 ==="
rm -f tmp/root.raw
simg2img tmp/root.simg tmp/root.raw
ls -l tmp/root.raw

A=$(sha256sum out/xiaomi-marble-root.img | awk '{print $1}')
B=$(sha256sum tmp/root.raw | awk '{print $1}')
echo "原始: $A"
echo "还原: $B"
if [ "$A" = "$B" ]; then
    echo "*** sparse 往返一致 ✅ ***"
    RSAVE=0
else
    echo "*** 往返不一致 ❌ ***"
    RSAVE=1
fi
rm -f tmp/root.raw

echo
echo "=== sparse 头部信息（供参考）==="
od -A d -t x1 -N 28 tmp/root.simg

exit $RSAVE
