#!/usr/bin/env bash
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

echo "Running as root, continuing..."

chmod 444 debian-13-generic-amd64-20251117-2299.qcow2
chmod 444 host3-gold-image.qcow2
chmod 444 host4-gold-image.qcow2
chmod 444 *.xml

chown libvirt-qemu:kvm *.qcow2

# net12
if ! virsh net-list --all --name | grep -qw net12; then
	virsh net-define net12.xml
	virsh net-autostart net12
	virsh net-start net12
else
    echo "net12 already exists"
fi

# net23
if ! virsh net-list --all --name | grep -qw net23; then
	virsh net-define net23.xml
	virsh net-autostart net23
	virsh net-start net23
else
    echo "net23 already exists"
fi

# net34
if ! virsh net-list --all --name | grep -qw net34; then
	virsh net-define net34.xml
	virsh net-autostart net34
	virsh net-start net34
else
    echo "net34 already exists"
fi

if ! virsh list --all --name | grep -qw host3; then
	qemu-img create -f qcow2 -F qcow2 -b host3-gold-image.qcow2 host3-work.qcow2 20G
	chown libvirt-qemu:kvm host3-work.qcow2
	virt-install \
	  --name host3 \
	  --memory 2048 \
	  --vcpus 2 \
	  --disk path=host3-work.qcow2,format=qcow2,bus=virtio \
	  --os-variant debian13 \
	  --network network=net23,model=virtio \
	  --network network=net34,model=virtio \
	  --import \
	  --noautoconsole \
	  --console pty,target_type=serial 
else
    echo "VM host3 already exists"
fi

if ! virsh list --all --name | grep -qw host4; then
	qemu-img create -f qcow2 -F qcow2 -b host4-gold-image.qcow2 host4-work.qcow2 20G
	chown libvirt-qemu:kvm host4-work.qcow2
	virt-install \
	  --name host4 \
	  --memory 2048 \
	  --vcpus 2 \
	  --disk path=host4-work.qcow2,format=qcow2,bus=virtio \
	  --os-variant debian13 \
	  --network network=net34,model=virtio \
	  --import \
	  --noautoconsole \
	  --console pty,target_type=serial 
else
    echo "VM host4 already exists"
fi
