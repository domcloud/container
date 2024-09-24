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

variable "output_directory" {
  type    = string
  default = "./output/image"
}

# Define the source image builder - for QEMU
source "qemu" "rocky_linux" {
  iso_url       = "https://download.rockylinux.org/pub/rocky/9.4/isos/aarch64/Rocky-9.4-aarch64-boot.iso"
  iso_checksum  = "sha256:c6244d1a94ddf1e91ea68f2667aaed218a742a985abb76c3486a85b72819d9e2"
  qemu_binary   = "qemu-system-aarch64"
  output_directory = var.output_directory
  http_directory = "."
  disk_size     = "10240"
  memory        = "1024"
  cpu_model     = "cortex-a57"
  qemuargs = [
    ["-machine", "type=virt"],
    ["-boot", "strict=off"],
    ["-display", "none"]
  ]
  ssh_port =  22
  ssh_password = "packer"
  ssh_username = "packer"
  ssh_timeout = "30m"
  headless      = false
  ssh_wait_timeout = "30m"
  boot_command = [
    "<tab><bs><bs><bs><bs><bs>inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/http/ksarm.cfg<enter><wait>"
  ] 
}

# Provision with an external shell script
build {
  sources = ["source.qemu.rocky_linux"]

  provisioner "shell" {
    script = "install.sh" 
  }
  
  provisioner "shell" {
    script = "preset.sh"
  }
}
