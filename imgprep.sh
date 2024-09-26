export PACKER_CACHE_DIR=$PWD/output/cache
export PACKER_LOG_PATH=$PWD/output/packer.log
export PACKER_LOG=1
ARCH=$(uname -m) # due to KVM
rm -rf $PWD/output/image-$ARCH
packer init vm.$ARCH.pkr.hcl
packer build vm.$ARCH.pkr.hcl
 