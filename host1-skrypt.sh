#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${APP_DIR:-${SCRIPT_DIR}/to-be-added/webapp}"
WEBAPP_PUBLIC_IP="${WEBAPP_PUBLIC_IP:-10.0.1.3}"
WEBAPP_INTERNAL_IP="${WEBAPP_INTERNAL_IP:-10.0.12.2}"
WEBMIN_HOST="${WEBMIN_HOST:-10.0.12.3}"
WEBMIN_PORT="${WEBMIN_PORT:-10000}"

# ---------------------------
# 1️⃣ Base packages + SSH
# ---------------------------
apt update
apt install -y openssh-server apache2 curl python3-venv
rm -f /etc/ssh/ssh_host_*
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure openssh-server

sed -i 's/^#\?\s*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

systemctl restart sshd
systemctl restart ssh

# ---------------------------
# 2️⃣ Apache reverse proxy
# ---------------------------
a2enmod proxy proxy_http headers rewrite

cat >/etc/apache2/sites-available/webapp.conf <<EOF
<VirtualHost *:80>
    ServerName ${WEBAPP_PUBLIC_IP}
    ServerAlias *

    ProxyPreserveHost On

    <Location /admin/infra/>
        ProxyPass http://${WEBMIN_HOST}:${WEBMIN_PORT}/ nocanon
        ProxyPassReverse http://${WEBMIN_HOST}:${WEBMIN_PORT}/

        ProxyPassReverseCookiePath / /admin/infra
        ProxyPassReverseCookieDomain ${WEBMIN_HOST} ${WEBAPP_PUBLIC_IP}

        RequestHeader set X-Forwarded-Proto "http"
        RequestHeader set X-Forwarded-Host "${WEBAPP_PUBLIC_IP}"
        RequestHeader set X-Forwarded-Port "80"

        Header edit Location "^http://${WEBMIN_HOST}:${WEBMIN_PORT}(/.*)?$" "/admin/infra\$1"
        Header edit Location "^http://${WEBAPP_PUBLIC_IP}:${WEBMIN_PORT}(/.*)?$" "/admin/infra\$1"
        Header edit Location "^/(?!admin/infra)(.*)$" "/admin/infra/\$1"
    </Location>

    ProxyPass / http://127.0.0.1:5000/
    ProxyPassReverse / http://127.0.0.1:5000/
</VirtualHost>
EOF

a2dissite 000-default.conf >/dev/null 2>&1 || true
a2ensite webapp.conf
apachectl -t
systemctl reload apache2

# ---------------------------
# 3️⃣ Webapp setup
# ---------------------------
if [ ! -d "$APP_DIR" ]; then
  echo "Webapp directory not found: $APP_DIR" >&2
  exit 1
fi

cd "$APP_DIR"
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

python app/init_db.py

chmod +x ./scripts/run.sh ./scripts/setup.sh ./scripts/test.sh ./scripts/attack_timed_sqli.py

echo "Webapp setup complete."

# ---------------------------
# 4️⃣ Network (net01 + net12)
# ---------------------------
cat >/etc/systemd/network/10-enp1.network <<'EOF'
[Match]
Name=enp1s0

[Network]
Address=10.0.1.3/24
Gateway=10.0.1.1
DNS=10.0.1.1
EOF

cat >/etc/systemd/network/20-enp2.network <<'EOF'
[Match]
Name=enp2s0

[Network]
Address=10.0.12.2/24
Gateway=10.0.12.1
DNS=10.0.12.1
EOF

systemctl enable systemd-networkd
systemctl restart systemd-networkd

echo "Host1 setup complete. Start the app with ${APP_DIR}/scripts/run.sh"
