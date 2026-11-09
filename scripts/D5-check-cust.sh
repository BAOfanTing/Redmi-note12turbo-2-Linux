#!/system/bin/sh
# 检查 cust 能否作为暂存区（2GiB，运行时未挂载）
set -u
echo "=== cust 分区 ==="
ls -l /dev/block/by-name/cust 2>/dev/null
echo "bytes=$(blockdev --getsize64 /dev/block/by-name/cust 2>/dev/null)"

echo
echo "=== 是否已挂载 ==="
grep -i cust /proc/mounts || echo "未挂载"

echo
echo "=== 文件系统类型探测 ==="
if command -v blkid >/dev/null 2>&1; then
    blkid /dev/block/by-name/cust 2>/dev/null || echo "blkid 无输出"
else
    echo "blkid 不存在"
fi
# 读 1024 字节偏移处的 ext superblock magic
echo -n "ext magic (偏移1080, 期望 53ef): "
dd if=/dev/block/by-name/cust bs=1 skip=1080 count=2 2>/dev/null | od -A n -t x1

echo
echo "=== 尝试挂载 ==="
mkdir -p /mnt/cust
if mount -t ext4 -o rw /dev/block/by-name/cust /mnt/cust 2>&1; then
    echo "挂载成功 (ext4)"
elif mount -t auto -o rw /dev/block/by-name/cust /mnt/cust 2>&1; then
    echo "挂载成功 (auto)"
else
    echo "挂载失败"
fi

echo
echo "=== 挂载后的可用空间 ==="
df -h /mnt/cust 2>/dev/null
echo "--- 内容 ---"
ls -la /mnt/cust 2>/dev/null | head -10

echo
echo "=== 写入测试 ==="
if touch /mnt/cust/.wtest 2>/dev/null; then echo "可写 OK"; rm -f /mnt/cust/.wtest; else echo "不可写"; fi
