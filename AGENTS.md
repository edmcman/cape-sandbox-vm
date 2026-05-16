# cape-sandbox-vm — Agent Instructions

Packer project that builds an Ubuntu 24.04 VM running CAPEv2 malware sandbox. CAPE runs a Windows 10 analysis guest inside the VM using KVM, so nested virtualization is required on the build host.

## Repository layout

```
cape.pkr.hcl            # Main Packer file — 3 builders: qemu, vmware-iso, virtualbox-iso
variables.pkrvars.hcl   # Build-time variables (CPUs, memory, credentials, guest network)
scripts/                # Provisioner shell scripts (run in order during build)
  update.sh             # apt upgrade
  sshd.sh               # harden SSH
  vmware.sh             # VMware open-vm-tools
  virtualbox.sh         # VirtualBox guest additions
  cape-install.sh       # Installs CAPE via official cape2.sh + kvm-qemu.sh installers
  cape-network.sh       # Creates libvirt 'cape' network, patches kvm.conf + cuckoo.conf
  apply-config-overrides.sh  # Copies conf-overrides/ → /opt/CAPEv2/custom/conf/
  cleanup.sh            # Remove logs, tmp files before snapshot
conf-overrides/         # User CAPE config overrides (see below)
CAPEv2/                 # Git submodule — upstream CAPEv2 source, do not modify directly
auto-windows-vm/        # Git submodule — builds the Windows 10 analysis guest QCOW2
http/                   # cloud-init user-data/meta-data for Ubuntu autoinstall
files/                  # cape-win10.xml.tmpl — libvirt domain XML template
```

## Build order

1. Build the Windows guest first (`auto-windows-vm/`, QEMU only):
   ```sh
   packer build -only=qemu <(jsonnet packer-templates/cape-win10.jsonnet) auto-windows-vm/
   ```
2. Build the CAPE sandbox VM:
   ```sh
   packer build -only='cape-sandbox.qemu.ubuntu' -var-file=variables.pkrvars.hcl .
   ```

The CAPE build uploads the CAPEv2 submodule and `conf-overrides/` as tarballs, runs the provisioner scripts, imports the Windows guest into libvirt, takes the analysis snapshot (`cape-ready`), and shuts down.

## Analysis network

- Subnet: `192.168.56.0/24`, NAT via libvirt bridge `virbr-cape`
- CAPE host (result server): `192.168.56.1`
- Windows guest: `192.168.56.10` (static + DHCP reservation by MAC)
- Guest MAC: `52:54:00:ca:fe:10` (must match `win10_guest_mac` in both builds)

`win10_guest_mac` and `win10_guest_ip` in `variables.pkrvars.hcl` must stay in sync with the values baked into the Windows guest — changing them requires rebuilding both images.

## CAPE config overrides

Place partial `.conf` files in `conf-overrides/` using CAPE's config filenames (e.g. `cuckoo.conf`, `reporting.conf`). Only include sections/keys to change. At build time these are copied to `/opt/CAPEv2/custom/conf/`, which CAPE reads at runtime and merges with its defaults.

Do not edit `CAPEv2/conf/` directly — it is upstream. Structural changes (network interface, machine list) are handled by `scripts/cape-network.sh`; everything else goes in `conf-overrides/`.

## Key paths on the installed VM

| Path | Purpose |
|------|---------|
| `/opt/CAPEv2/` | CAPE installation root |
| `/opt/CAPEv2/conf/` | Active config files |
| `/opt/CAPEv2/custom/conf/` | User config overrides (read at runtime) |
| `/var/lib/libvirt/images/cape-win10.qcow2` | Windows guest disk |
| `/var/lib/libvirt/qemu/nvram/cape-win10_VARS.fd` | UEFI vars for Windows guest |

## SSH access

```sh
sshpass -p cape ssh cape@<vm-ip>
```

Check `arp -n` if the IP is unknown. Default credentials: `cape` / `cape`.

## Submodules

```sh
git submodule update --init --recursive
```

`CAPEv2` tracks upstream kevoreilly/CAPEv2. `auto-windows-vm` is a local submodule for the Windows guest build. Bump submodules with `git submodule update --remote` then commit.
