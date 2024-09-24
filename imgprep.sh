export PACKER_CACHE_DIR=$PWD/output/cache
export PACKER_LOG_PATH=$PWD/output/packer.log
export PACKER_LOG=1
rm -rf $PWD/output/image
packer init vm.$(uname -m).pkr.hcl
packer build vm.$(uname -m).pkr.hcl
 