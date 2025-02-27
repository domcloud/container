# rocky-linux-packer.pkr.hcl

# Required Packer version
packer {
  required_version = ">= 1.7.0"

  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "display" {
  type    = string
  default = "none"
}

variable "output_directory" {
  type    = string
  default = "./output/image-x86_64"
}

# Define the source image builder - for QEMU
source "qemu" "ubuntu_linux" {
  iso_url       = "https://old-releases.ubuntu.com/releases/24.04/ubuntu-24.04-live-server-amd64.iso"
  iso_checksum  = "sha256:8762f7e74e4d64d72fceb5f70682e6b069932deedb4949c6975d0f0fe0a91be3"
  qemu_binary   = "qemu-system-x86_64"
  output_directory = var.output_directory
  http_directory = "."
  disk_size     = "40960"
  memory        = "2048"
  cores         = 8
  cpu_model     = "host" # if no KVM use "Haswell-v1"
  ssh_port =  22
  boot_wait = "1s"
  ssh_password = "root"
  ssh_username  = "ubuntu"
  ssh_timeout = "60m" # without KVM can be 10x slower
  headless      = false
  shutdown_command = "/sbin/halt -h -p"
  qemuargs = [
    ["-display", var.display], # "gtk" or "none"
    ["-machine", "type=pc,accel=kvm"], # "type=q35" if no KVM
  ]
  boot_command = ["<esc><esc><esc><esc>e<wait><del>", 
  "<del><del><del><del><del><del><del><del>", 
  "<del><del><del><del><del><del><del><del>", 
  "<del><del><del><del><del><del><del><del>", 
  "<del><del><del><del><del><del><del><del>", 
  "<del><del><del><del><del><del><del><del>", 
  "<del><del><del><del><del><del><del><del>", 
  "<del><del><del><del><del><del><del><del>", 
  "<del><del><del><del><del><del><del><del>", 
  "<del><del><del><del><del><del><del><del>", 
  "<del><del><del><del><del><del><del><del>", 
  "<del><del><del><del><del><del><del><del>", 
  "<del><del><del><del><del><del><del><del>", 
  "<del><del><del><del><del><del><del><del>", 
  "<del><del><del><del><del><del><del><del>", 
  "linux /casper/vmlinuz --- autoinstall  net.ifnames=0 ds=\"nocloud-net;seedfrom=http://{{ .HTTPIP }}:{{ .HTTPPort }}/http/\"<enter><wait>", "initrd /casper/initrd<enter><wait>", "boot<enter>", "<enter><f10><wait>"
  ]
}

# Provision with an external shell script
build {
  sources = ["source.qemu.ubuntu_linux"]

  provisioner "shell" {
    script = "install-ubuntu.sh" 
  }
}
