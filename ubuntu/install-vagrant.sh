#!/usr/bin/env bash
#
# install-vagrant.sh - Installs Vagrant + the vagrant-libvirt plugin.
#
# Prerequisites: libvirt/KVM already in place (see bootstrap-host.sh at the repo
# root - this script only handles Vagrant, not libvirt).
#
# Packer is not installed here: the Packer template that builds the Ubuntu
# box lives in another repo, separate from this one (see README.md).
#
set -euo pipefail

VAGRANT_VERSION="2.4.9"

fail() {
    echo "[ERROR] $*" >&2
    exit 1
}

detect_architecture() {
    case "$(uname -m)" in
        x86_64|amd64) echo "x86_64" ;;
        aarch64|arm64) echo "aarch64" ;;
        *) fail "Unsupported architecture: $(uname -m)" ;;
    esac
}

detect_package_manager() {
    if command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    else
        fail "Unsupported package manager (expected dnf/apt)."
    fi
}

PACKAGE_MANAGER="$(detect_package_manager)"

echo "=== Installing Vagrant ${VAGRANT_VERSION} + vagrant-libvirt plugin ==="
echo ""

# --- 1. Vagrant ---
echo "[1/3] Vagrant..."
if command -v vagrant &>/dev/null; then
    INSTALLED=$(vagrant --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
    if [[ "$INSTALLED" == "$VAGRANT_VERSION" ]]; then
        echo "      OK (already at version ${VAGRANT_VERSION})"
    else
        echo "      Installed version: ${INSTALLED:-unknown} - updating to ${VAGRANT_VERSION}..."
        ARCH="$(detect_architecture)"
        if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
            DEB_FILE="/tmp/vagrant_${VAGRANT_VERSION}_${ARCH}.deb"
            wget -q "https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_${ARCH}.deb" -O "$DEB_FILE"
            sudo apt-get install -y "$DEB_FILE"
            rm -f "$DEB_FILE"
        else
            RPM_FILE="/tmp/vagrant-${VAGRANT_VERSION}-1.${ARCH}.rpm"
            wget -q "https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant-${VAGRANT_VERSION}-1.${ARCH}.rpm" -O "$RPM_FILE"
            sudo dnf install -y "$RPM_FILE"
            rm -f "$RPM_FILE"
        fi
    fi
else
    echo "      Installing Vagrant ${VAGRANT_VERSION}..."
    ARCH="$(detect_architecture)"
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        DEB_FILE="/tmp/vagrant_${VAGRANT_VERSION}_${ARCH}.deb"
        wget -q "https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_${ARCH}.deb" -O "$DEB_FILE"
        sudo apt-get install -y "$DEB_FILE"
        rm -f "$DEB_FILE"
    else
        RPM_FILE="/tmp/vagrant-${VAGRANT_VERSION}-1.${ARCH}.rpm"
        wget -q "https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant-${VAGRANT_VERSION}-1.${ARCH}.rpm" -O "$RPM_FILE"
        sudo dnf install -y "$RPM_FILE"
        rm -f "$RPM_FILE"
    fi
fi

# --- 2. Build dependencies for vagrant-libvirt ---
echo "[2/3] Build dependencies (gcc, ruby-devel, libvirt-devel...)..."
if [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
    sudo dnf install -y gcc make libvirt-devel libxml2-devel ruby-devel libguestfs-tools
else
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gcc make libvirt-dev libxml2-dev ruby-dev libguestfs-tools
fi

# --- 3. vagrant-libvirt plugin ---
echo "[3/3] vagrant-libvirt plugin..."
if vagrant plugin list 2>/dev/null | grep -q 'vagrant-libvirt'; then
    echo "      OK (already installed)"
else
    vagrant plugin install vagrant-libvirt
fi

echo ""
echo "=== Done, Vagrant and its libvirt plugin are now installed properly  ==="
vagrant --version
vagrant plugin list 2>/dev/null | grep libvirt || echo "vagrant-libvirt: NOT INSTALLED"
