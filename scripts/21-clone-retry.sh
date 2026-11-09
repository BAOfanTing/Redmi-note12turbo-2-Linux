#!/usr/bin/env bash
# Retry the pmaports clone with HTTP/1.1 + retries (GnuTLS flakiness on this network).
set -uo pipefail

USER_NAME="${USER_NAME:-baofanting}"
BUILD=/home/$USER_NAME/marble-build
LOG=/mnt/e/Cache/shuaji/logs/21-clone-retry.log
exec > >(tee -a "$LOG") 2>&1

echo "### [$(date -Is)] clone-retry start"
mkdir -p "$BUILD"
cd "$BUILD"
rm -rf pmaports

export GIT_HTTP_LOW_SPEED_LIMIT=1000
export GIT_HTTP_LOW_SPEED_TIME=60

echo "### connectivity"
for u in https://github.com https://codeload.github.com https://gitlab.nura.eco; do
    printf '%-30s %s\n' "$u" "$(curl -s -o /dev/null -w '%{http_code} %{time_total}s' --max-time 20 "$u")"
done

ok=0
for attempt in 1 2 3 4; do
    echo "### clone attempt $attempt"
    if git -c http.version=HTTP/1.1 -c http.postBuffer=524288000 \
           clone --depth 1 -b marble https://github.com/iLtanaka/pmaports.git pmaports; then
        ok=1
        break
    fi
    echo "   attempt $attempt failed, cleaning up"
    rm -rf pmaports
    sleep 5
done

if [ "$ok" -ne 1 ]; then
    echo "### git clone failed -> falling back to tarball"
    mkdir -p pmaports
    if curl -fL --retry 3 --retry-delay 5 --max-time 600 \
        -o /tmp/pmaports-marble.tar.gz \
        https://codeload.github.com/iLtanaka/pmaports/tar.gz/refs/heads/marble; then
        tar -xzf /tmp/pmaports-marble.tar.gz -C pmaports --strip-components=1
        echo "tarball extracted"
    else
        echo "!! tarball download also failed"
        exit 1
    fi
fi

cd pmaports
echo "### content check"
ls -1 | head -20
echo
echo "### device package"
ls -l device/testing/device-xiaomi-marble/APKBUILD 2>&1
echo "### linux aport"
grep -E '^(pkgname|pkgver|_commit|_tag)=' device/testing/linux-xiaomi-marble/APKBUILD 2>&1 | head
echo "### firmware aport dirs"
ls -d device/testing/firmware-xiaomi-marble* 2>/dev/null | head -20

chown -R "$USER_NAME:$USER_NAME" "$BUILD"
echo "### [$(date -Is)] clone-retry done (ok=$ok)"
