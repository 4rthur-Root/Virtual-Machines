#!/usr/bin/env bash
#
# setup-box.sh - Copies the Ubuntu box from the external drive and registers
# it with Vagrant. Run once (or if the box was removed from
# `vagrant box list`).
#
# The box itself (dfir-ubuntu-base.box) is backed up on an external drive.
# The Packer template that produced it lives in another repo - see the README.md
# in this folder for the full rebuild if the box is ever lost.
#
# Usage: ./setup-box.sh /path/to/dfir-ubuntu-base.box
#
set -euo pipefail

BOX_NAME="dfir-ubuntu-base"
LOCAL_BOX_DIR="${HOME}/Downloads/ISO"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /path/to/dfir-ubuntu-base.box"
    echo "  (e.g. path to the mounted external drive)"
    exit 1
fi

SOURCE_BOX="$1"

if [[ ! -f "$SOURCE_BOX" ]]; then
    echo "ERROR: file not found: $SOURCE_BOX"
    exit 1
fi

if vagrant box list 2>/dev/null | awk '{print $1}' | grep -Fxq "$BOX_NAME"; then
    echo "Box '$BOX_NAME' is already registered with Vagrant."
    vagrant box list | grep "$BOX_NAME"
    read -rp "Re-register anyway? (y/N) " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

echo "[1/2] Local copy of the box..."
mkdir -p "$LOCAL_BOX_DIR"
LOCAL_COPY="${LOCAL_BOX_DIR}/${BOX_NAME}.box"
if [[ -f "$LOCAL_COPY" ]]; then
    echo "      Box already present in $LOCAL_BOX_DIR, skipping copy."
else
    cp "$SOURCE_BOX" "$LOCAL_COPY"
fi

echo "[2/2] Registering with Vagrant..."
vagrant box add "$BOX_NAME" "$LOCAL_COPY" --force

echo ""
echo "=== Box ready ==="
vagrant box list | grep "$BOX_NAME"
