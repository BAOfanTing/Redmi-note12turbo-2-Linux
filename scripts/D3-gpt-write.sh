#!/system/bin/sh
# 手机端：写入新 GPT（主+备），并 dump 回来供 PC 校验
# LBA1 起的头部/表和磁盘末尾的备份，都不属于任何分区，写入安全
set -u
W=/data/local/tmp/gptwork
DEV=/dev/block/sda
SS=4096
BAK_LBA=61880317     # 备用表起点（entries）
PRIMARY_LBA=1

echo "=== 写之前：备份当前 GPT 到文件（保险） ==="
dd if=$DEV bs=$SS count=34 of=$W/gpt-before.bin 2>&1 | tail -1
# 备用 GPT：表+头 共 4 扇区，位于末尾
dd if=$DEV bs=$SS skip=$BAK_LBA count=4 of=$W/gpt-before-backup.bin 2>&1 | tail -1
ls -l $W/gpt-before.bin $W/gpt-before-backup.bin

echo
echo "=== 写备用 GPT（先写备份，再写主，和 marble-install 顺序一致）==="
dd if=$W/gpt-new-backup.bin of=$DEV bs=$SS seek=$BAK_LBA conv=notrunc 2>&1 | tail -1
sync
echo "--- flush block device ---"
blockdev --flushbufs $DEV 2>/dev/null && echo "flush OK" || echo "flush 不支持，继续"

echo
echo "=== 写主 GPT ==="
dd if=$W/gpt-new-primary.bin of=$DEV bs=$SS seek=$PRIMARY_LBA conv=notrunc 2>&1 | tail -1
sync
blockdev --flushbufs $DEV 2>/dev/null

echo
echo "=== 读回 GPT 头验证签名 ==="
dd if=$DEV bs=1 skip=$((SS)) count=16 2>/dev/null | od -A d -t x1 | head -2

echo
echo "=== dump 新 GPT 供 PC 校验（34 扇区 + 备用 4 扇区）==="
dd if=$DEV bs=$SS count=34 of=$W/gpt-after.bin 2>&1 | tail -1
dd if=$DEV bs=$SS skip=$BAK_LBA count=4 of=$W/gpt-after-backup.bin 2>&1 | tail -1
chmod 644 $W/gpt-after.bin $W/gpt-after-backup.bin $W/gpt-before*.bin
ls -l $W/
