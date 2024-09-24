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

variable "arch" {
  type    = string
  default = "aarch64"
}


# Define the source image builder - for QEMU
source "qemu" "rocky_linux" {
  iso_url       = "https://download.rockylinux.org/pub/rocky/9.4/isos/x86_64/Rocky-9.4-x86_64-boot.iso"
  iso_checksum  = "sha256:c7e95e3dba88a1f68fff8b7d4e66adf6f76ac4fba2e246a83c46ab79574c78a8"
  output_directory = var.output_directory
  http_directory = "http"
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
  headless      = false
  boot_command = [
    "<tab><bs><bs><bs><bs><bs>inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ksamd.cfg<enter><wait>"
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
