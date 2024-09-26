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
  default = "./output/image-x86_64"
}

# Define the source image builder - for QEMU
source "qemu" "rocky_linux" {
  iso_url       = "https://download.rockylinux.org/pub/rocky/9.4/isos/x86_64/Rocky-9.4-x86_64-minimal.iso"
  iso_checksum  = "sha256:ee3ac97fdffab58652421941599902012179c37535aece76824673105169c4a2"
  qemu_binary   = "qemu-system-x86_64"
  output_directory = var.output_directory
  http_directory = "."
  disk_size     = "10240"
  memory        = "1024"
  # cpu_model     = "Haswell-v1" # no KVM
  cpu_model     = "host" # with KVM
  ssh_port =  22
  boot_wait = "1s"
  ssh_password = "rocky"
  ssh_username = "root"
  ssh_timeout = "30m" # without KVM can be 10x slower
  headless      = false
  shutdown_command = "/sbin/halt -h -p"
  qemuargs = [
    # ["-machine", "type=q35"], # if no KVM
    # ["-display", "gtk"], # if has GTK
    ["-display", "none"],
    ["-machine", "type=pc,accel=kvm"],
  ]
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
