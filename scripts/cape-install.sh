#!/bin/bash -eux

# System dependencies for CAPEv2
apt-get install -y \
    git python3 python3-pip python3-venv python3-dev \
    libffi-dev libssl-dev libjpeg-dev zlib1g-dev \
    postgresql postgresql-client \
    tcpdump libpcap-dev \
    p0f \
    yara libyara-dev \
    apparmor-utils \
    build-essential \
    zip unzip curl wget \
    suricata \
    net-tools \
    samba samba-common-bin

# MongoDB (not in Ubuntu 24.04 main; use official repo)
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc \
    | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] \
https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/7.0 multiverse" \
    > /etc/apt/sources.list.d/mongodb-org-7.0.list
apt-get update
apt-get install -y mongodb-org
systemctl enable mongod

# Create dedicated analysis user account
useradd -m -s /bin/bash cape-analysis || true
echo "cape-analysis:cape" | chpasswd

# Clone CAPEv2
git clone https://github.com/kevoreilly/CAPEv2 /opt/CAPEv2
chown -R "${SSH_USERNAME}":"${SSH_USERNAME}" /opt/CAPEv2

# Python virtualenv with CAPEv2 dependencies
cd /opt/CAPEv2
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip wheel
# poetry is the package manager used by CAPEv2
pip install poetry
poetry install --no-root 2>/dev/null || pip install -r requirements.txt || true
deactivate

# Configure PostgreSQL database for CAPE
sudo -u postgres psql -c "CREATE USER cape WITH PASSWORD 'cape';" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE cape OWNER cape;" 2>/dev/null || true

# Drop in the kvm machinery config
if [[ -f /opt/CAPEv2/conf/kvm.conf.default ]]; then
    cp /opt/CAPEv2/conf/kvm.conf.default /opt/CAPEv2/conf/kvm.conf
fi

# Allow cape user to run tcpdump without root (needed for traffic capture)
setcap cap_net_raw,cap_net_admin=eip /usr/bin/tcpdump

chown -R "${SSH_USERNAME}":"${SSH_USERNAME}" /opt/CAPEv2
