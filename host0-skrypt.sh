#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

# ---------------------------
# 1️⃣ Base packages + SSH
# ---------------------------
apt update
apt install -y openssh-server
rm -f /etc/ssh/ssh_host_*
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure openssh-server

sed -i 's/^#\?\s*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

systemctl restart sshd
systemctl restart ssh

# ---------------------------
# 2️⃣ Network (NAT + net01)
# ---------------------------
# enp1s0 -> NAT (DHCP)
cat >/etc/systemd/network/10-enp1.network <<'EOF'
[Match]
Name=enp1s0

[Network]
DHCP=yes
EOF

# enp2s0 -> net01 (static)
cat >/etc/systemd/network/20-enp2.network <<'EOF'
[Match]
Name=enp2s0

[Network]
Address=10.0.1.2/24
Gateway=10.0.1.1
DNS=10.0.1.1
EOF

systemctl enable systemd-networkd
systemctl restart systemd-networkd

echo "Host0 setup complete."
