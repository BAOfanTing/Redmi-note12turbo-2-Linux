#!/usr/bin/env bash
set -uo pipefail
OUT=/mnt/e/Cache/shuaji/out
cd "$OUT"

echo "=== 重新生成 SHA256SUMS ==="
sha256sum boot-uboot.img marble-install \
          xiaomi-marble-boot.img xiaomi-marble-root.img \
          flash-marble.sh backup-marble.sh setup-server.sh \
          dashboard/marble-dashboard.sh dashboard/marble-dashboard.service \
          dashboard/marble-dashboard-kiosk.service dashboard/install-dashboard.sh \
          credentials.txt 手册.md README.md \
          > SHA256SUMS.txt

cat SHA256SUMS.txt
echo
echo "=== 自校验 ==="
sha256sum -c SHA256SUMS.txt 2>&1 | tail -5
echo
echo "=== out/ 最终结构 ==="
find . -type f -printf '%-46p %10s bytes\n' | sort
echo
echo "=== 总大小 ==="
du -sh .
echo
echo "=== 退出检查：镜像是否非空 ==="
for f in xiaomi-marble-boot.img xiaomi-marble-root.img boot-uboot.img; do
    [ -s "$f" ] && echo "OK  $f $(stat -c %s "$f") bytes" || echo "!!  $f 缺失或为空"
done
