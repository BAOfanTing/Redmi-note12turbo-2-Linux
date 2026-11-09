#!/usr/bin/env bash
set -uo pipefail
D=$(echo /mnt/e/Cache/shuaji/marble-backup/*/ | awk '{print $1}')
echo "备份目录: $D"
cd "$D" || exit 1

echo "=== 1. 校验和核对（设备端生成的 SHA256SUMS.txt）==="
sha256sum -c SHA256SUMS.txt
echo "rc=$?"

echo
echo "=== 2. 内容真实性检查（防止全是 0 的空镜像）==="
for f in persist.img modemst1.img modemst2.img fsg.img; do
    [ -f "$f" ] || continue
    total=$(stat -c %s "$f")
    nonzero=$(tr -d '\000' < "$f" | wc -c)
    pct=$(( nonzero * 100 / total ))
    printf '  %-14s %9s 字节，非零字节 %8s（%3s%%）' "$f" "$total" "$nonzero" "$pct"
    if [ "$pct" -lt 1 ]; then echo "  <-- 可疑：几乎全 0"; else echo "  OK"; fi
done

echo
echo "=== 3. 头部十六进制（确认不是全零）==="
for f in persist.img modemst1.img fsg.img; do
    echo "--- $f ---"
    xxd -l 48 "$f"
done

echo
echo "=== 4. device-info.txt 里的分区对照 ==="
sed -n '1,25p' device-info.txt
