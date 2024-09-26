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
  default = "./output/image-aarch64"
}

# Define the source image builder - for QEMU
source "qemu" "rocky_linux" {
  iso_url       = "https://download.rockylinux.org/pub/rocky/9.4/isos/aarch64/Rocky-9.4-aarch64-minimal.iso"
  iso_checksum  = "sha256:0a3e9464fe3fb00ec04e3cce138ec4ccfdc2757e6eef50313fe52fe3332f46b5"
  qemu_binary   = "qemu-system-aarch64"
  output_directory = var.output_directory
  http_directory = "."
  disk_size     = "10240"
  memory        = "1024"
  cpu_model     = "max"
  qemuargs = [
    ["-machine", "type=virt"], # no KVM
    # ["-display", "none"],  # if inside docker
    ["-boot", "strict=off"],
  ]
  ssh_port =  22
  ssh_password = "rocky"
  ssh_username = "root"
  ssh_timeout = "30m"
  headless      = false
  ssh_wait_timeout = "30m"
  shutdown_command = "/sbin/halt -h -p"
  boot_command = [
    "<tab><bs><bs><bs><bs><bs>inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/http/ks.cfg<enter><wait>"
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
