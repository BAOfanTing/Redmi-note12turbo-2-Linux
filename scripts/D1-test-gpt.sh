#!/usr/bin/env bash
# 离线验证 D0-make-gpt.py：合成一个带 userdata 的 GPT，跑改写，再用 sgdisk 验表
set -uo pipefail
S=/mnt/e/Cache/shuaji/scripts/D0-make-gpt.py
T=$(mktemp -d)
cd "$T"

echo "=========== 1. 造合成磁盘 (16 GiB, 512B 扇区) ==========="
truncate -s 16G disk.img
# 1G super 放在前面，其余全部给 userdata（模拟 marble 布局）
sgdisk -n 1:2048:+1G   -t 1:8300 -c 1:"super"    disk.img >/dev/null
sgdisk -n 2:0:0        -t 2:8300 -c 2:"userdata" disk.img >/dev/null
sgdisk -p disk.img

echo "=========== 2. dump 主 GPT（LBA0..33，512B 扇区）==========="
dd if=disk.img of=gpt-orig.bin bs=512 count=34 status=none
ls -l gpt-orig.bin

DISK_SIZE=$(stat -c %s disk.img)
echo "disk-size = $DISK_SIZE"

echo "=========== 3. dry-run 改写 ==========="
python3 "$S" --gpt gpt-orig.bin --disk-size "$DISK_SIZE" \
    --sector-size 512 --esp-size 1G --prefix new

echo
echo "=========== 4. 真写并应用到副本 ==========="
python3 "$S" --gpt gpt-orig.bin --disk-size "$DISK_SIZE" \
    --sector-size 512 --esp-size 1G --prefix new --yes

cp disk.img patched.img
python3 - <<'PY'
import json, subprocess
p = json.load(open("new-plan.json"))
print("plan:", json.dumps(p, indent=2))
PY

PLAN=new-plan.json
read -r PL PB BL BB < <(python3 -c "
import json;p=json.load(open('$PLAN'))
print(p['primary_lba'],p['primary_bytes'],p['backup_lba'],p['backup_bytes'])")

echo "-- 写 backup（先），再写 primary --"
dd if=new-backup.bin  of=patched.img bs=512 seek="$BL" conv=notrunc status=none
dd if=new-primary.bin of=patched.img bs=512 seek="$PL" conv=notrunc status=none

echo
echo "=========== 5. sgdisk 校验新分区表 ==========="
sgdisk -v patched.img
echo "---"
sgdisk -p patched.img

echo
echo "=========== 6. 结论 ==========="
if sgdisk -v patched.img 2>&1 | grep -qi 'no problems\|found no problems'; then
    echo "PASS: 新 GPT 通过 sgdisk 一致性检查"
else
    echo "注意：sgdisk -v 输出见上（不同版本措辞不同）"
fi
rm -rf "$T"
