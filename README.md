# cape-sandbox-vm

Packer project that builds an Ubuntu 24.04 VM running [CAPEv2](https://github.com/kevoreilly/CAPEv2) malware sandbox. CAPE uses KVM to run a Windows 10 analysis guest inside the VM, so **nested virtualization must be enabled** on the build host or hypervisor.

## Quick Start

Requires [Packer](https://developer.hashicorp.com/packer/install) ≥ 1.9, [Jsonnet](https://github.com/google/jsonnet), and `/dev/kvm` on the build host.

1. **Clone with submodules**

   ```sh
   git clone --recurse-submodules https://github.com/edmcman/cape-sandbox-vm
   ```

2. **(Optional) Adjust configuration** — see [Configuration](#configuration).

3. **Initialize Packer plugins**

   ```sh
   packer init .
   ```

4. **Build the Windows 10 analysis guest**

   ```sh
   # Fish
   packer build -only=qemu (jsonnet packer-templates/cape-win10.jsonnet | psub) auto-windows-vm/

   # Bash
   packer build -only=qemu <(jsonnet packer-templates/cape-win10.jsonnet) auto-windows-vm/
   ```

5. **Build the CAPE sandbox VM**

   ```sh
   # QEMU/KVM (recommended)
   packer build -only='cape-sandbox.qemu.ubuntu' -var-file=variables.pkrvars.hcl .

   # VMware
   packer build -only='cape-sandbox.vmware-iso.ubuntu' -var-file=variables.pkrvars.hcl .

   # VirtualBox
   packer build -only='cape-sandbox.virtualbox-iso.ubuntu' -var-file=variables.pkrvars.hcl .
   ```

   The build registers the Windows guest with libvirt, takes the analysis snapshot, and configures CAPE automatically.

6. **Boot the VM** in your hypervisor. The web UI is at `http://cape-sandbox.local:8000` (via mDNS) or `http://<vm-ip>:8000`.

## Configuration

All settings have working defaults. To customize before building:

- **CAPE VM** (CPUs, memory, disk, credentials, build options): `variables.pkrvars.hcl`
- **Windows guest** (network, disk, OS settings): `auto-windows-vm/packer-templates/cape-win10.jsonnet`
- **CAPE settings** (reporting, processing, timeouts, etc.): `conf-overrides/`

The Windows guest network settings (`win10_guest_*`) in `variables.pkrvars.hcl` must stay in sync with the values baked into the Windows guest image — if you change them, rebuild both images.

### Output format (Vagrant box)

By default the build leaves the raw builder artifacts in `output-*/` (the `cape-sandbox` qcow2/vmdk/vdi plus the `clean-install` snapshot). To instead package the VM into a Vagrant `.box` (libvirt/VirtualBox/vmware, with nested virt enabled via `files/vagrantfile.template`), build with:

    packer build -only='cape-sandbox.qemu.ubuntu' -var-file=variables.pkrvars.hcl -var enable_vagrant=true .

Add `-var keep_vagrant_input=true` to keep `output-*/` alongside the `.box`. Both toggles live in `variables.pkrvars.hcl`.

### CAPE config overrides

Place partial `.conf` files in `conf-overrides/` using the same filenames as CAPE's config files (e.g. `cuckoo.conf`, `reporting.conf`). Only include the sections and keys you want to change — CAPE merges them with its defaults at runtime via its `custom/conf/` mechanism.

Example — enable the MongoDB reporter and increase the analysis timeout:

```ini
# conf-overrides/reporting.conf
[mongodb]
enabled = yes

# conf-overrides/cuckoo.conf
[timeouts]
default = 120
```
