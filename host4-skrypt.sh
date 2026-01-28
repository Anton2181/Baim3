#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

REPO_URL="https://github.com/tdekeyser/log4shell-lab"
DIR="/root/log4shell-lab"

echo "[1/6] Base packages (curl, git, java)..."
apt-get update -y
apt-get install -y ca-certificates curl git default-jdk

echo "[2/6] Docker (official repo) + Compose plugin..."
# Remove conflicting unofficial packages (safe if not installed)
apt-get remove -y docker.io docker-compose docker-doc podman-docker containerd runc || true

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${VERSION_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker


echo "[3/6] Clone/update lab repo..."
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull --ff-only
else
  git clone "$REPO_URL" "$DIR"
fi

echo "[4/6] Apply requested patches (Dockerfile + compose privileged + restart)..."

# 4a) Dockerfile base image swap
DOCKERFILE="$DIR/vulnerable-app/Dockerfile"
sed -i 's|^FROM openjdk:11-slim$|FROM eclipse-temurin:11.0.16.1_1-jre-jammy|' "$DOCKERFILE"

# 4b) docker-compose.yaml patches
COMPOSE_YML="$DIR/docker-compose.yml"
if [ -f "$COMPOSE_YML" ]; then
  # privileged: true
  if ! grep -q 'privileged:' "$COMPOSE_YML"; then
    sed -i '/container_name: log4shell-vulnerable-app/a\    privileged: true' "$COMPOSE_YML"
  fi

  # restart: unless-stopped (auto-start containers on reboot)
  if ! grep -q 'restart:' "$COMPOSE_YML"; then
    sed -i '/container_name: log4shell-vulnerable-app/a\    restart: unless-stopped' "$COMPOSE_YML"
  fi
fi

echo "[5/6] Build vulnerable app (Gradle)..."
cd "$DIR/vulnerable-app"
chmod +x ./gradlew
./gradlew bootJar


echo "[6/6] Start lab (Docker Compose)..."
cd "$DIR"
docker compose up -d --build




rm /etc/systemd/network/10-wired.network
cat >/etc/systemd/network/10-enp1.network <<'EOF'
[Match]
Name=enp1s0

[Network]
Address=10.0.34.3/24
Gateway=10.0.34.1
DNS=10.0.34.1
EOF

systemctl enable systemd-networkd
systemctl restart systemd-networkd
