#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

WEBMIN_VERSION="1.920"
WEBMIN_TARBALL="webmin-${WEBMIN_VERSION}.tar.gz"
WEBMIN_URL="https://sourceforge.net/projects/webadmin/files/webmin/${WEBMIN_VERSION}/${WEBMIN_TARBALL}"
INSTALL_DIR="/usr/local/webmin"
WEBMIN_PORT="${WEBMIN_PORT:-10000}"
WEBMIN_LOGIN="${WEBMIN_LOGIN:-admin}"
WEBMIN_PASSWORD="${WEBMIN_PASSWORD:-admin123}"
WEBMIN_SSL="${WEBMIN_SSL:-n}"
WEBMIN_START_BOOT="${WEBMIN_START_BOOT:-n}"
WEBMIN_HTTP_PORT="${WEBMIN_HTTP_PORT:-${WEBMIN_PORT}}"
WEBMIN_IP="${WEBMIN_IP:-10.0.12.3}"
WEBMIN_NETMASK="${WEBMIN_NETMASK:-255.255.255.0}"
WEBMIN_CONFIG_DIR="${WEBMIN_CONFIG_DIR:-/etc/webmin}"
WEBMIN_LOG_DIR="${WEBMIN_LOG_DIR:-/var/webmin}"
WEBMIN_PERL_PATH="${WEBMIN_PERL_PATH:-/usr/bin/perl}"
WEBAPP_IP="${WEBAPP_IP:-10.0.12.2}"
WEBAPP_HOST="${WEBAPP_HOST:-10.0.1.3}"
WEBMIN_WEBPREFIX="${WEBMIN_WEBPREFIX:-/admin/infra}"
WEBMIN_REDIRECT_HOST="${WEBMIN_REDIRECT_HOST:-${WEBAPP_HOST}}"

# ---------------------------
# 1️⃣ Base packages + SSH
# ---------------------------
apt update
apt install -y openssh-server curl perl python3-venv
rm -f /etc/ssh/ssh_host_*
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure openssh-server

sed -i 's/^#\?\s*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

systemctl restart sshd
systemctl restart ssh

# ---------------------------
# 2️⃣ Network (net12 + net23)
# ---------------------------
cat >/etc/systemd/network/10-enp1.network <<'EOF'
[Match]
Name=enp1s0

[Network]
Address=10.0.12.3/24
Gateway=10.0.12.1
DNS=10.0.12.1
EOF

cat >/etc/systemd/network/20-enp2.network <<'EOF'
[Match]
Name=enp2s0

[Network]
Address=10.0.23.2/24
Gateway=10.0.23.1
DNS=10.0.23.1
EOF

systemctl enable systemd-networkd
systemctl restart systemd-networkd

# ---------------------------
# 3️⃣ Install Webmin
# ---------------------------
tmp_dir=$(mktemp -d)
cleanup() { rm -rf "${tmp_dir}"; }
trap cleanup EXIT

curl -L -o "${tmp_dir}/${WEBMIN_TARBALL}" "${WEBMIN_URL}"
tar -xzf "${tmp_dir}/${WEBMIN_TARBALL}" -C "${tmp_dir}"

cd "${tmp_dir}/webmin-${WEBMIN_VERSION}"
cat <<EOF | ./setup.sh "${INSTALL_DIR}"
${WEBMIN_CONFIG_DIR}
${WEBMIN_LOG_DIR}
${WEBMIN_PERL_PATH}
${WEBMIN_PORT}
${WEBMIN_LOGIN}
${WEBMIN_PASSWORD}
${WEBMIN_PASSWORD}
${WEBMIN_SSL}
${WEBMIN_START_BOOT}
EOF

if [[ -f /etc/webmin/miniserv.conf ]]; then
  sed -i "/^bind=/d" /etc/webmin/miniserv.conf
  sed -i "/^allow=/d" /etc/webmin/miniserv.conf
  sed -i "/^deny=/d" /etc/webmin/miniserv.conf
  sed -i "/^redirect_prefix=/d" /etc/webmin/miniserv.conf
  sed -i "/^cookiepath=/d" /etc/webmin/miniserv.conf
  sed -i "/^redirect_host=/d" /etc/webmin/miniserv.conf
  sed -i "/^redirect_port=/d" /etc/webmin/miniserv.conf
  {
    echo "bind=${WEBMIN_IP}"
    echo "allow=${WEBAPP_IP} 127.0.0.1"
    echo "redirect_prefix=${WEBMIN_WEBPREFIX}"
    echo "cookiepath=${WEBMIN_WEBPREFIX}"
    echo "redirect_host=${WEBMIN_REDIRECT_HOST}"
    echo "redirect_port=80"
  } >> /etc/webmin/miniserv.conf
fi

if [[ -f /etc/webmin/config ]]; then
  sed -i "/^referers_none=/d" /etc/webmin/config
  sed -i "/^referers=/d" /etc/webmin/config
  sed -i "/^webprefix=/d" /etc/webmin/config
  sed -i "/^webprefixnoredir=/d" /etc/webmin/config
  echo "referers=${WEBAPP_HOST}" >> /etc/webmin/config
  echo "referers_none=0" >> /etc/webmin/config
  echo "webprefix=${WEBMIN_WEBPREFIX}" >> /etc/webmin/config
  echo "webprefixnoredir=1" >> /etc/webmin/config
fi

if [[ -f /etc/webmin/xterm/config ]]; then
  sed -i "/^host=/d" /etc/webmin/xterm/config
  echo "host=${WEBMIN_REDIRECT_HOST}" >> /etc/webmin/xterm/config
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl restart webmin >/dev/null 2>&1 || true
elif [[ -x /etc/init.d/webmin ]]; then
  /etc/init.d/webmin restart >/dev/null 2>&1 || true
elif [[ -x /etc/webmin/restart ]]; then
  /etc/webmin/restart >/dev/null 2>&1 || true
fi

echo "Host2 setup complete. Webmin available via ${WEBAPP_HOST}${WEBMIN_WEBPREFIX}."
