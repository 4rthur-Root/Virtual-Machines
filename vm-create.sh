#!/usr/bin/env bash
#
# vm-create.sh - Create a throwable Debian VM via COW clone + cloud-init
#
# Use: ./vm-create.sh <name> <ram_mb> <vcpus>
# Example: ./vm-create.sh mydebian 2048 2
#
set -euo pipefail

# Configuration - fixed paths of the environment
POOL_DIR="/home/vms"
TEMPLATE="${POOL_DIR}/templates/debian-13-genericcloud-amd64.qcow2"
SSH_KEY="${HOME}/.ssh/lab_vms.pub"
SSH_USER="adrien"
DEFAULT_DISK_SIZE="20G"
OS_VARIANT="debian12"   # not a debian13 profile yet in osinfo-db

# Verifying the arguments
if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <name> <ram_mb> <vcpus>"
    echo "Example: $0 webtest 2048 2"
    exit 1
fi

VM_NAME="$1"
RAM_MB="$2"
VCPUS="$3"

# Preliminary checks — fail fast and clearly rather than crash
# in the middle of a creation step
if [[ "${LIBVIRT_DEFAULT_URI:-}" != "qemu:///system" ]]; then
    echo "ERROR: LIBVIRT_DEFAULT_URI is not set to qemu:///system"
    echo "  Add this to your ~/.zshrc or ~/.bashrc:"
    echo '  export LIBVIRT_DEFAULT_URI="qemu:///system"'
    exit 1
fi

if [[ ! -f "$TEMPLATE" ]]; then
    echo "ERROR: template not found: $TEMPLATE"
    exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
    echo "ERROR: public SSH key not found: $SSH_KEY"
    exit 1
fi

if virsh dominfo "$VM_NAME" &>/dev/null; then
    echo "ERROR: a VM named '$VM_NAME' already exists"
    echo "  Destroy it first : virsh destroy $VM_NAME && virsh undefine $VM_NAME"
    exit 1
fi

DISK_PATH="${POOL_DIR}/${VM_NAME}.qcow2"
CIDATA_ISO="${POOL_DIR}/${VM_NAME}-cidata.iso"

if [[ -f "$DISK_PATH" ]]; then
    echo "ERROR: disk file already exists: $DISK_PATH"
    exit 1
fi

# Step 1 — COW clone from read-only template
echo "[1/5] COW clone from template..."
qemu-img create -f qcow2 -b "$TEMPLATE" -F qcow2 "$DISK_PATH" >/dev/null
qemu-img resize "$DISK_PATH" "$DEFAULT_DISK_SIZE" >/dev/null
echo "      -> $DISK_PATH (${DEFAULT_DISK_SIZE} virtual)"

# Step 2 — Generate user-data / meta-data
echo "[2/5] Generating cloud-init config..."

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

SSH_PUBKEY=$(cat "$SSH_KEY")
INSTANCE_ID="$(date +%s)-${VM_NAME}"

cat > "${WORKDIR}/user-data" << EOF
#cloud-config
hostname: ${VM_NAME}
manage_etc_hosts: true

users:
  - name: ${SSH_USER}
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - ${SSH_PUBKEY}

ssh_pwauth: false
disable_root: true

package_update: false
EOF

cat > "${WORKDIR}/meta-data" << EOF
instance-id: ${INSTANCE_ID}
local-hostname: ${VM_NAME}
EOF

# Step 3 — Package into cidata ISO
echo "[3/5] Creating cidata ISO..."
genisoimage -output "$CIDATA_ISO" \
    -volid cidata -joliet -rock \
    "${WORKDIR}/user-data" "${WORKDIR}/meta-data" >/dev/null 2>&1
echo "      -> $CIDATA_ISO"

# Step 4 — Define and start VM
echo "[4/5] Starting VM..."
virt-install \
    --name "$VM_NAME" \
    --memory "$RAM_MB" \
    --vcpus "$VCPUS" \
    --disk "${DISK_PATH},bus=virtio" \
    --disk "${CIDATA_ISO},device=cdrom" \
    --os-variant "$OS_VARIANT" \
    --network network=default,model=virtio \
    --graphics none \
    --import \
    --noautoconsole >/dev/null

# Step 5 — Waiting for IP (poll with timeout)
echo "[5/5] Waiting for IP address (timeout 60s)..."
IP=""
for i in $(seq 1 30); do
    IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | awk '/ipv4/{print $4}' | cut -d/ -f1)
    if [[ -n "$IP" ]]; then
        break
    fi
    sleep 2
done

echo ""
if [[ -n "$IP" ]]; then
    echo "✓ VM '$VM_NAME' ready"
    echo "  IP:  $IP"
    echo "  SSH: ssh -i ${SSH_KEY%.pub} ${SSH_USER}@${IP}"
else
    echo "⚠ VM created but no IP obtained after 60s."
    echo "  Check manually : virsh domifaddr $VM_NAME"
    echo "  Cloud-init may still be running — try again in a few seconds."
fi
