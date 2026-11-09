#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap

echo "=== ui list helper ==="
cat pmb/helpers/ui.py
echo
echo "=== ui-* aports in pmaports ==="
ls -d /home/baofanting/marble-build/pmaports/main/postmarketos-ui-* 2>/dev/null | xargs -n1 basename
echo
echo "=== pmaports.cfg ==="
cat /home/baofanting/marble-build/pmaports/pmaports.cfg
