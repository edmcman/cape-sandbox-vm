#!/bin/bash -eux

SSH_USER=${SSH_USERNAME:-cape}
DISK_USAGE_BEFORE_CLEANUP=$(df -h)

echo "==> Cleaning up udev rules"
rm -rf /dev/.udev/ 2>/dev/null || true

echo "==> Cleaning up leftover dhcp leases"
if [ -d "/var/lib/dhcp" ]; then
    rm -f /var/lib/dhcp/*
fi

echo "==> Blanking systemd machine-id (unique ID regenerated on first boot)"
if [ -f "/etc/machine-id" ]; then
    truncate -s 0 "/etc/machine-id"
fi

echo "==> Cleaning up tmp"
rm -rf /tmp/*

apt-get -y autoremove --purge
apt-get -y clean
apt-get -y autoclean

unset HISTFILE
rm -f /root/.bash_history
rm -f /home/${SSH_USER}/.bash_history

find /var/log -type f | while read -r f; do echo -ne '' > "${f}"; done

>/var/log/lastlog
>/var/log/wtmp
>/var/log/btmp

# Zero swap partition to reduce image size
set +e
swapuuid=$(/sbin/blkid -o value -l -s UUID -t TYPE=swap)
set -e
if [ "x${swapuuid}" != "x" ]; then
    swappart=$(readlink -f /dev/disk/by-uuid/$swapuuid)
    /sbin/swapoff "${swappart}"
    dd if=/dev/zero of="${swappart}" bs=1M || echo "dd exit code $? suppressed"
    /sbin/mkswap -U "${swapuuid}" "${swappart}"
fi

dd if=/dev/zero of=/EMPTY bs=1M || echo "dd exit code $? suppressed"
rm -f /EMPTY
sync

echo "==> Disk usage before cleanup"
echo "${DISK_USAGE_BEFORE_CLEANUP}"
echo "==> Disk usage after cleanup"
df -h
