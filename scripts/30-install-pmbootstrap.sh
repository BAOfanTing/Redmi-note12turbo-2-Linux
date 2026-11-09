#!/usr/bin/env bash
# Step 3: install pmbootstrap for the build user.
set -uo pipefail

USER_NAME="${USER_NAME:-baofanting}"
BUILD=/home/$USER_NAME/marble-build
LOG=/mnt/e/Cache/shuaji/logs/30-pmbootstrap.log
exec > >(tee -a "$LOG") 2>&1

echo "### [$(date -Is)] pmbootstrap install start"

cd "$BUILD"

if [ -d pmbootstrap/.git ]; then
    echo "pmbootstrap: already cloned"
else
    for attempt in 1 2 3; do
        echo "### clone pmbootstrap attempt $attempt"
        if git -c http.version=HTTP/1.1 clone --depth 1 \
               https://gitlab.nura.eco/postmarketOS/pmbootstrap.git pmbootstrap; then
            break
        fi
        rm -rf pmbootstrap
        sleep 5
    done
fi

if [ ! -d pmbootstrap/.git ]; then
    echo "### git clone failed, trying tarball"
    mkdir -p pmbootstrap
    curl -fL --retry 3 --max-time 300 -o /tmp/pmb.tar.gz \
        https://gitlab.nura.eco/postmarketOS/pmbootstrap/-/archive/master/pmbootstrap-master.tar.gz \
        && tar -xzf /tmp/pmb.tar.gz -C pmbootstrap --strip-components=1
fi

cd pmbootstrap
echo "### pmbootstrap version info"
git log -1 --format='%H %ad %s' --date=short 2>/dev/null
grep -m1 -E '__version__|version' pmb/__init__.py 2>/dev/null

chown -R "$USER_NAME:$USER_NAME" "$BUILD"

# Install as a symlink into the user's ~/.local/bin
su - "$USER_NAME" -c '
set -e
mkdir -p ~/.local/bin
chmod +x ~/marble-build/pmbootstrap/pmbootstrap.py
ln -sf ~/marble-build/pmbootstrap/pmbootstrap.py ~/.local/bin/pmbootstrap
export PATH="$HOME/.local/bin:$PATH"
pmbootstrap --version
'

echo "### [$(date -Is)] pmbootstrap install done"
