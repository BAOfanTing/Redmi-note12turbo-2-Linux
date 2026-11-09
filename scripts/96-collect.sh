#!/usr/bin/env bash
# Step 8: collect artifacts into E:\Cache\shuaji\out, verify, and checksum.
set -uo pipefail

W=/home/baofanting/marble-build/work
OUT=/mnt/e/Cache/shuaji/out
RF="$W/chroot_native/home/pmos/rootfs"
LOG=/mnt/e/Cache/shuaji/logs/96-collect.log
exec > >(tee -a "$LOG") 2>&1

echo "### [$(date -Is)] collect artifacts"

echo "=== search for images ==="
find "$W" -maxdepth 6 \( -name 'xiaomi-marble-*.img' -o -name '*.img' \) 2>/dev/null | head -20
echo
echo "=== rootfs dir ==="
ls -la "$RF" 2>/dev/null

mkdir -p "$OUT"
for f in xiaomi-marble-boot.img xiaomi-marble-root.img; do
    src=""
    for cand in "$RF/$f" "$W/images/$f"; do
        [ -f "$cand" ] && src="$cand" && break
    done
    if [ -z "$src" ]; then
        src=$(find "$W" -name "$f" 2>/dev/null | head -1)
    fi
    if [ -n "$src" ] && [ -f "$src" ]; then
        echo ">>> copying $f from $src"
        cp -f "$src" "$OUT/$f"
    else
        echo "!! $f NOT FOUND"
    fi
done

echo
echo "=== verification ==="
for f in "$OUT"/xiaomi-marble-*.img; do
    [ -f "$f" ] || continue
    echo "--- $(basename "$f") ---"
    ls -lh "$f"
    echo -n "type: "; blkid -p -o export "$f" 2>/dev/null | grep -E '^(TYPE|BLOCK_SIZE|LABEL)=' | tr '\n' ' '; echo
    echo -n "block size: "; dumpe2fs -h "$f" 2>/dev/null | grep -i 'Block size' || echo "(not ext)"
done

echo
echo "=== boot image must contain /extlinux/extlinux.conf ==="
if [ -f "$OUT/xiaomi-marble-boot.img" ]; then
    debugfs -R "stat /extlinux/extlinux.conf" "$OUT/xiaomi-marble-boot.img" 2>/dev/null | head -6
    echo "--- extlinux.conf content ---"
    debugfs -R "cat /extlinux/extlinux.conf" "$OUT/xiaomi-marble-boot.img" 2>/dev/null | head -20
    echo "--- /boot listing ---"
    debugfs -R "ls -l /" "$OUT/xiaomi-marble-boot.img" 2>/dev/null | head -15
fi

echo
echo "=== checksums ==="
cd "$OUT"
sha256sum boot-uboot.img marble-install flash-marble.sh backup-marble.sh \
          setup-server.sh xiaomi-marble-boot.img xiaomi-marble-root.img \
          > SHA256SUMS.txt 2>/dev/null
cat SHA256SUMS.txt
echo
echo "### [$(date -Is)] collect done"
