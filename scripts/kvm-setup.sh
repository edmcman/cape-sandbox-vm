#!/bin/bash -eux

apt-get install -y \
    qemu-kvm libvirt-daemon-system libvirt-clients \
    virtinst bridge-utils cpu-checker \
    ovmf

# Allow cape user to manage VMs without sudo
usermod -aG libvirt,kvm "${SSH_USERNAME}"

# Persist nested KVM config for both Intel and AMD
cat > /etc/modprobe.d/kvm-nested.conf <<'EOF'
options kvm_intel nested=1
options kvm_amd nested=1
EOF

# Load immediately if possible (may not match host CPU type; errors are harmless)
modprobe kvm_intel nested=1 2>/dev/null || modprobe kvm_amd nested=1 2>/dev/null || true

# Enable and start libvirtd
systemctl enable --now libvirtd
