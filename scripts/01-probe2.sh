#!/usr/bin/env bash
set -u
echo "=== pid1 ==="
cat /proc/1/comm
echo
echo "=== systemd? ==="
systemctl is-system-running 2>&1 | head -2
echo
echo "=== existing sudoers.d ==="
ls /etc/sudoers.d/ 2>&1
echo
echo "=== apt policy qemu-user-static ==="
apt-cache policy qemu-user-static 2>/dev/null | head -4
echo
echo "=== python venv/pip ==="
python3 -m venv --help >/dev/null 2>&1 && echo "venv ok" || echo "venv MISSING"
python3 -m pip --version 2>&1 | head -1
echo
echo "=== /mnt/e perms test ==="
touch /mnt/e/Cache/shuaji/.permtest 2>&1 && echo "write ok" || echo "write FAIL"
ls -l /mnt/e/Cache/shuaji/.permtest 2>&1
rm -f /mnt/e/Cache/shuaji/.permtest
echo
echo "=== drvfs mount opts ==="
mount | grep ' /mnt/e ' 
