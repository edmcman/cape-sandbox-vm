#!/bin/bash -eux

mkdir -p /opt/CAPEv2/custom/conf
for f in /tmp/conf-overrides/*.conf; do
    [[ -f "$f" ]] || continue
    cp "$f" /opt/CAPEv2/custom/conf/
done

# Substitute build-time placeholders
sed -i "s|__WIN10_GUEST_IP__|${WIN10_GUEST_IP}|g" /opt/CAPEv2/custom/conf/kvm.conf
sed -i "s|__WIN10_GUEST_GATEWAY__|${WIN10_GUEST_GATEWAY}|g" /opt/CAPEv2/custom/conf/cuckoo.conf
