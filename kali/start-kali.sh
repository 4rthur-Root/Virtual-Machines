#!/usr/bin/env bash
#
# start-kali.sh - Interactive Kali VM Manager.
#
# Usage:
#   ./start-kali.sh [action] [name] [ram] [vcpus]
#   If [name], [ram], or [vcpus] are missing, it will ask interactively.
#
set -euo pipefail

KALI_DIR="/home/vms/kali"
DISK_PATH="${KALI_DIR}/kali.qcow2"
DEFAULT_RAM="2048"
DEFAULT_VCPUS="2"
DEFAULT_NAME="kali"

# --- Functions ---

ask_input() {
    local prompt="$1"
    local default="$2"
    local response

    if [[ -n "$default" ]]; then
        read -rp "$prompt [$default]: " response
        if [[ -z "$response" ]]; then
            response="$default"
        fi
    else
        read -rp "$prompt: " response
    fi
    echo "$response"
}

check_deps() {
    if ! command -v virsh &>/dev/null; then
        echo "ERROR: virsh not found. Install libvirt-client."
        exit 1
    fi
    if [[ ! -f "$DISK_PATH" ]]; then
        echo "ERROR: Disk image not found: $DISK_PATH"
        echo "Run ./setup-kali.sh first."
        exit 1
    fi
}

create_vm() {
    local name="$1"
    local ram="$2"
    local vcpus="$3"

    # Validate inputs
    if ! [[ "$ram" =~ ^[0-9]+$ ]]; then
        echo "ERROR: RAM must be a number (got: $ram)"
        exit 1
    fi
    if ! [[ "$vcpus" =~ ^[0-9]+$ ]]; then
        echo "ERROR: vCPUs must be a number (got: $vcpus)"
        exit 1
    fi

    echo "Creating VM '$name' with $ram MB RAM and $vcpus vCPUs..."
    
    # Clean up if VM exists
    if virsh dominfo "$name" &>/dev/null; then
        echo "  Removing existing VM definition..."
        if virsh domstate "$name" 2>/dev/null | grep -q running; then
            virsh destroy "$name"
        fi
        virsh undefine "$name"
    fi

    virt-install \
        --name "$name" \
        --memory "$ram" \
        --vcpus "$vcpus" \
        --disk "${DISK_PATH},bus=virtio" \
        --os-variant debian12 \
        --boot hd \
        --network network=default,model=virtio \
        --graphics spice,listen=127.0.0.1 \
        --video virtio \
        --import \
        --noautoconsole >/dev/null

    echo "VM '$name' created successfully."
}

start_vm() {
    local name="$1"
    local ram="$2"
    local vcpus="$3"

    if virsh dominfo "$name" &>/dev/null; then
        if [[ $(virsh domstate "$name" 2>/dev/null) == "running" ]]; then
            echo "VM '$name' is already running."
            virsh domifaddr "$name"
            return 0
        fi
        echo "Starting existing VM '$name'..."
        virsh start "$name"
    else
        echo "VM '$name' not found. Creating new instance..."
        create_vm "$name" "$ram" "$vcpus"
    fi
}

wait_for_ip() {
    local name="$1"
    local timeout=60
    local ip=""
    
    echo "Waiting for IP (timeout ${timeout}s)..."
    for i in $(seq 1 $((timeout / 2))); do
        ip=$(virsh domifaddr "$name" 2>/dev/null | awk '/ipv4/{print $4}' | cut -d/ -f1)
        if [[ -n "$ip" ]]; then
            break
        fi
        sleep 2
    done

    if [[ -n "$ip" ]]; then
        echo "✓ VM '$name' is ready - IP: $ip"
        echo "  SSH: ssh kali@${ip} (pass: kali)"
        echo "  GUI: remote-viewer spice://127.0.0.1"
        
        # Try to enable SSH
        if command -v sshpass &>/dev/null; then
            echo "  Attempting to enable SSH remotely..."
            if sshpass -p "kali" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 kali@${ip} "sudo systemctl enable --now ssh" 2>/dev/null; then
                echo "  ✓ SSH enabled successfully."
            else
                echo "  ⚠ SSH remote enable failed."
                echo "  Please connect via GUI (remote-viewer) or Console and run manually:"
                echo "    sudo systemctl enable --now ssh"
            fi
        else
            echo "  ⚠ sshpass not installed. Cannot enable SSH remotely."
            echo "  Connect via GUI or Console: virsh console $name"
        fi
        return 0
    else
        echo "⚠ No IP obtained after ${timeout}s."
        echo "  Check: virsh domifaddr $name"
        echo "  Try: virsh console $name or remote-viewer spice://127.0.0.1"
        return 1
    fi
}

# --- Main Logic ---

ACTION="${1:-start}"
ARG_NAME="${2:-}"
ARG_RAM="${3:-}"
ARG_VCPUS="${4:-}"

check_deps

# Resolve values (use defaults if empty, or ask if interactive)
# Logic: If ARG is empty, we ask. If ARG is provided, we use it.
# But for 'start' without name, we default to 'kali' immediately.

case "$ACTION" in
    start)
        name="${ARG_NAME:-$DEFAULT_NAME}"
        ram="${ARG_RAM:-$DEFAULT_RAM}"
        vcpus="${ARG_VCPUS:-$DEFAULT_VCPUS}"
        
        # If user didn't provide RAM/VCPUS, and we are creating a new VM, ask?
        # For simplicity in 'start', we just use defaults if missing.
        # If the VM doesn't exist, we create it with defaults.
        
        start_vm "$name" "$ram" "$vcpus"
        wait_for_ip "$name"
        ;;

    recreate)
        # Interactive if missing
        if [[ -z "$ARG_NAME" ]]; then
            name=$(ask_input "VM Name (default: kali)" "$DEFAULT_NAME")
        else
            name="$ARG_NAME"
        fi
        
        if [[ -z "$ARG_RAM" ]]; then
            ram=$(ask_input "RAM in MB (default: 4096)" "$DEFAULT_RAM")
        else
            ram="$ARG_RAM"
        fi

        if [[ -z "$ARG_VCPUS" ]]; then
            vcpus=$(ask_input "Number of vCPUs (default: 2)" "$DEFAULT_VCPUS")
        else
            vcpus="$ARG_VCPUS"
        fi

        create_vm "$name" "$ram" "$vcpus"
        wait_for_ip "$name"
        ;;

    new)
        # Interactive if missing
        if [[ -z "$ARG_NAME" ]]; then
            name=$(ask_input "New VM Name (default: kali-new)" "kali-new")
        else
            name="$ARG_NAME"
        fi
        
        if [[ -z "$ARG_RAM" ]]; then
            ram=$(ask_input "RAM in MB (default: 4096)" "$DEFAULT_RAM")
        else
            ram="$ARG_RAM"
        fi

        if [[ -z "$ARG_VCPUS" ]]; then
            vcpus=$(ask_input "Number of vCPUs (default: 2)" "$DEFAULT_VCPUS")
        else
            vcpus="$ARG_VCPUS"
        fi

        create_vm "$name" "$ram" "$vcpus"
        wait_for_ip "$name"
        ;;

    destroy)
        if [[ -z "$ARG_NAME" ]]; then
            name=$(ask_input "VM Name to destroy (default: kali)" "$DEFAULT_NAME")
        else
            name="$ARG_NAME"
        fi

        if ! virsh dominfo "$name" &>/dev/null; then
            echo "VM '$name' does not exist."
            exit 0
        fi

        echo "VM '$name' found."
        echo "1. Keep disk (remove VM definition only)"
        echo "2. Remove disk (destroy everything)"
        read -rp "Choose [1/2]: " choice

        if [[ "$choice" == "1" ]]; then
            echo "Destroying VM definition (disk kept)..."
            if virsh domstate "$name" 2>/dev/null | grep -q running; then
                virsh destroy "$name"
            fi
            virsh undefine "$name"
            echo "✓ VM destroyed. Disk at $DISK_PATH is safe."
        elif [[ "$choice" == "2" ]]; then
            read -rp "⚠️  Are you SURE you want to DELETE the disk? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo "Destroying VM and disk..."
                if virsh domstate "$name" 2>/dev/null | grep -q running; then
                    virsh destroy "$name"
                fi
                virsh undefine "$name" --remove-all-storage
                rm -f "$DISK_PATH"
                echo "✓ VM and disk deleted."
            else
                echo "Cancelled."
            fi
        else
            echo "Invalid choice."
        fi
        ;;

    *)
        echo "Usage: $0 [start|recreate|new|destroy] [name] [ram] [vcpus]"
        echo "  start: Start existing VM or create if missing."
        echo "  recreate: Destroy and recreate existing VM (or create new)."
        echo "  new: Create a new VM with a custom name."
        echo "  destroy: Destroy VM (with options for disk)."
        echo ""
        echo "Examples:"
        echo "  $0 recreate          # Interactive (asks for Name, RAM, CPU)"
        echo "  $0 recreate mykali   # Non-interactive with name"
        echo "  $0 new kali-test     # Create new VM named 'kali-test'"
        echo "  $0 destroy           # Interactive destroy"
        exit 1
        ;;
esac