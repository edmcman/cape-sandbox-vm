#!/bin/bash -eux

# Define the CAPE analysis network via libvirt (192.168.56.0/24, NAT)
# The Windows guest is statically assigned 192.168.56.10 by auto-windows-vm's set-static-ip.ps1
cat > /tmp/cape-net.xml <<'EOF'
<network>
  <name>cape</name>
  <forward mode='nat'/>
  <bridge name='virbr-cape' stp='on' delay='0'/>
  <ip address='192.168.56.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.56.100' end='192.168.56.200'/>
    </dhcp>
  </ip>
</network>
EOF

virsh net-define /tmp/cape-net.xml
virsh net-autostart cape
virsh net-start cape

# Patch CAPE config to use this interface if it already exists
if [[ -f /opt/CAPEv2/conf/kvm.conf ]]; then
    sed -i 's/^interface =.*/interface = virbr-cape/' /opt/CAPEv2/conf/kvm.conf
fi

# Allow cape user to capture on the analysis bridge
setcap cap_net_raw,cap_net_admin=eip "$(which tcpdump)"

rm -f /tmp/cape-net.xml
