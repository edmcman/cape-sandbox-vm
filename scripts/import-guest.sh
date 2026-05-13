#!/bin/bash -eux
# Post-deployment operator script — run this on the deployed CAPE host.
# Usage: ./import-guest.sh /path/to/cape-win10.qcow2
#
# The Windows guest image comes from auto-windows-vm:
#   output-qemu-cape-win10/cape-win10
# It has the CAPE agent installed and a snapshot named "cape-ready".

set -euo pipefail

QCOW2="${1:?Usage: $0 /path/to/cape-win10.qcow2}"
DEST=/var/lib/libvirt/images/cape-win10.qcow2
XML_TMPL="$(dirname "$0")/../files/cape-win10.xml.tmpl"
DOMAIN_XML=/tmp/cape-win10.xml

if [[ ! -f "$QCOW2" ]]; then
    echo "Error: $QCOW2 not found" >&2
    exit 1
fi

echo "==> Copying QCOW2 image to libvirt storage..."
cp "$QCOW2" "$DEST"
chown libvirt-qemu:libvirt-qemu "$DEST" 2>/dev/null || true

echo "==> Defining libvirt domain..."
sed "s|CAPE_QCOW2_PATH|${DEST}|g" "$XML_TMPL" > "$DOMAIN_XML"
virsh define "$DOMAIN_XML"
rm -f "$DOMAIN_XML"

echo "==> Done. The guest VM 'cape-win10' is now defined."
echo "    Revert to the analysis snapshot and configure CAPE:"
echo "      virsh snapshot-revert cape-win10 cape-ready"
echo "      Edit /opt/CAPEv2/conf/kvm.conf — set machines = cape-win10"
echo "      Edit /opt/CAPEv2/conf/cuckoo.conf — review resultserver_ip"
echo "      cd /opt/CAPEv2 && source venv/bin/activate && python3 cuckoo.py"
