#!/bin/bash -eux

# Enable systemd-resolved's native mDNS responder (replaces avahi-daemon).
# Lighter weight than avahi; avoids a second daemon competing for UDP 5353.

# CAPE's wkhtmltopdf dependency can pull avahi-daemon in later via package
# recommendations. Pre-mask both activation paths so that installing the
# package cannot start a second mDNS responder alongside systemd-resolved.
# Keep the package and its libraries installed for dependency compatibility.
systemctl disable --now avahi-daemon.service avahi-daemon.socket 2>/dev/null || true
systemctl mask avahi-daemon.service avahi-daemon.socket

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
# netplan generates (e.g. 10-netplan-eth0.network). The host NIC is pinned
# to eth0 across all builders via net.ifnames=0 (see http/user-data), so the
# name is consistent -- but we still glob rather than hard-code it, since
# that also avoids touching virbr-cape (the CAPE analysis bridge), which
# libvirt manages directly and which never appears under
# /run/systemd/network.

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
