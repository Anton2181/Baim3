#!/usr/bin/env bash
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

echo "Running as root, continuing..."

chmod 444 debian-13-generic-amd64-20251117-2299.qcow2
chmod 444 host0-gold-image.qcow2 2>/dev/null || true
chmod 444 host1-gold-image.qcow2 2>/dev/null || true
chmod 444 host2-gold-image.qcow2 2>/dev/null || true
chmod 444 host3-gold-image.qcow2
chmod 444 host4-gold-image.qcow2
chmod 444 *.xml

chown libvirt-qemu:kvm *.qcow2

# net01
if ! virsh net-list --all --name | grep -qw net01; then
	virsh net-define net01.xml
	virsh net-autostart net01
	virsh net-start net01
else
    echo "net01 already exists"
fi

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

if [ -f host0-gold-image.qcow2 ] && ! virsh list --all --name | grep -qw host0; then
	qemu-img create -f qcow2 -F qcow2 -b host0-gold-image.qcow2 host0-work.qcow2 20G
	chown libvirt-qemu:kvm host0-work.qcow2
	virt-install \
	  --name host0 \
	  --memory 2048 \
	  --vcpus 2 \
	  --disk path=host0-work.qcow2,format=qcow2,bus=virtio \
	  --os-variant debian13 \
	  --network network=default,model=virtio \
	  --network network=net01,model=virtio \
	  --import \
	  --noautoconsole \
	  --console pty,target_type=serial
elif [ -f host0-gold-image.qcow2 ]; then
    echo "VM host0 already exists"
else
    echo "host0-gold-image.qcow2 not found, skipping host0"
fi

if [ -f host1-gold-image.qcow2 ] && ! virsh list --all --name | grep -qw host1; then
	qemu-img create -f qcow2 -F qcow2 -b host1-gold-image.qcow2 host1-work.qcow2 20G
	chown libvirt-qemu:kvm host1-work.qcow2
	virt-install \
	  --name host1 \
	  --memory 4096 \
	  --vcpus 2 \
	  --disk path=host1-work.qcow2,format=qcow2,bus=virtio \
	  --os-variant debian13 \
	  --network network=net01,model=virtio \
	  --network network=net12,model=virtio \
	  --import \
	  --noautoconsole \
	  --console pty,target_type=serial
elif [ -f host1-gold-image.qcow2 ]; then
    echo "VM host1 already exists"
else
    echo "host1-gold-image.qcow2 not found, skipping host1"
fi

if [ -f host2-gold-image.qcow2 ] && ! virsh list --all --name | grep -qw host2; then
	qemu-img create -f qcow2 -F qcow2 -b host2-gold-image.qcow2 host2-work.qcow2 20G
	chown libvirt-qemu:kvm host2-work.qcow2
	virt-install \
	  --name host2 \
	  --memory 2048 \
	  --vcpus 2 \
	  --disk path=host2-work.qcow2,format=qcow2,bus=virtio \
	  --os-variant debian13 \
	  --network network=net12,model=virtio \
	  --network network=net23,model=virtio \
	  --import \
	  --noautoconsole \
	  --console pty,target_type=serial
elif [ -f host2-gold-image.qcow2 ]; then
    echo "VM host2 already exists"
else
    echo "host2-gold-image.qcow2 not found, skipping host2"
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
