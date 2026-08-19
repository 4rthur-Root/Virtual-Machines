#!/usr/bin/env bash
#
# setup-kali.sh - Downloads the official Kali QEMU image (.7z), extracts it,
# and sets it up for direct boot via libvirt.
#
# No COW clone here: Kali is treated as a ready-to-use VM,
# disposable (destroyed/recreated at will), not as a template to clone.
#
# Usage: ./setup-kali.sh [version]
# Example: ./setup-kali.sh 2026.2
#
set -euo pipefail
 
ISO_DIR="${HOME}/Downloads/ISO"
KALI_DIR="/home/vms/kali"
VERSION="${1:-2026.2}"
ARCHIVE_NAME="kali-linux-${VERSION}-qemu-amd64.7z"
QCOW2_NAME="kali-linux-${VERSION}-qemu-amd64.qcow2"
KALI_URL="https://cdimage.kali.org/kali-${VERSION}/${ARCHIVE_NAME}"

echo "=== Setting up Kali Linux ${VERSION} (official QEMU image) ==="
echo ""

if ! command -v 7z &>/dev/null && ! command -v 7za &>/dev/null; then
    echo "ERROR: p7zip is not installed (required to extract .7z)"
    echo "  -> sudo dnf install -y p7zip p7zip-plugins"
    exit 1
fi
SEVENZIP=$(command -v 7z || command -v 7za)

mkdir -p "$ISO_DIR" "$KALI_DIR"

if [[ -f "${KALI_DIR}/kali.qcow2" ]]; then
    echo "A Kali image already exists: ${KALI_DIR}/kali.qcow2"
    read -rp "Re-download and overwrite? (y/N) " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

if [[ -f "${ISO_DIR}/${ARCHIVE_NAME}" ]]; then
    echo "Archive already here: ${ISO_DIR}/${ARCHIVE_NAME}"
    read -rp "Download again ? (y/N) " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Verifying existing archive integrity..."
        if ! "$SEVENZIP" t "${ISO_DIR}/${ARCHIVE_NAME}" >/dev/null 2>&1; then
            echo "      Archive is corrupted. Removing and re-downloading..."
            rm -f "${ISO_DIR}/${ARCHIVE_NAME}"
        else
            echo "      Archive OK."
        fi
    else
        rm -f "${ISO_DIR}/${ARCHIVE_NAME}"
    fi
fi

echo "[1/4] Downloading or Using from $KALI_URL ..."
if [[ ! -f "${ISO_DIR}/${ARCHIVE_NAME}" ]]; then
    wget -O "${ISO_DIR}/${ARCHIVE_NAME}" "$KALI_URL"
fi

echo "[2/4] Extracting .7z archive..."
"$SEVENZIP" x "${ISO_DIR}/${ARCHIVE_NAME}" -o"${ISO_DIR}" -y >/dev/null

if [[ ! -f "${ISO_DIR}/${QCOW2_NAME}" ]]; then
    echo "ERROR: expected qcow2 not found after extraction: ${ISO_DIR}/${QCOW2_NAME}"
    echo "  Check extracted contents in $ISO_DIR"
    exit 1
fi

echo "[3/4] Moving to libvirt location ($KALI_DIR)..."
mv "${ISO_DIR}/${QCOW2_NAME}" "${KALI_DIR}/kali.qcow2"
chmod 644 "${KALI_DIR}/kali.qcow2"

echo "[4/4] Cleaning up downloaded archive..."
rm -f "${ISO_DIR}/${ARCHIVE_NAME}"

echo ""
echo "=== Kali ready ==="
qemu-img info "${KALI_DIR}/kali.qcow2"
echo ""
echo "To start it:"
echo "  ./start-kali.sh"
echo ""
echo "Default Kali credentials (change if you expose the VM): kali / kali"
