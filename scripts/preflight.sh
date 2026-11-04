#!/usr/bin/env bash
set -euo pipefail

: "${FOX_BRANCH:=12.1}"
: "${DEVICE_TREE_BRANCH:=11}"
: "${DEVICE_TREE_REPO:=https://github.com/NeonzDump/twrp_infinix_X688B.git}"
: "${DEVICE:=X688B}"

echo "== X688B OrangeFox preflight =="
echo "Device: $DEVICE"
echo "OrangeFox: fox_$FOX_BRANCH"
echo "Tree: $DEVICE_TREE_REPO ($DEVICE_TREE_BRANCH)"
echo
echo "IMPORTANT:"
echo "The known public X688B tree is a TWRP Android 11 tree."
echo "It is not documented as an OrangeFox-maintained/validated tree."
echo "A successful compile does NOT prove that recovery boots or works."
echo
echo "OrangeFox fox_12.1 build sources require substantial disk space."
echo "GitHub standard hosted runners may run out of disk."
