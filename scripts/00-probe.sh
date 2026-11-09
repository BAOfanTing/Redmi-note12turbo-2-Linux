#!/usr/bin/env bash
# Probe the WSL build environment for the marble (Redmi Note 12 Turbo) route-B build.
set -u

echo "=== identity ==="
id
echo
echo "=== distro ==="
. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME"
echo
echo "=== tools ==="
for t in pmbootstrap apk mkfs.ext4 mke2fs qemu-aarch64-static gcc make flex bison bc \
         python3 git curl wget losetup cryptsetup ssh-keygen abuild; do
    p="$(command -v "$t" 2>/dev/null)"
    printf '%-22s %s\n' "$t" "${p:-MISSING}"
done
echo
echo "=== binfmt_misc ==="
ls /proc/sys/fs/binfmt_misc/ 2>&1
echo
echo "=== binfmt aarch64 entry ==="
cat /proc/sys/fs/binfmt_misc/qemu-aarch64 2>&1 | head -6
echo
echo "=== loop devices ==="
ls /dev/loop* 2>&1 | head -4
echo
echo "=== resources ==="
echo "nproc: $(nproc)"
free -g | head -2
df -h / /mnt/e 2>/dev/null | tail -3
echo
echo "=== network ==="
for u in https://gitlab.nura.eco https://github.com https://dl-cdn.alpinelinux.org; do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 12 "$u" 2>/dev/null)"
    printf '%-40s %s\n' "$u" "${code:-FAIL}"
done
echo
echo "=== apt cache state ==="
apt-get -v >/dev/null 2>&1 && echo "apt-get present"
ls /var/lib/apt/lists/ 2>/dev/null | head -3
