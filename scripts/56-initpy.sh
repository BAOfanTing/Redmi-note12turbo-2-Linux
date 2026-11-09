#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap
sed -n '60,140p' pmb/__init__.py
