#!/usr/bin/env bash
set -uo pipefail
echo "=== main/ layout ==="
curl -sL --max-time 25 https://mirror.nura.eco/postmarketos/main/ | grep -oE 'href="[^"]+"' | head -20
echo
echo "=== main/aarch64 index ==="
curl -sIL --max-time 25 -o /dev/null -w '%{http_code}\n' \
  https://mirror.nura.eco/postmarketos/main/aarch64/APKINDEX.tar.gz
echo
echo "=== extra-repos layout ==="
curl -sL --max-time 25 https://mirror.nura.eco/postmarketos/extra-repos/ | grep -oE 'href="[^"]+"' | head -10
echo
echo "=== extra-repos/systemd layout ==="
curl -sL --max-time 25 https://mirror.nura.eco/postmarketos/extra-repos/systemd/ | grep -oE 'href="[^"]+"' | head -10
echo
echo "=== systemd aarch64 index ==="
curl -sIL --max-time 25 -o /dev/null -w '%{http_code}\n' \
  https://mirror.nura.eco/postmarketos/extra-repos/systemd/aarch64/APKINDEX.tar.gz
echo
echo "=== alpine edge main aarch64 ==="
curl -sIL --max-time 25 -o /dev/null -w '%{http_code}\n' \
  http://mirror.nura.eco/alpine/edge/main/aarch64/APKINDEX.tar.gz
echo "=== alpine cdn ==="
curl -sIL --max-time 25 -o /dev/null -w '%{http_code}\n' \
  https://dl-cdn.alpinelinux.org/alpine/edge/main/aarch64/APKINDEX.tar.gz
