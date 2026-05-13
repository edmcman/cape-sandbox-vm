# cape-sandbox-vm

Packer project that builds a ready-to-run [CAPEv2](https://github.com/kevoreilly/CAPEv2) malware sandbox host VM running Ubuntu 24.04 LTS. The host uses KVM/QEMU to run a Windows analysis guest.

## What gets built

- Ubuntu 24.04 LTS server (no desktop)
- KVM/QEMU/libvirt with nested virtualization enabled
- CAPEv2 cloned to `/opt/CAPEv2/` with Python venv and dependencies installed
- MongoDB 7.0 and PostgreSQL configured
- Libvirt `cape` network on `192.168.56.0/24` for isolated guest traffic
- `tcpdump` with `cap_net_raw` so CAPE can capture without root

The Windows analysis guest is **not** baked in — import it post-deployment once it's ready (see [Importing the guest](#importing-the-guest)).

## Prerequisites

| Tool | Version |
|------|---------|
| [Packer](https://developer.hashicorp.com/packer/install) | ≥ 1.9 |
| One of: VMware Workstation/Fusion, VirtualBox, or KVM/QEMU | — |

**QEMU builds require KVM on the build host.** The build machine must have `/dev/kvm` available (bare-metal Linux or a VM with nested virtualization enabled).

## Building

Install plugins once:

```
packer init .
```

Build a specific target:

```sh
# QEMU/KVM (recommended on Linux)
packer build -only=qemu.ubuntu -var-file=variables.pkrvars.hcl .

# VMware
packer build -only=vmware-iso.ubuntu -var-file=variables.pkrvars.hcl .

# VirtualBox
packer build -only=virtualbox-iso.ubuntu -var-file=variables.pkrvars.hcl .

# All three
packer build -var-file=variables.pkrvars.hcl .
```

Output is written to `output-qemu-cape/`, `output-vmware-cape/`, or `output-vbox-cape/`.

## Variables

Override any variable in `variables.pkrvars.hcl` or on the command line with `-var`:

| Variable | Default | Description |
|----------|---------|-------------|
| `vm_name` | `cape-sandbox` | VM name |
| `ssh_username` | `cape` | Host OS login |
| `ssh_password` | `cape` | Host OS password |
| `cpus` | `4` | vCPUs (host + guest combined; ≥ 4 recommended) |
| `memory` | `8192` | RAM in MB (host + guest combined; ≥ 8192 recommended) |
| `disk_size` | `102400` | Disk in MB (100 GB) |
| `headless` | `false` | Hide VM console during build |
| `update` | `true` | Run `dist-upgrade` during build |

Example — build headless with more RAM:

```sh
packer build -only=qemu.ubuntu \
  -var="headless=true" \
  -var="memory=16384" \
  -var-file=variables.pkrvars.hcl .
```

## Importing the guest

The Windows analysis guest is built separately by
[auto-windows-vm](../auto-windows-vm) using the `cape-win10.jsonnet` target.
Once that QCOW2 is ready, copy it to the running CAPE host and run:

```sh
sudo ./scripts/import-guest.sh /path/to/cape-win10.qcow2
```

This copies the image into libvirt storage and defines the `cape-win10` domain.
Then finish the CAPE configuration:

```sh
# Revert to the pre-analysis snapshot
virsh snapshot-revert cape-win10 cape-ready

# Edit CAPE config
$EDITOR /opt/CAPEv2/conf/kvm.conf      # set machines = cape-win10
$EDITOR /opt/CAPEv2/conf/cuckoo.conf   # review resultserver_ip (should be 192.168.56.1)

# Start CAPE
cd /opt/CAPEv2
source venv/bin/activate
python3 cuckoo.py
```

The web UI is at `http://<host-ip>:8000` once CAPE is running.

## Network layout

```
  Build host / hypervisor
  └── CAPE sandbox VM (192.168.x.x — DHCP from hypervisor)
        └── libvirt bridge virbr-cape (192.168.56.1)
              └── Windows guest (192.168.56.10 — static)
                    └── CAPE agent on :8000
```

All guest traffic is NATed through the bridge. To isolate the guest from the internet, set `forward mode='route'` or remove the `<forward/>` element in `files/cape-win10.xml.tmpl` before importing.

## Nested virtualization

| Hypervisor | How enabled |
|-----------|-------------|
| VMware | `vhv.enable = TRUE` in VMX |
| VirtualBox | `--nested-hw-virt on` |
| QEMU/KVM | `-cpu host` (inherits host VMX/SVM flags) |

The KVM nested config is persisted in `/etc/modprobe.d/kvm-nested.conf` inside the VM so it survives reboots.
