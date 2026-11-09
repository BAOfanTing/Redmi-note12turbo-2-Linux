#!/usr/bin/env bash
set -u
echo "=== mknod test on /mnt/e (9p) ==="
if mknod /mnt/e/Cache/shuaji/.nodetest c 1 3 2>/dev/null; then
    echo "mknod: OK"
    ls -l /mnt/e/Cache/shuaji/.nodetest
    rm -f /mnt/e/Cache/shuaji/.nodetest
else
    echo "mknod: FAILED (chroot build on drvfs is not viable)"
fi
echo
echo "=== chown test on /mnt/e ==="
touch /mnt/e/Cache/shuaji/.chowntest
if chown 0:0 /mnt/e/Cache/shuaji/.chowntest 2>/dev/null; then
    echo "chown: ok -> $(stat -c '%u:%g' /mnt/e/Cache/shuaji/.chowntest)"
else
    echo "chown: FAILED"
fi
rm -f /mnt/e/Cache/shuaji/.chowntest
echo
echo "=== hardlink test on /mnt/e ==="
echo x > /mnt/e/Cache/shuaji/.h1 2>/dev/null
ln /mnt/e/Cache/shuaji/.h1 /mnt/e/Cache/shuaji/.h2 2>/dev/null && echo "hardlink: ok" || echo "hardlink: FAILED"
rm -f /mnt/e/Cache/shuaji/.h1 /mnt/e/Cache/shuaji/.h2
echo
echo "=== ext4 home ==="
df -h /root | tail -1
echo
echo "=== ext4 mknod ==="
mknod /root/.nodetest c 1 3 2>/dev/null && echo "ext4 mknod: OK" && rm -f /root/.nodetest || echo "ext4 mknod: FAILED"
