# rocky-linux-packer.pkr.hcl

# Required Packer version
packer {
  required_version = ">= 1.7.0"
}

# Define variables
variable "rocky_version" {
  type    = string
  default = "9.2"
}

variable "output_directory" {
  type    = string
  default = "./output"
}

# Define the source image builder - for QEMU
source "qemu" "rocky_linux" {
  iso_url       = "https://download.rockylinux.org/pub/rocky/9.4/isos/${var.arch}/Rocky-9.4-${var.arch}-minimal.iso"
  output_directory = var.output_directory
  disk_size     = "10240"
  memory        = "1024"
  headless      = true
  accelerator   = "kvm"
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

  post-processor "qemu" {
    output = "rocky-linux-qemu-{{user `rocky_version`}}.qcow2"
  }
}
