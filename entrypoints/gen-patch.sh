#!/usr/bin/env bash
set -Eeuo pipefail

PATCH_DIR="../patches/"

cd openvpn
git fetch --prune
git fetch --all --tags
git checkout "tags/v$TO_VERSION"
patch -p1 < "$PATCH_DIR/openvpn-v$FROM_VERSION-aws.patch"
git diff > "$PATCH_DIR/openvpn-v$TO_VERSION-aws.patch"
