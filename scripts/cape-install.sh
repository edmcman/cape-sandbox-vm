#!/bin/bash -eux

# Use CAPE's official installers instead of hand-rolling deps
# kvm-qemu.sh: compiles QEMU/libvirt with anti-VM-detection patches
# cape2.sh: installs CAPEv2, MongoDB, dependencies, systemd services

CAPE_ROOT="${CAPE_ROOT:-/opt/CAPEv2}"

# Clone CAPEv2 first so installers are available
git clone https://github.com/kevoreilly/CAPEv2 "$CAPE_ROOT"

# Run CAPE's KVM/QEMU setup (compiles QEMU with anti-VM patches)
cd "$CAPE_ROOT/installer"
bash kvm-qemu.sh base # ip?

# Run CAPE's main installer (MongoDB, deps, CAPE itself)
# Fix poetry cache permissions — cape2.sh runs as root but poetry uses cape's cache
mkdir -p /home/"${SSH_USERNAME}"/.cache/pypoetry
chown -R "${SSH_USERNAME}":"${SSH_USERNAME}" /home/"${SSH_USERNAME}"/.cache
cd "$CAPE_ROOT/installer"
bash cape2.sh all

# Create dedicated analysis user account
useradd -m -s /bin/bash cape-analysis || true
echo "cape-analysis:cape" | chpasswd

# Configure PostgreSQL database for CAPE
sudo -u postgres psql -c "CREATE USER cape WITH PASSWORD 'cape';" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE cape OWNER cape;" 2>/dev/null || true

# Allow cape user to run tcpdump without root (needed for traffic capture)
setcap cap_net_raw,cap_net_admin=eip /usr/bin/tcpdump

chown -R "${SSH_USERNAME}":"${SSH_USERNAME}" "$CAPE_ROOT"
