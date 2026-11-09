#!/system/bin/sh
# 采集 LUN0 几何信息 + dump 原始 GPT（手机端，root）
set -u
echo "=== 磁盘几何 ==="
if command -v blockdev >/dev/null 2>&1; then
    echo "size64=$(blockdev --getsize64 /dev/block/sda 2>/dev/null)"
    echo "ss=$(blockdev --getss /dev/block/sda 2>/dev/null)"
else
    echo "blockdev 不存在"
fi
echo "sys_size_sectors=$(cat /sys/block/sda/size 2>/dev/null)"
echo "sys_logical_bs=$(cat /sys/block/sda/queue/logical_block_size 2>/dev/null)"
echo "sys_physical_bs=$(cat /sys/block/sda/queue/physical_block_size 2>/dev/null)"

echo
echo "=== userdata / super 分区节点 ==="
ls -l /dev/block/by-name/userdata /dev/block/by-name/super 2>/dev/null

echo
echo "=== 挂载情况（确认 /data 在 userdata 上）==="
grep -E ' /data | /data/media ' /proc/mounts 2>/dev/null

echo
echo "=== dump 主 GPT（LBA0..33 = 34*4096 字节）==="
mkdir -p /data/local/tmp/gptwork
if dd if=/dev/block/sda bs=4096 count=34 of=/data/local/tmp/gptwork/gpt-orig.bin 2>&1 | tail -2; then
    ls -l /data/local/tmp/gptwork/gpt-orig.bin
fi
chmod 755 /data/local/tmp/gptwork
chmod 644 /data/local/tmp/gptwork/gpt-orig.bin

echo
echo "=== GPT 头部字段（python 不在手机上，这里只 dump 十六进制签名）==="
dd if=/dev/block/sda bs=1 skip=4096 count=92 2>/dev/null | od -A d -t x1 | head -6
