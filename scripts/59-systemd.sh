#!/usr/bin/env bash
set -uo pipefail
P=/home/baofanting/marble-build/pmaports

echo "=== extra-repos ==="
ls -la "$P/extra-repos/" 2>&1
echo
echo "=== extra-repos/systemd ==="
ls "$P/extra-repos/systemd/" 2>&1 | head -20
echo
echo "=== pmaports.cfg of systemd repo ==="
cat "$P/extra-repos/systemd/pmaports.cfg" 2>&1 | head -20
echo
echo "=== ui-console APKBUILD options ==="
grep -E '^(pkgname|options|depends|subpackages)=' "$P/main/postmarketos-ui-console/APKBUILD" | head
echo
echo "=== device package systemd units (already seen) + openrc? ==="
ls "$P/device/testing/device-xiaomi-marble/" | grep -iE 'openrc|initd|service' 
echo
echo "=== does the marble branch have systemd base packages? ==="
ls -d "$P/main/postmarketos-base" 2>&1
grep -E '^(pkgname|subpackages|options)=' "$P/main/postmarketos-base/APKBUILD" | head
