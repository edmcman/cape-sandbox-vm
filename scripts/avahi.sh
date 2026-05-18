#!/bin/bash -eux

apt-get -y install avahi-daemon libnss-mdns
systemctl enable avahi-daemon