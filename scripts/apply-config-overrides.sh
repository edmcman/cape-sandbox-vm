#!/bin/bash -eux

mkdir -p /opt/CAPEv2/custom/conf
for f in /tmp/conf-overrides/*.conf; do
    [[ -f "$f" ]] || continue
    cp "$f" /opt/CAPEv2/custom/conf/
done
