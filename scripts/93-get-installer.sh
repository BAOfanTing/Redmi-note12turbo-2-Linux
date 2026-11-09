#!/usr/bin/env bash
set -uo pipefail
OUT=/mnt/e/Cache/shuaji/out
W=/home/baofanting/marble-build/work

echo "=== marble-install via raw.githubusercontent ==="
for url in \
  https://raw.githubusercontent.com/iLtanaka/u-boot-marble/main/scripts/marble-install \
  https://cdn.jsdelivr.net/gh/iLtanaka/u-boot-marble@main/scripts/marble-install ; do
    echo "trying: $url"
    if curl -fsSL --retry 2 --retry-delay 3 --connect-timeout 30 --max-time 120 \
         -o "$OUT/marble-install" "$url"; then
        echo "  OK"
        break
    fi
    echo "  failed"
done

if [ -s "$OUT/marble-install" ]; then
    chmod +x "$OUT/marble-install"
    ls -l "$OUT/marble-install"
    head -5 "$OUT/marble-install"
    echo
    python3 -c "import ast,sys; ast.parse(open('$OUT/marble-install').read()); print('python syntax OK')"
else
    echo "!! could not download marble-install"
fi

echo
echo "=== also copy boot-uboot.img to out/ ==="
cp -v "$W/boot-uboot.img" "$OUT/boot-uboot.img"
sha256sum "$OUT/boot-uboot.img"
