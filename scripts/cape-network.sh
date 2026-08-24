#!/bin/bash

set -euxo pipefail

# CAPE needs the dnsmasq binary for libvirt's per-network DNS/DHCP
# processes, but not the distribution's standalone dnsmasq service.  The
# standalone service binds port 53 on every address and conflicts with
# systemd-resolved's loopback listeners.  Libvirt starts its own instances
# below, scoped to virbr-cape (and any other libvirt-managed bridge).
systemctl disable --now dnsmasq.service
systemctl reset-failed dnsmasq.service || true

systemctl start libvirtd.service

# Define the CAPE analysis network via libvirt (192.168.56.0/24, NAT).
# DHCP reservation ensures the guest gets the right IP even if Windows
# falls back to DHCP (e.g. due to firmware/NIC identity mismatch).
cat > /tmp/cape-net.xml <<EOF
<network>
  <name>cape</name>
  <forward mode='nat'/>
  <bridge name='virbr-cape' stp='on' delay='0'/>
  <ip address='192.168.56.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.56.100' end='192.168.56.200'/>
      <host mac='${WIN10_GUEST_MAC}' ip='${WIN10_GUEST_IP}'/>
    </dhcp>
  </ip>
</network>
EOF

virsh net-define /tmp/cape-net.xml
virsh net-autostart cape
virsh net-start cape

# Allow cape user to capture on the analysis bridge
setcap cap_net_raw,cap_net_admin=eip "$(which tcpdump)"

rm -f /tmp/cape-net.xml
