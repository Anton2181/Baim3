#!/bin/bash
set -e

# ---------------------------
# 1️⃣ Update and install
# ---------------------------
apt update
apt install -y openssh-server
rm -f /etc/ssh/ssh_host_*
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure openssh-server

# Enable root login
sed -i 's/^#\?\s*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Enable password authentication
sed -i 's/^#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

systemctl restart sshd
systemctl restart ssh


apt install -y postgresql sudo locales

# Fix locale warnings (optional but recommended)
locale-gen en_US.UTF-8
update-locale LANG=C.UTF-8 LC_ALL=C.UTF-8

# ---------------------------
# 2️⃣ Enable PostgreSQL
# ---------------------------
systemctl enable --now postgresql

# Allow postgres to run apt commands as root
cat >/etc/sudoers.d/postgres-apt <<'EOF'
postgres ALL=(root) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get
EOF
chmod 0440 /etc/sudoers.d/postgres-apt

# ---------------------------
# 3️⃣ Configure PostgreSQL
# ---------------------------
su - postgres -c "psql -v ON_ERROR_STOP=1" <<'SQL'
-- Ensure SCRAM password encryption
ALTER SYSTEM SET password_encryption = 'scram-sha-256';
SELECT pg_reload_conf();
SQL

# ---------------------------
# 4️⃣ Create database safely
# ---------------------------
su - postgres -c "psql -v ON_ERROR_STOP=1" <<'SQL'
-- Conditional database creation (outside DO block)
SELECT 'CREATE DATABASE appdb'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname='appdb')
\gexec
SQL

# ---------------------------
# 5️⃣ Create or update roles
# ---------------------------
su - postgres -c "psql -v ON_ERROR_STOP=1 appdb" <<'SQL'
DO $$
BEGIN
  -- Create or update roles with passwords
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'webapp') THEN
    CREATE ROLE webapp LOGIN PASSWORD 'WebApp9mQf2zKpA4vX7cLrT1';
  ELSE
    ALTER ROLE webapp LOGIN PASSWORD 'WebApp9mQf2zKpA4vX7cLrT1';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dev') THEN
    CREATE ROLE dev LOGIN PASSWORD 'Dev6vN3pYtS8kJqR5hLm2';
  ELSE
    ALTER ROLE dev LOGIN PASSWORD 'Dev6vN3pYtS8kJqR5hLm2';
  END IF;
END $$;
SQL

# ---------------------------
# 6️⃣ Configure schema and tables
# ---------------------------
su - postgres -c "psql -v ON_ERROR_STOP=1 appdb" <<'SQL'
-- Restrict general access
REVOKE ALL ON DATABASE appdb FROM PUBLIC;

-- Grant connect to roles
GRANT CONNECT ON DATABASE appdb TO webapp, dev;

-- Set ownership
ALTER DATABASE appdb OWNER TO dev;

-- Create schema 'app' owned by dev
CREATE SCHEMA IF NOT EXISTS app AUTHORIZATION dev;
REVOKE ALL ON SCHEMA app FROM PUBLIC;
GRANT USAGE ON SCHEMA app TO webapp;

-- Create credentials table
CREATE TABLE IF NOT EXISTS app.credentials (
  user_id       BIGSERIAL PRIMARY KEY,
  username      TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL
);
ALTER TABLE app.credentials OWNER TO dev;

-- Grant webapp DML rights
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE app.credentials TO webapp;
GRANT USAGE, SELECT ON SEQUENCE app.credentials_user_id_seq TO webapp;

-- Ensure future dev-created objects grant webapp access
ALTER DEFAULT PRIVILEGES FOR ROLE dev IN SCHEMA app
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO webapp;

ALTER DEFAULT PRIVILEGES FOR ROLE dev IN SCHEMA app
  GRANT USAGE, SELECT ON SEQUENCES TO webapp;

-- Grant high-risk capabilities to dev
GRANT pg_read_server_files TO dev;
GRANT pg_write_server_files TO dev;
GRANT pg_execute_server_program TO dev;

-- Grant dev EXECUTE rights on helper functions
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS proc
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'pg_catalog'
      AND p.proname IN ('pg_read_file','pg_read_binary_file','pg_ls_dir','pg_stat_file')
  LOOP
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO dev;', r.proc);
  END LOOP;
END $$;
SQL

sed -i -r "s/^#?\s*listen_addresses\s*=.*/listen_addresses = '*'/" /etc/postgresql/17/main/postgresql.conf

sed -i -r "s/^(host\s+)(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/\1all all 0.0.0.0\/0 scram-sha-256/" /etc/postgresql/17/main/pg_hba.conf
systemctl restart postgresql

# ---------------------------
# ✅ Done
# ---------------------------
echo "PostgreSQL setup complete. Database 'appdb' and roles 'webapp' and 'dev' are ready."

# Static IP for ens3 on net23
cat >/etc/systemd/network/10-enp1.network <<'EOF'
[Match]
Name=enp1s0

[Network]
Address=10.0.23.3/24
Gateway=10.0.23.1
DNS=10.0.23.1
EOF

cat >/etc/systemd/network/20-enp2.network <<'EOF'
[Match]
Name=enp2s0

[Network]
Address=10.0.34.2/24
Gateway=10.0.34.1
DNS=10.0.34.1
EOF

systemctl enable systemd-networkd
systemctl restart systemd-networkd
