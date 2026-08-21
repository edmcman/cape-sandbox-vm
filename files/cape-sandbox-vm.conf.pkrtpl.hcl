# Configurable parameters of this CAPE sandbox VM, rendered by the Packer
# build from variables.pkrvars.hcl and installed as /etc/cape-sandbox-vm.conf.
#
# Only values that vary between builds appear here, so anything on this VM can
# read them instead of rediscovering them. CAPE reads its own copies from
# /opt/CAPEv2/custom/conf/, substituted from the same Packer variables --
# change variables.pkrvars.hcl and rebuild rather than editing either by hand.

[guest]
ip = ${guest_ip}
gateway = ${guest_gateway}
mac = ${guest_mac}
