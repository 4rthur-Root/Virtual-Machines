#!/usr/bin/env bash
#
# setup-template.sh - Downloads and sets up the Debian cloud image template.
# Run once (or after losing the template).
#
# Usage: ./setup-template.sh
#
set -euo pipefail

POOL_DIR="/home/vms"
TEMPLATE_DIR="${POOL_DIR}/templates"
TEMPLATE_NAME="debian-13-genericcloud-amd64.qcow2"
TEMPLATE_PATH="${TEMPLATE_DIR}/${TEMPLATE_NAME}"
DEBIAN_URL="https://cloud.debian.org/images/cloud/trixie/latest/${TEMPLATE_NAME}"
CURRENT_USER="${SUDO_USER:-$USER}"

echo "=== Setting up Debian 13 template (genericcloud) ==="
echo ""

if [[ -f "$TEMPLATE_PATH" ]]; then
    echo "Template already present: $TEMPLATE_PATH"
    qemu-img info "$TEMPLATE_PATH"
    read -rp "Re-download and overwrite? (y/N) " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Cancelled."
        exit 0
    fi
    chmod u+w "$TEMPLATE_PATH"
fi

echo "[1/3] Checking storage pool..."
if [[ ! -d "$TEMPLATE_DIR" ]]; then
    echo "ERROR: $TEMPLATE_DIR does not exist."
    echo "  Run bootstrap-host.sh at the repo root first."
    exit 1
fi

echo "[2/3] Downloading from $DEBIAN_URL ..."
wget -O "$TEMPLATE_PATH" "$DEBIAN_URL"

echo "[3/3] Securing template (ownership + read-only)..."
sudo chown "${CURRENT_USER}:qemu" "$TEMPLATE_PATH"
chmod 444 "$TEMPLATE_PATH"

echo ""
echo "=== Template ready ==="
qemu-img info "$TEMPLATE_PATH"
echo ""
echo "Note: virtual size is intentionally small (~3G)."
echo "vm-create.sh resizes each clone individually, never the template."
