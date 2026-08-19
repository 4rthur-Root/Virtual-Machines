#!/usr/bin/env bash
#
# new-ubuntu-lab.sh - Creates a new Ubuntu lab folder (Vagrant),
# to allow multiple independent Ubuntu VMs in parallel.
#
# Each created folder contains its own Vagrantfile + Vagrant state
# (.vagrant/), so labs don't interfere with each other.
#
# Usage: ./new-ubuntu-lab.sh [name] [ram_mb] [vcpus]
# If an argument is missing, it will be asked interactively.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABS_ROOT="${SCRIPT_DIR}/labs"
TEMPLATE_VAGRANTFILE="${SCRIPT_DIR}/Vagrantfile"

ask_input() {
    local prompt="$1"
    local default="$2"
    local response
    read -rp "$prompt [$default]: " response
    echo "${response:-$default}"
}

NAME="${1:-}"
RAM="${2:-}"
VCPUS="${3:-}"

if [[ -z "$NAME" ]]; then
    NAME=$(ask_input "Lab name (folder + hostname)" "ubuntu-lab")
fi
if [[ -z "$RAM" ]]; then
    RAM=$(ask_input "RAM in MB" "2048")
fi
if [[ -z "$VCPUS" ]]; then
    VCPUS=$(ask_input "Number of vCPUs" "2")
fi

if ! [[ "$RAM" =~ ^[0-9]+$ ]]; then
    echo "ERROR: RAM must be a number (received: $RAM)"
    exit 1
fi
if ! [[ "$VCPUS" =~ ^[0-9]+$ ]]; then
    echo "ERROR: vCPUs must be a number (received: $VCPUS)"
    exit 1
fi

LAB_DIR="${LABS_ROOT}/${NAME}"

if [[ -d "$LAB_DIR" ]]; then
    echo "ERROR: folder already exists: $LAB_DIR"
    echo "  cd ${LAB_DIR} && VM_NAME=${NAME} VM_RAM=${RAM} VM_CPUS=${VCPUS} vagrant up"
    exit 1
fi

mkdir -p "$LAB_DIR"
cp "$TEMPLATE_VAGRANTFILE" "$LAB_DIR/Vagrantfile"

cat > "${LAB_DIR}/.env" << EOF
export VM_NAME=${NAME}
export VM_RAM=${RAM}
export VM_CPUS=${VCPUS}
EOF

echo ""
echo "=== Lab '$NAME' created ==="
echo "  Folder: $LAB_DIR"
echo ""
echo "To start:"
echo "  cd $LAB_DIR"
echo "  source .env && vagrant up"
echo ""
read -rp "Start now? (y/N) " START_NOW
if [[ "$START_NOW" == "y" || "$START_NOW" == "Y" ]]; then
    cd "$LAB_DIR"
    export VM_NAME="$NAME" VM_RAM="$RAM" VM_CPUS="$VCPUS"
    vagrant up

    # Vagrant peut créer le disque avec des permissions restrictives (600) qui
    # ne respectent pas le setgid du pool - on les corrige après coup.
    sudo chmod 664 /home/vms/${NAME}_default.img 2>/dev/null || true
    sudo chown adrien:qemu /home/vms/${NAME}_default.img 2>/dev/null || true
fi
