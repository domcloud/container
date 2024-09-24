PATH="/usr/libexec/qemu-kvm:${PATH}"
export PACKER_CACHE_DIR=/app/output/cache
export PACKER_LOG_PATH=/app/output/packer.log
cd /app
rm -rf ./output/image
packer init vm.$(uname -m).pkr.hcl
packer build vm.$(uname -m).pkr.hcl
 