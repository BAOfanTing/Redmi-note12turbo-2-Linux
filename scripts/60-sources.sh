#!/usr/bin/env bash
set -uo pipefail
echo "=== firmware tarball (github) ==="
for u in \
  https://github.com/iLtanaka/firmware-xiaomi-marble/archive/v20261008/firmware-xiaomi-marble-20261008.tar.gz \
  https://codeload.github.com/iLtanaka/firmware-xiaomi-marble/tar.gz/refs/tags/v20261008 ; do
  printf '%-100s ' "$u"
  curl -sIL --max-time 25 -o /dev/null -w '%{http_code} size=%{size_download}\n' "$u" || echo FAIL
done
echo
echo "=== kernel tarball (cdn.kernel.org) ==="
curl -sIL --max-time 25 -o /dev/null -w 'linux-7.2.8: %{http_code}\n' \
  https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.2.8.tar.xz
echo
echo "=== alpine mirror via pmos ==="
curl -sL --max-time 25 -o /dev/null -w 'alpine edge main aarch64: %{http_code}\n' \
  http://mirror.nura.eco/postmarketos/../alpine/edge/main/aarch64/APKINDEX.tar.gz 2>/dev/null
echo
echo "=== pmos repo index ==="
for u in \
  https://mirror.nura.eco/postmarketos/edge/aarch64/APKINDEX.tar.gz \
  https://mirror.nura.eco/postmarketos/edge/systemd/aarch64/APKINDEX.tar.gz ; do
  printf '%-75s ' "$u"
  curl -sIL --max-time 25 -o /dev/null -w '%{http_code}\n' "$u" || echo FAIL
done
