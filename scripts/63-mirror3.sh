#!/usr/bin/env bash
set -uo pipefail
echo "=== systemd repo main/aarch64 ==="
curl -sIL --max-time 25 -o /dev/null -w '%{http_code}\n' \
  https://mirror.nura.eco/postmarketos/extra-repos/systemd/main/aarch64/APKINDEX.tar.gz
echo "=== alpine cdn edge main aarch64 ==="
curl -sIL --max-time 25 -o /dev/null -w '%{http_code}\n' \
  https://dl-cdn.alpinelinux.org/alpine/edge/main/aarch64/APKINDEX.tar.gz
echo
echo "=== how does pmbootstrap build repo URLs? ==="
cd /home/baofanting/marble-build/pmbootstrap
grep -rn 'mirrordir_alpine\|mirrors.alpine\|mirrors.pmaports\|mirrors.systemd' pmb/ --include=*.py | head -20
