#!/usr/bin/env bash
#
# bootstrap-host.sh - Resets the libvirt infrastructure from scratch (or verifies it
# is already correct). Idempotent: safe to rerun on an already configured
# system.
#
# Run once after a fresh Fedora install (or after a kernel panic that wiped everything).
#
# Usage: ./bootstrap-host.sh
#
set -euo pipefail

POOL_NAME="vms"
POOL_DIR="/home/vms"
CURRENT_USER="${SUDO_USER:-$USER}"

detect_rc_file() {
    local shell="${SHELL:-}"
    case "$shell" in
        *zsh) echo "${HOME}/.zshrc" ;;
        *bash) echo "${HOME}/.bashrc" ;;
        *) echo "${HOME}/.profile" ;;
    esac
}

RC_FILE="$(detect_rc_file)"

echo "=== Bootstrapping libvirt infrastructure ==="
echo ""

echo "[1/6] Checking required packages..."
REQUIRED_PKGS=(libvirt-daemon-kvm virt-install genisoimage qemu-img)
MISSING=()
for pkg_check in "${REQUIRED_PKGS[@]}"; do
    if ! rpm -q "$pkg_check" &>/dev/null; then
        MISSING+=("$pkg_check")
    fi
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "      MISSING: ${MISSING[*]}"
    echo "      -> sudo dnf install -y @virtualization genisoimage"
    exit 1
fi
echo "   ✔   OK, all required packages are installed."

echo "[2/6] Checking user groups ($CURRENT_USER)..."
NEEDS_RELOGIN=false
for grp in qemu libvirt; do
    if ! groups "$CURRENT_USER" | grep -qw "$grp"; then
        echo "      Adding $CURRENT_USER to group $grp..."
        sudo usermod -aG "$grp" "$CURRENT_USER"
        NEEDS_RELOGIN=true
    fi
done
if [[ "$NEEDS_RELOGIN" == true ]]; then
    echo "      ! New group(s) added - log out and back in after this script."
else
    echo "   ✔   OK ($CURRENT_USER is already in qemu + libvirt)."
fi

echo "[3/6] Enabling libvirtd..."
sudo systemctl enable --now libvirtd.socket
echo "    ✔  OK, Libvirtd daemon enabled"

echo "[4/6] Ensuring LIBVIRT_DEFAULT_URI=qemu:///system in $RC_FILE..."
if ! grep -q "LIBVIRT_DEFAULT_URI" "$RC_FILE" 2>/dev/null; then
    echo 'export LIBVIRT_DEFAULT_URI="qemu:///system"' >> "$RC_FILE"
    echo "      Added to $RC_FILE."
    if [[ "$RC_FILE" == "${HOME}/.bashrc" || "$RC_FILE" == "${HOME}/.zshrc" ]]; then
        # shellcheck disable=SC1090
        source "$RC_FILE" 2>/dev/null || echo "      Could not source $RC_FILE automatically - please reload your shell."
    fi
else
    echo "   ✔   OK, qemu:///system already configured."
fi
export LIBVIRT_DEFAULT_URI="qemu:///system"

echo "[5/6] Checking 'default' network..."
if ! virsh net-info default &>/dev/null; then
    virsh net-define /usr/share/libvirt/networks/default.xml
fi
if [[ "$(virsh net-info default 2>/dev/null | awk '/^Active:/{print $2}')" != "yes" ]]; then
    virsh net-start default
fi
virsh net-autostart default &>/dev/null
echo "    ✔  OK, default network available !"

echo "[6/6] Checking pool '$POOL_NAME' ($POOL_DIR)..."
if ! virsh pool-info "$POOL_NAME" &>/dev/null; then
    sudo mkdir -p "${POOL_DIR}/templates"
    virsh pool-define-as "$POOL_NAME" dir --target "$POOL_DIR"
    virsh pool-autostart "$POOL_NAME"
    virsh pool-start "$POOL_NAME"
fi
sudo mkdir -p "${POOL_DIR}/templates"
sudo chown -R "${CURRENT_USER}:qemu" "$POOL_DIR"
sudo chmod -R 2775 "$POOL_DIR"
echo "   ✔   OK. Storage pools are available."

echo ""
echo "==== Bootstrap complete with success, here is the breakdown! ===="

echo "==== Available network ===="
virsh net-list --all
echo "==== Available storage pool ===="
virsh pool-list --all
echo ""
if [[ "$NEEDS_RELOGIN" == true ]]; then
    echo "! Reconnect your session (new group added) before continuing."
fi
