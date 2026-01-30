#!/bin/bash

export PACKER_CACHE_DIR=$PWD/output/cache
export PACKER_LOG_PATH=$PWD/output/packer.log
export PACKER_LOG=1

QEMU_DISPLAY=${QEMU_DISPLAY:-"none"}
OS=${OS:-"rocky"}
ARCH=$(uname -m) # due to KVM
rm -rf $PWD/output/image-$ARCH
packer init vm.$OS.$ARCH.pkr.hcl
packer build -var "display=$QEMU_DISPLAY" vm.$OS.$ARCH.pkr.hcl
