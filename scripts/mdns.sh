#!/bin/bash -eux

# Enable systemd-resolved's native mDNS responder (replaces avahi-daemon).
# Lighter weight than avahi; avoids a second daemon competing for UDP 5353.

# 1. Global enable via a drop-in (avoid hand-editing resolved.conf directly).
mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/mdns.conf <<'EOF'
[Resolve]
MulticastDNS=yes
EOF

# 2. Per-link enable, without hard-coding any interface name.
#
# mDNS needs both the global setting above AND a per-link setting. The
# per-link drop-in must match the systemd-networkd .network unit name
# netplan generates (e.g. 10-netplan-ens32.network) -- only known at boot,
# and it varies per builder (qemu/vmware/virtualbox use different NIC
# drivers) and even per build host. Rather than guess it, install an
# idempotent oneshot script + unit that discovers it fresh every boot.
# Because it globs at runtime, it also never touches virbr-cape (the CAPE
# analysis bridge), which libvirt manages directly and which never appears
# under /run/systemd/network.

mkdir -p /usr/local/sbin
cat > /usr/local/sbin/enable-mdns-links.sh <<'EOF'
#!/bin/bash
# Idempotently enable systemd-networkd MulticastDNS on every link networkd
# currently manages, then reload to apply. Runs every boot via
# mdns-links.service (After=systemd-networkd.service).
set -euo pipefail

shopt -s nullglob
units=(/run/systemd/network/*.network)

if [ ${#units[@]} -eq 0 ]; then
    echo "enable-mdns-links: no systemd-networkd .network units found; cannot enable link-level mDNS"
    exit 1
fi

for unit_path in "${units[@]}"; do
    unit_name="$(basename "$unit_path")"
    dropin_dir="/etc/systemd/network/${unit_name}.d"
    mkdir -p "$dropin_dir"
    cat > "${dropin_dir}/mdns.conf" <<'INNER'
[Network]
MulticastDNS=yes
INNER
    echo "enable-mdns-links: enabled MulticastDNS for ${unit_name}"
done

networkctl reload
EOF
chmod +x /usr/local/sbin/enable-mdns-links.sh

cat > /etc/systemd/system/mdns-links.service <<'EOF'
[Unit]
Description=Enable systemd-resolved MulticastDNS on networkd-managed links
After=systemd-networkd.service
Requires=systemd-networkd.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/enable-mdns-links.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable mdns-links.service

# 3. Make resolved pick up the new global config immediately, and run the
#    per-link unit now so we can verify during provisioning.
systemctl restart systemd-resolved
systemctl start mdns-links.service

# 4. Verify during provisioning -- fail loudly if mDNS isn't actually on.
resolvectl mdns
