#!/usr/bin/env bash
set -euo pipefail

cd twrp

source build/envsetup.sh
lunch twrp_X688B-eng

mka -j2 recoveryimage