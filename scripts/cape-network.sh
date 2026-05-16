#!/bin/bash -eux

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

# Patch CAPE config for the analysis network
if [[ -f /opt/CAPEv2/conf/kvm.conf ]]; then
    sed -i 's/^interface =.*/interface = virbr-cape/' /opt/CAPEv2/conf/kvm.conf
    sed -i 's/^machines =.*/machines = cape-win10/' /opt/CAPEv2/conf/kvm.conf
    cat >> /opt/CAPEv2/conf/kvm.conf <<'EOF'

[cape-win10]
label = cape-win10
platform = windows
ip = 192.168.56.10
snapshot = cape-ready
arch = x64
tags = win10
EOF
fi

if [[ -f /opt/CAPEv2/conf/cuckoo.conf ]]; then
    sed -i 's/^ip = 192\.168\.1\.1/ip = 192.168.56.1/' /opt/CAPEv2/conf/cuckoo.conf
fi

# Allow cape user to capture on the analysis bridge
setcap cap_net_raw,cap_net_admin=eip "$(which tcpdump)"

rm -f /tmp/cape-net.xml
