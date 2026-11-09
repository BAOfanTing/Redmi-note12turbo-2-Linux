#!/usr/bin/env bash
set -uo pipefail
OUT=/mnt/e/Cache/shuaji/out
cd "$OUT"

echo "=== 自动枚举 out/ 下所有文件生成 SHA256SUMS（排除 SHA256SUMS.txt 自身）==="
find . -type f ! -name 'SHA256SUMS.txt' -printf '%P\n' | sort | xargs -d '\n' sha256sum > SHA256SUMS.txt
cat SHA256SUMS.txt

echo
echo "=== 自校验 ==="
sha256sum -c SHA256SUMS.txt 2>&1 | tail -6

echo
echo "=== out/ 最终结构 ==="
find . -type f -printf '%-48p %10s\n' | sort
echo
echo "=== 总大小 ==="
du -sh .
