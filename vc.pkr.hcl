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
source "docker" "rocky_linux" {
  image      = "rockylinux:9"  # Use the official Rocky Linux image as a base
  commit     = true
}

# Provisioning script to install QEMU and dependencies
build {
  sources = ["source.docker.rocky_linux"]

  provisioner "shell" {
    script = "vcsysdaemon.sh" 
  }

  provisioner "shell" {
    script = "install.sh" 
  }
  
  provisioner "shell" {
    script = "preset.sh"
  }

  post-processor "docker-tag" {
    repository = "domcloud-container"
    tag        = ["latest"]
  }
}
