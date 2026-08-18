vm_name      = "cape-sandbox"

# Windows 10 guest network config — must match cape-win10.jsonnet in auto-windows-vm.
win10_guest_mac     = "52:54:00:ca:fe:10"
win10_guest_ip      = "192.168.56.10"
win10_guest_gateway = "192.168.56.1"
hostname     = "cape-sandbox"
ssh_username = "cape"
ssh_password = "cape"
cpus         = 4
memory       = 8192
disk_size    = 102400
headless     = false
update       = "true"

# Vagrant box packaging. Default: keep raw output-*/ artifacts, no .box.
enable_vagrant     = false
keep_vagrant_input  = false  # set true with enable_vagrant=true to keep output-*/ AND the .box
