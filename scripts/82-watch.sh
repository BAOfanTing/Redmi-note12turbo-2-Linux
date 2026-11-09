#!/usr/bin/env bash
# Watch the firmware build without dumping wget progress bars.
set -uo pipefail
D=/home/baofanting/marble-build/work
for i in $(seq 1 60); do
    part=$(stat -c %s "$D/cache_distfiles/firmware-xiaomi-marble-20261008.tar.gz.part" 2>/dev/null || echo 0)
    full=$(stat -c %s "$D/cache_distfiles/firmware-xiaomi-marble-20261008.tar.gz" 2>/dev/null || echo 0)
    apks=$(find "$D/packages" -name '*.apk' 2>/dev/null | wc -l)
    printf '[%s] part=%sMB full=%sMB apks=%s\n' "$(date +%H:%M:%S)" \
        "$((part/1048576))" "$((full/1048576))" "$apks"
    if [ "$full" -gt 0 ] && [ "$apks" -gt 0 ]; then
        echo "firmware tarball complete and packages present"
        break
    fi
    sleep 20
done
echo "=== final ==="
ls -l "$D/cache_distfiles/" 2>/dev/null
find "$D/packages" -name '*.apk' 2>/dev/null
