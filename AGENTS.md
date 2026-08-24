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
                        # cape-win10-snapshot-check.sh.tmpl + .service — first-boot snapshot self-heal (see below)
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

## `cape-ready` snapshot portability

`cape-win10`'s CPU is `mode='host-passthrough' check='none'` (`files/cape-win10.xml.tmpl`) — QEMU gets `-cpu host` directly, with no libvirt-side translation into a named model. This matters because `mode='host-model'` (the more commonly recommended default) gets translated by libvirt into a concrete `mode='custom'` spec (nearest named model + explicit `<feature policy='require'>` list) before it's validated/started, and that translated form is what ends up embedded in a snapshot's XML and — critically — becomes the domain's new *persistent* definition after any successful `virsh snapshot-revert` (revert restores the full domain config from the snapshot, not just disk/memory). That silently downgrades an adaptive `host-model` domain to a static one pinned to whatever host most recently reverted successfully, breaking future adaptability. `host-passthrough` has no translated form to freeze, so a revert always restores `host-passthrough` again. `cape-win10` never migrates between physical hosts, so `host-model`'s only advantage (safe cross-host migration compatibility checking) doesn't apply here.

This doesn't remove the need to keep the `cape-ready` snapshot itself in sync with whatever host is running it: any `cape-ready` snapshot is a **live memory snapshot**, so it freezes the register/execution state of whatever host created it, and restoring that on a host missing a feature that host had still fails with `guest CPU doesn't match specification: missing features: ...` — that part is inherent to restoring saved live state on different silicon, independent of CPU mode.

Do not "fix" this by pinning a specific CPU model via `mode='custom'` in `cape-win10.xml.tmpl` — that just trades one hardcoded baseline for another and still caps every recipient at whatever model is picked. Instead, `files/cape-win10-snapshot-check.sh.tmpl` + `files/cape-win10-snapshot-check.service` are installed and enabled at build time (see the provisioners in `cape.pkr.hcl`, right after the Windows guest domain is imported/defined) to self-heal: the service runs before both `cape.service` and `getty-pre.target` on **every boot**, tries a normal revert, and if that fails (including because no `cape-ready` snapshot exists yet at all), cold-boots the Windows guest and rebuilds `cape-ready` locally so it matches whatever CPU is really there. Gating `getty-pre.target` keeps graphical and serial login prompts from overwriting the check's console progress. The `base-vm` build itself never starts `cape-win10` or takes a snapshot; `cape-ready` is always created lazily, the first time the VM actually boots for real. A compatible snapshot reverts in seconds, so checking every boot is cheap in the common case.

Deliberately no one-shot "already checked" marker: `combined-vm` clones this VM's output and genuinely boots it (via Packer's `vmware-vmx`/`qemu`/`virtualbox-ovf` builders) to install the agent container, which would count as the "first boot" and let a marker get baked into the shipped image on the *build* machine — permanently disabling the self-heal for actual recipients. Checking unconditionally on every boot sidesteps that class of bug entirely and also means a VM whose files get copied to genuinely different hardware later re-validates automatically.

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
