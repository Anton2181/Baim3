#!/usr/bin/env bash
set -euo pipefail

### ----- ROOT CHECK -----
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

### ----- BASE IMAGE -----
BASE_IMAGE="debian-13-generic-amd64-20251117-2299.qcow2"

if [ ! -f "$BASE_IMAGE" ]; then
    echo "Base image not found: $BASE_IMAGE"
    exit 1
fi

### ----- INPUTS -----
VM_NAME="${1:-}"
ROOT_PASS="${2:-}"
shift 2 || true
NETWORKS=("$@")

# VM name
if [ -z "$VM_NAME" ]; then
    read -rp "Enter VM hostname/name: " VM_NAME
fi

if [ -z "$VM_NAME" ]; then
    echo "VM name cannot be empty"
    exit 1
fi

# Root password
if [ -z "$ROOT_PASS" ]; then
    read -rsp "Enter root password: " ROOT_PASS
    echo
fi

if [ -z "$ROOT_PASS" ]; then
    echo "Root password cannot be empty"
    exit 1
fi

# Networks
if [ "${#NETWORKS[@]}" -eq 0 ]; then
    read -rp "Enter networks (space-separated) [default]: " -a NETWORKS
fi

# Default network if empty
if [ "${#NETWORKS[@]}" -eq 0 ]; then
    NETWORKS=("default")
fi

### ----- VALIDATE NETWORKS -----
for net in "${NETWORKS[@]}"; do
    if ! virsh net-list --all --name | grep -qw "$net"; then
        echo "Network '$net' does not exist"
        exit 1
    fi
done

### ----- CHECK VM EXISTS -----
if virsh list --all --name | grep -qw "$VM_NAME"; then
    echo "VM '$VM_NAME' already exists"
    exit 0
fi

### ----- CREATE DISK -----
WORK_DISK="${VM_NAME}-gold-image.qcow2"

echo "Creating disk: $WORK_DISK"
qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMAGE" "$WORK_DISK" 20G
chown libvirt-qemu:kvm "$WORK_DISK"

### ----- CUSTOMIZE IMAGE -----
echo "Customizing image (hostname + root password)"
virt-customize \
    -a "$WORK_DISK" \
    --hostname "$VM_NAME" \
    --root-password "password:$ROOT_PASS"

### ----- BUILD NETWORK FLAGS -----
NET_ARGS=()
for net in "${NETWORKS[@]}"; do
    NET_ARGS+=(--network "network=$net,model=virtio")
done

### ----- CREATE VM -----
echo "Creating VM '$VM_NAME' with networks: ${NETWORKS[*]}"
virt-install \
    --name "$VM_NAME" \
    --memory 2048 \
    --vcpus 2 \
    --disk "path=$WORK_DISK,format=qcow2,bus=virtio" \
    --os-variant debian13 \
    "${NET_ARGS[@]}" \
    --import \
    --noautoconsole \
    --console pty,target_type=serial

echo
echo "✅ VM '$VM_NAME' created successfully"
echo "   Networks: ${NETWORKS[*]}"
