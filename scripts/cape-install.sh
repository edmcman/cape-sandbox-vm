#!/bin/bash -eux

# Use CAPE's official installers instead of hand-rolling deps
# kvm-qemu.sh: compiles QEMU/libvirt with anti-VM-detection patches
# cape2.sh: installs CAPEv2, MongoDB, dependencies, systemd services

CAPE_ROOT="${CAPE_ROOT:-/opt/CAPEv2}"

# Run CAPE's KVM/QEMU setup (compiles QEMU with anti-VM patches)
cd "$CAPE_ROOT/installer"
bash -x kvm-qemu.sh all

# Run CAPE's main installer (MongoDB, deps, CAPE itself) using uv (--use-uv must be
# a CLI arg, not an env var — the env var sets USE_UV but never updates PYTHON_MGR).
cd "$CAPE_ROOT/installer"
bash -x cape2.sh base --use-uv

# Create dedicated analysis user account
useradd -m -s /bin/bash cape-analysis || true
echo "cape-analysis:cape" | chpasswd

# Configure PostgreSQL database for CAPE
sudo -u postgres psql -c "CREATE USER cape WITH PASSWORD 'cape';" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE cape OWNER cape;" 2>/dev/null || true

# Allow cape user to run tcpdump without root (needed for traffic capture)
setcap cap_net_raw,cap_net_admin=eip /usr/bin/tcpdump

chown -R "${SSH_USERNAME}":"${SSH_USERNAME}" "$CAPE_ROOT"
