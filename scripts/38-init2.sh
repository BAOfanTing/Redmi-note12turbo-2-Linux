#!/usr/bin/env bash
set -uo pipefail
cd /home/baofanting/marble-build/pmbootstrap
sed -n '200,460p' pmb/config/init.py
