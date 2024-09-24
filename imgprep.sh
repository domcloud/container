PACKER=packer_1.10.3_linux_$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "amd64" ) 
curl -fsSL https://releases.hashicorp.com/packer/1.10.3/$PACKER.zip -o /tmp/packer.zip 
unzip /tmp/packer.zip -d /usr/local/bin 
rm /tmp/packer.zip

PATH="/usr/libexec/qemu-kvm:${PATH}"
export PACKER_CACHE_DIR=/app/output/cache
export PACKER_LOG=1
export PACKER_LOG_PATH=/app/output/packer.log
env
rm -rf ./output/image
packer init .
packer build vm.$(uname -m).pkr.hcl
 