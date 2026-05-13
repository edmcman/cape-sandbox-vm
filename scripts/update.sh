#!/bin/bash -eux

sed -i.bak 's/^Prompt=.*$/Prompt=never/' /etc/update-manager/release-upgrades

for i in $(seq 1 5); do apt-get -y update && break || sleep 10; done

if [[ $UPDATE =~ true || $UPDATE =~ 1 || $UPDATE =~ yes ]]; then
    apt-get -y dist-upgrade
    reboot
fi
