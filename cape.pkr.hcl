packer {
  required_plugins {
    vmware = {
      source  = "github.com/hashicorp/vmware"
      version = "~> 1"
    }
    virtualbox = {
      source  = "github.com/hashicorp/virtualbox"
      version = "~> 1"
    }
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
    vagrant = {
      source  = "github.com/hashicorp/vagrant"
      version = ">= 1.1.7"
    }
  }
}

variable "vm_name" {
  type    = string
  default = "cape-sandbox"
}
variable "hostname" {
  type    = string
  default = "cape-sandbox"
}
variable "ssh_username" {
  type    = string
  default = "cape"
}
variable "ssh_password" {
  type    = string
  default = "cape"
}
variable "cpus" {
  type    = number
  default = 4
}
variable "memory" {
  type    = number
  default = 8192
}
variable "disk_size" {
  type    = number
  default = 102400
}
variable "headless" {
  type    = bool
  default = false
}
variable "update" {
  type    = string
  default = "true"
}
variable "win10_guest_mac" {
  type    = string
  default = "52:54:00:ca:fe:10"
}
variable "win10_guest_ip" {
  type    = string
  default = "192.168.56.10"
}
variable "win10_guest_gateway" {
  type    = string
  default = "192.168.56.1"
}
variable "enable_vagrant" {
  type    = bool
  default = false
}
variable "keep_vagrant_input" {
  type    = bool
  default = false
}

locals {
  iso_url      = "https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso"
  iso_checksum = "sha256:e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433"

  # Ubuntu 24.04 server ISO uses GRUB; 'c' drops to GRUB console
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/' systemd.mask=ssh console=ttyS0",
    "<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]
}

source "vmware-iso" "ubuntu" {
  vm_name          = var.vm_name
  guest_os_type    = "ubuntu-64"
  headless         = var.headless
  http_directory   = "http"
  iso_url          = local.iso_url
  iso_checksum     = local.iso_checksum
  disk_size        = var.disk_size
  memory           = var.memory
  cores            = var.cpus
  boot_wait        = "5s"
  boot_command     = local.boot_command
  ssh_username     = var.ssh_username
  ssh_password     = var.ssh_password
  ssh_timeout      = "7200s"
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
  output_directory = "output-vmware-cape"
  vmx_data = {
    # Expose VMX instructions to the guest for nested KVM
    "vhv.enable"              = "TRUE"
    "ethernet0.pciSlotNumber" = "32"
    # Serial port for installer debug output
    "serial0.present"         = "TRUE"
    "serial0.fileType"        = "file"
    "serial0.fileName"        = "serial.log"
  }
  vmx_remove_ethernet_interfaces = false
  snapshot_name                  = "clean-install"
}

source "virtualbox-iso" "ubuntu" {
  vm_name              = var.vm_name
  guest_os_type        = "Ubuntu_64"
  headless             = var.headless
  http_directory       = "http"
  iso_url              = local.iso_url
  iso_checksum         = local.iso_checksum
  disk_size            = var.disk_size
  hard_drive_interface = "sata"
  # Skip guest additions ISO upload; server VM doesn't need them
  guest_additions_mode = "disable"
  boot_wait            = "5s"
  boot_command         = local.boot_command
  ssh_username         = var.ssh_username
  ssh_password         = var.ssh_password
  ssh_timeout          = "7200s"
  shutdown_command     = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
  output_directory     = "output-vbox-cape"
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--memory", "${var.memory}"],
    ["modifyvm", "{{.Name}}", "--cpus", "${var.cpus}"],
    ["modifyvm", "{{.Name}}", "--nested-hw-virt", "on"],
    ["modifyvm", "{{.Name}}", "--ioapic", "on"],
    ["modifyvm", "{{.Name}}", "--rtcuseutc", "on"],
    ["modifyvm", "{{.Name}}", "--graphicscontroller", "vmsvga"],
    ["modifyvm", "{{.Name}}", "--vram", "16"],
    # Serial port for installer debug output
    ["modifyvm", "{{.Name}}", "--uart1", "0x3f8", "4"],
    ["modifyvm", "{{.Name}}", "--uartmode1", "file", "serial.log"],
  ]
  vboxmanage_post = [
    ["snapshot", "{{.Name}}", "take", "clean-install"],
  ]
}

source "qemu" "ubuntu" {
  vm_name          = var.vm_name
  headless         = var.headless
  http_directory   = "http"
  iso_url          = local.iso_url
  iso_checksum     = local.iso_checksum
  disk_size        = "${var.disk_size}M"
  # KVM required on build host; -cpu host exposes VMX for nested KVM in guest
  accelerator      = "kvm"
  machine_type     = "q35"
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  format           = "qcow2"
  memory           = var.memory
  cpus             = var.cpus
  boot_wait        = "5s"
  boot_command     = local.boot_command
  ssh_username     = var.ssh_username
  ssh_password     = var.ssh_password
  ssh_timeout      = "7200s"
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
  output_directory = "output-qemu-cape"
  qemuargs = [
    ["-cpu", "host"],
    ["-serial", "file:serial.log"],
  ]
}

build {
  name = "cape-sandbox"
  sources = [
    "source.vmware-iso.ubuntu",
    "source.virtualbox-iso.ubuntu",
    "source.qemu.ubuntu",
  ]

  provisioner "shell-local" {
    command = "mkdir -p toupload && tar cf toupload/capev2.tar -C CAPEv2 . && tar cf toupload/conf-overrides.tar conf-overrides/"
  }

  provisioner "file" {
    source      = "toupload"
    destination = "/tmp/"
  }

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -E -S bash '{{.Path}}'"
    inline          = ["mkdir -p /opt/CAPEv2 && tar xf /tmp/toupload/capev2.tar -C /opt/CAPEv2 && tar xf /tmp/toupload/conf-overrides.tar -C /tmp && rm -rf /tmp/toupload"]
  }

  provisioner "shell" {
    execute_command     = "echo '${var.ssh_password}' | {{.Vars}} sudo -E -S bash '{{.Path}}'"
    expect_disconnect   = true
    start_retry_timeout = "10m"
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "UPDATE=${var.update}",
      "SSH_USERNAME=${var.ssh_username}",
      "SSH_PASSWORD=${var.ssh_password}",
      "WIN10_GUEST_MAC=${var.win10_guest_mac}",
      "WIN10_GUEST_IP=${var.win10_guest_ip}",
      "WIN10_GUEST_GATEWAY=${var.win10_guest_gateway}",
    ]
    scripts = [
      "scripts/update.sh",
      "scripts/sshd.sh",
      "scripts/mdns.sh",
      "scripts/vmware.sh",
      "scripts/virtualbox.sh",
      "scripts/cape-install.sh",
      "scripts/cape-network.sh",
      "scripts/inetsim.sh",
      "scripts/apply-config-overrides.sh",
    ]
  }

  provisioner "file" {
    source      = "files/cape-win10.xml.tmpl"
    destination = "/tmp/cape-win10.xml.tmpl"
  }

  provisioner "shell" {
    inline = ["mkdir -p /tmp/win-guest"]
  }

  provisioner "file" {
    source      = "auto-windows-vm/output-qemu-cape-win10/"
    destination = "/tmp/win-guest"
  }

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -E -S bash '{{.Path}}'"
    inline = [
      "cp /tmp/win-guest/cape-win10 /var/lib/libvirt/images/cape-win10.qcow2",
      "chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/cape-win10.qcow2 2>/dev/null || true",
      "mkdir -p /var/lib/libvirt/qemu/nvram",
      "cp /tmp/win-guest/efivars.fd /var/lib/libvirt/qemu/nvram/cape-win10_VARS.fd",
      "sed 's|CAPE_QCOW2_PATH|/var/lib/libvirt/images/cape-win10.qcow2|g; s|CAPE_WIN10_GUEST_MAC|${var.win10_guest_mac}|g' /tmp/cape-win10.xml.tmpl | virsh define /dev/stdin",
      "rm -rf /tmp/win-guest /tmp/cape-win10.xml.tmpl",
    ]
  }

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -E -S bash '{{.Path}}'"
    inline = [
      "virsh start cape-win10",
      "echo 'Waiting for CAPE agent on ${var.win10_guest_ip}:8000...'",
      "timeout 300 bash -c 'until nc -z ${var.win10_guest_ip} 8000 2>/dev/null; do sleep 5; done' || echo 'WARNING: CAPE agent did not respond on ${var.win10_guest_ip}:8000 within 300s -- snapshot will be taken without a running agent'",
      "mkdir -p /var/lib/libvirt/qemu/snapshot/cape-win10",
      "virsh snapshot-create-as --domain cape-win10 --name cape-ready --description 'CAPE analysis baseline' --memspec file=/var/lib/libvirt/qemu/snapshot/cape-win10/cape-ready.mem,snapshot=external --diskspec sda,snapshot=external --live",
      "virsh shutdown --domain cape-win10 --mode acpi",
      "timeout 120 bash -c 'until virsh domstate cape-win10 | grep -q \"shut off\"; do sleep 3; done'",
    ]
  }

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -E -S bash '{{.Path}}'"
    scripts         = ["scripts/cleanup.sh"]
  }

  post-processor "shell-local" {
    only   = ["qemu.ubuntu"]
    inline = ["qemu-img snapshot -c clean-install output-qemu-cape/${var.vm_name}"]
  }

  post-processor "vagrant" {
    only                = var.enable_vagrant ? [] : ["__vagrant_disabled__"]
    keep_input_artifact = var.keep_vagrant_input
    vagrantfile_template = "files/vagrantfile.template"
    output               = "${var.vm_name}-{{.Provider}}.box"
  }
}
