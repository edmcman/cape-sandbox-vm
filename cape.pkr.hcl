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

locals {
  iso_url      = "https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso"
  iso_checksum = "sha256:e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433"

  # Ubuntu 24.04 server ISO uses GRUB; 'c' drops to GRUB console
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/' systemd.mask=ssh",
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
  }
  vmx_remove_ethernet_interfaces = false
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
  ]
}

build {
  name = "cape-sandbox"
  sources = [
    "source.vmware-iso.ubuntu",
    "source.virtualbox-iso.ubuntu",
    "source.qemu.ubuntu",
  ]

  provisioner "shell" {
    execute_command     = "echo '${var.ssh_password}' | {{.Vars}} sudo -E -S bash '{{.Path}}'"
    expect_disconnect   = true
    start_retry_timeout = "10m"
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "UPDATE=${var.update}",
      "SSH_USERNAME=${var.ssh_username}",
      "SSH_PASSWORD=${var.ssh_password}",
    ]
    scripts = [
      "scripts/update.sh",
      "scripts/sshd.sh",
      "scripts/vmware.sh",
      "scripts/virtualbox.sh",
      "scripts/kvm-setup.sh",
      "scripts/cape-install.sh",
      "scripts/cape-network.sh",
      "scripts/cleanup.sh",
    ]
  }
}
