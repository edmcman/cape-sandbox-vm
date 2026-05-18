#!/bin/bash -eux
export DEBIAN_FRONTEND=noninteractive

apt-get install -y inetsim

# Bind to CAPE analysis network interface instead of default 127.0.0.1
sed -i 's/^#\?\s*service_bind_address\b.*/service_bind_address 192.168.56.1/' /etc/inetsim/inetsim.conf

systemctl enable --now inetsim
systemctl is-active --quiet inetsim
