#!/usr/bin/env bash
#
# start-kali.sh - Starts (or restarts) the Kali VM from the official QEMU image
# already in place (see setup-kali.sh).
#
# Important: Kali pre-built QEMU images use BIOS/SeaBIOS,
# not UEFI. Do not add --boot uefi here, it would prevent booting.
#
# Usage: ./start-kali.sh [ram_mb] [vcpus]
#
set -euo pipefail

KALI_DIR="/home/vms/kali"
DISK_PATH="${KALI_DIR}/kali.qcow2"
VM_NAME="kali"
RAM_MB="${1:-4096}"
VCPUS="${2:-2}"

if [[ "${LIBVIRT_DEFAULT_URI:-}" != "qemu:///system" ]]; then
    echo "ERROR: LIBVIRT_DEFAULT_URI is not set to qemu:///system"
    exit 1
fi

if [[ ! -f "$DISK_PATH" ]]; then
    echo "ERROR: Kali image not found: $DISK_PATH"
    echo "  Run ./setup-kali.sh first"
    exit 1
fi

# If the VM already exists and is stopped, simply restart it
if virsh dominfo "$VM_NAME" &>/dev/null; then
    STATE=$(virsh domstate "$VM_NAME")
    if [[ "$STATE" == "running" ]]; then
        echo "Kali is already running."
        virsh domifaddr "$VM_NAME"
        exit 0
    fi
    echo "Existing Kali VM found (stopped) - starting..."
    virsh start "$VM_NAME"
else
    echo "First creation of the Kali VM..."
    virt-install \
        --name "$VM_NAME" \
        --memory "$RAM_MB" \
        --vcpus "$VCPUS" \
        --disk "${DISK_PATH},bus=virtio" \
        --os-variant debian12 \
        --boot bios \
        --network network=default,model=virtio \
        --graphics none \
        --import \
        --noautoconsole >/dev/null
fi

echo "Waiting for IP (timeout 60s)..."
IP=""
for i in $(seq 1 30); do
    IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | awk '/ipv4/{print $4}' | cut -d/ -f1)
    [[ -n "$IP" ]] && break
    sleep 2
done

echo ""
if [[ -n "$IP" ]]; then
    echo "✓ Kali ready - IP: $IP"
    echo "  ssh kali@${IP}   (default password: kali)"
else
    echo "⚠ No IP obtained after 60s. Check: virsh domifaddr $VM_NAME"
fi
