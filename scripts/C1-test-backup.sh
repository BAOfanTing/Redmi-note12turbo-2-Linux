#!/usr/bin/env bash
set -uo pipefail
D=/mnt/e/Cache/shuaji/out

echo "=== 1. POSIX 语法检查 ==="
for sh in dash bash; do
    printf '%-8s ' "$sh"
    if $sh -n "$D/backup-marble.sh" 2>/tmp/err; then echo "OK"; else echo "FAIL"; cat /tmp/err; fi
done
if command -v busybox >/dev/null 2>&1; then
    printf '%-8s ' busybox; busybox sh -n "$D/backup-marble.sh" && echo OK || echo FAIL
else
    echo "busybox  未安装（可选）"
fi

echo
echo "=== 2. 检查是否还残留 bash 专有语法 ==="
grep -nE 'declare -A|\[\[|\bfunction\b|status=progress|\$\{[a-zA-Z_]+\[@\]\}' "$D/backup-marble.sh" \
    && echo "!! 发现 bash 专有语法" || echo "干净：没有 bash 专有语法"

echo
echo "=== 3. 功能测试：用普通文件冒充块设备 ==="
TMP=$(mktemp -d)
mkdir -p "$TMP/by-name" "$TMP/out"

# 造 4 个"分区"，大小故意不同以模拟真实情况
head -c 32768  /dev/urandom > "$TMP/by-name/persist"    # 32KB
head -c 8192   /dev/urandom > "$TMP/by-name/modemst1"   # 8KB
head -c 8192   /dev/urandom > "$TMP/by-name/modemst2"
head -c 8192   /dev/urandom > "$TMP/by-name/fsg"

# 生成把 /dev/block 指向假目录的副本
sed "s#/dev/block/by-name#$TMP/by-name#g; s#/dev/block/\*/by-name#$TMP/by-name#g" \
    "$D/backup-marble.sh" > "$TMP/test.sh"
chmod +x "$TMP/test.sh"

echo "--- 运行（输出目录 $TMP/out）---"
sh "$TMP/test.sh" "$TMP/out"
rc=$?
echo "--- 退出码: $rc （期望 0）---"

echo
echo "=== 4. 检查产物 ==="
find "$TMP/out" -type f -printf '%-40p %8s bytes\n' | sort
echo
echo "--- 内容一致性（原文件 vs 备份）---"
d=$(find "$TMP/out" -mindepth 1 -maxdepth 1 -type d | head -1)
for n in persist modemst1 modemst2 fsg; do
    if cmp -s "$TMP/by-name/$n" "$d/$n.img"; then echo "  OK   $n 内容一致"; else echo "  FAIL $n 内容不一致"; fi
done

echo
echo "=== 5. 校验和文件 ==="
cat "$d/SHA256SUMS.txt" 2>/dev/null
echo
echo "=== 6. device-info.txt 抽样 ==="
head -8 "$d/device-info.txt" 2>/dev/null

rm -rf "$TMP"
