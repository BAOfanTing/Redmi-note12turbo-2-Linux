#!/usr/bin/env bash
set -uo pipefail
rm -rf /tmp/ir && mkdir -p /tmp/ir
cd /tmp/ir

if ! command -v zstd >/dev/null; then echo "zstd 未安装"; exit 1; fi

zstd -dc /tmp/initramfs.bin 2>/dev/null | cpio -idm --quiet 2>/dev/null
echo "文件总数: $(find . | wc -l)"
echo
echo "=== marble 相关文件 ==="
find . -iname '*marble*' | head -10
echo
echo "=== init 脚本头部 ==="
head -12 init 2>/dev/null
echo
echo "=== 内核模块（initramfs 内的）==="
ls lib/modules/*/ 2>/dev/null | head -25
echo
echo "=== 是否有 UFS / PMIC 等关键模块 ==="
find . -name '*.ko*' 2>/dev/null | sed 's|.*/||' | sort | head -30
