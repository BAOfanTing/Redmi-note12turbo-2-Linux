#!/usr/bin/env bash
set -uo pipefail
W=/home/baofanting/marble-build/work
R="$W/chroot_buildroot_aarch64"

echo "=== buildroot exists? ==="
ls -d "$R" 2>/dev/null || echo MISSING
echo
echo "=== ccache dir contents ==="
ls -l "$R/usr/lib/ccache/bin" 2>/dev/null | head -10
echo
echo "=== test compile inside chroot (via pmbootstrap chroot) ==="
su - baofanting -c 'export PATH="$HOME/.local/bin:$PATH"
echo "--- cc --version ---"
pmbootstrap chroot -b aarch64 -- cc --version 2>&1 | head -5
echo "--- which cc / gcc ---"
pmbootstrap chroot -b aarch64 -- sh -c "command -v cc; command -v gcc; ls -l /usr/bin/cc" 2>&1 | head -6
echo "--- try compiling ---"
pmbootstrap chroot -b aarch64 -- sh -c "cd /tmp && printf \"int main(void){return 0;}\n\" > t.c && cc -o t t.c && echo COMPILE_OK" 2>&1 | head -10
' 2>&1
