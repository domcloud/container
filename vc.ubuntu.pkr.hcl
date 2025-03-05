packer {
  required_version = ">= 1.7.0"

  required_plugins {
    docker = {
      version = ">= 0.0.7"
      source  = "github.com/hashicorp/docker"
    }
  }
}

# Define the source image builder - for Docker
source "docker" "ubuntu" {
  image      = "ubuntu:24.04"  # Use the official Ubuntu image as a base
  commit     = true
}

# Provisioning script to install QEMU and dependencies
build {
  sources = ["source.docker.ubuntu"]

  provisioner "shell" {
    script = "vcsysdaemon.sh" 
  }

  provisioner "shell" {
    script = "install-ubuntu.sh" 
  }
  
  provisioner "shell" {
    script = "preset.sh"
  }

  post-processor "docker-tag" {
    repository = "domcloud-ubuntu-container"
    tag        = ["latest"]
  }
}
