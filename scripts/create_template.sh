#!/bin/bash
set -euo pipefail

# ============================================================
# Proxmox VM Template Creator — Ubuntu 22.04 (Jammy) Cloud Image
# Run this script directly on your Proxmox host as root.
# ============================================================

# --- Configuration (CHANGE THESE) ---
TEMPLATE_ID=9000
TEMPLATE_NAME="ubuntu-template"
STORAGE="local-lvm"          # Run 'pvesm status' to check yours
BRIDGE="vmbr0"               # Run 'ip a' or check Proxmox UI
MEMORY=2048
CORES=2
USERNAME="rias"
SSH_KEY_PATH="/root/.ssh/id_rsa.pub"  # Path to your PUBLIC key on the Proxmox host
IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
IMAGE_FILE="jammy-server-cloudimg-amd64.img"

# --- 1. Install dependencies ---
echo ">>> Installing dependencies..."
apt update && apt install -y libguestfs-tools

# --- 2. Download cloud image ---
if [ ! -f "$IMAGE_FILE" ]; then
    echo ">>> Downloading Ubuntu 22.04 cloud image..."
    wget "$IMAGE_URL"
else
    echo ">>> Image already downloaded, skipping."
fi

# --- 3. Customize the image ---
echo ">>> Customizing image..."

# Install qemu-guest-agent (required for Proxmox/Terraform communication)
# Also ensuring cloud-init is installed
virt-customize -a "$IMAGE_FILE" --install qemu-guest-agent,cloud-init

# Create user with sudo rights
virt-customize -a "$IMAGE_FILE" \
    --run-command "useradd -m -s /bin/bash $USERNAME" \
    --run-command "usermod -aG sudo $USERNAME" \
    --run-command "echo '$USERNAME ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$USERNAME"

# Optional: Install fish shell
virt-customize -a "$IMAGE_FILE" \
    --run-command "apt-add-repository ppa:fish-shell/release-3 --yes" \
    --install fish \
    --run-command "chsh -s /usr/bin/fish $USERNAME"

# Update all packages
virt-customize -a "$IMAGE_FILE" --update

# --- 4. Create the Proxmox VM ---
echo ">>> Creating VM $TEMPLATE_ID..."

# Destroy existing template if it exists (safety)
qm destroy "$TEMPLATE_ID" --purge 2>/dev/null || true

qm create "$TEMPLATE_ID" \
    --name "$TEMPLATE_NAME" \
    --memory "$MEMORY" \
    --cores "$CORES" \
    --net0 "virtio,bridge=$BRIDGE" \
    --ostype l26

# Import disk
echo ">>> Importing disk to $STORAGE..."
qm importdisk "$TEMPLATE_ID" "$IMAGE_FILE" "$STORAGE"

# Attach disk and configure hardware
qm set "$TEMPLATE_ID" --scsihw virtio-scsi-pci --scsi0 "$STORAGE:vm-${TEMPLATE_ID}-disk-0"
qm set "$TEMPLATE_ID" --boot order=scsi0
qm set "$TEMPLATE_ID" --ide2 "$STORAGE:cloudinit"
qm set "$TEMPLATE_ID" --serial0 socket --vga serial0
qm set "$TEMPLATE_ID" --agent enabled=1

# --- 5. Configure Cloud-Init ---
echo ">>> Configuring cloud-init..."
qm set "$TEMPLATE_ID" --ciuser "$USERNAME"
qm set "$TEMPLATE_ID" --ipconfig0 "ip=dhcp"

# Set SSH key (if file exists)
if [ -f "$SSH_KEY_PATH" ]; then
    qm set "$TEMPLATE_ID" --sshkeys "$SSH_KEY_PATH"
    echo ">>> SSH key loaded from $SSH_KEY_PATH"
else
    echo "⚠️  WARNING: SSH key not found at $SSH_KEY_PATH"
    echo "   You can set it later with: qm set $TEMPLATE_ID --sshkeys /path/to/key.pub"
fi

# --- 6. Convert to template ---
echo ">>> Converting to template..."
qm template "$TEMPLATE_ID"

# --- 7. Cleanup ---
echo ">>> Cleaning up image file..."
rm -f "$IMAGE_FILE"

echo ""
echo "✅ Template '$TEMPLATE_NAME' (ID: $TEMPLATE_ID) created successfully!"
echo ""
echo "Usage:"
echo "  Clone (full):  qm clone $TEMPLATE_ID <NEW_ID> --name my-vm --full"
echo "  Clone (linked): qm clone $TEMPLATE_ID <NEW_ID> --name my-vm"
echo "  Then start:     qm start <NEW_ID>"
echo "  SSH:            ssh $USERNAME@<VM_IP>"
