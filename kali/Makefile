# Makefile for Kali VM Management
#
# Usage:
#   make start          # Start default VM (kali)
#   make recreate       # Recreate default VM (kali) - Interactive
#   make new            # Create a new VM - Interactive
#   make destroy        # Destroy default VM (kali) - Interactive
#   make help           # Show this help

.PHONY: start recreate new destroy clean help

start:
	@echo "Starting Kali VM..."
	@./start-kali.sh start $(NAME) $(RAM) $(VCPUS)

recreate:
	@echo "Recreating Kali VM..."
	@./start-kali.sh recreate $(NAME) $(RAM) $(VCPUS)

new:
	@echo "Creating new Kali VM..."
	@./start-kali.sh new $(NAME) $(RAM) $(VCPUS)

destroy:
	@echo "Destroying Kali VM..."
	@./start-kali.sh destroy $(NAME)

clean:
	@echo "Cleaning up (destroying VM and disk)..."
	@./start-kali.sh destroy $(NAME) 2>/dev/null || true
	@rm -f /home/vms/kali/kali.qcow2
	@echo "Cleaned."

help:
	@echo "=== Kali VM Makefile ==="
	@echo ""
	@echo "Basic Commands:"
	@echo "  make start       - Start the VM (default name: kali)"
	@echo "  make recreate    - Recreate the VM (default name: kali)"
	@echo "  make new         - Create a NEW VM with a custom name"
	@echo "  make destroy     - Destroy the VM (default name: kali)"
	@echo "  make clean       - Destroy VM AND delete the disk image"
	@echo "  make help        - Show this help"
	@echo ""
	@echo "Advanced Usage (override defaults):"
	@echo "  make start NAME=myvm RAM=8192 VCPUS=4"
	@echo "  make recreate NAME=kali-test RAM=4096"
	@echo ""
	@echo "Interactive Mode:"
	@echo "  If no NAME/RAM/VCPUS are provided, the script will ask you interactively."
	@echo "  Example: make recreate (asks for Name, RAM, CPU)"
	@echo ""
	@echo "Direct Script Usage:"
	@echo "  ./start-kali.sh [start|recreate|new|destroy] [name] [ram] [vcpus]"