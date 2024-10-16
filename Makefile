init:
	packer init .
build-container:
	packer build vc.pkr.hcl
run-container:
	docker compose run domcloud
build-image-gtk:
	DISPLAY=gtk sh ./imgprep.sh

build-image:
	docker build -t image-build .
	docker run --privileged \
	-v "./output:/app/output" \
	image-build

convert-image:
# Optimized ESXi 6.0 Compatible VMDK
	docker run --privileged \
	-v "./output:/app/output" \
	-it image-build qemu-img convert \
	-f qcow2 -O vmdk -o adapter_type=lsilogic,subformat=streamOptimized,compat6  \
	output/image-$(shell uname -m)/{packer-rocky_linux,domcloud-$(shell uname -m).vmdk}
# Optimized QCOW2 (Shrunk by ~1.5 GB)
	docker run --privileged \
	-v "./output:/app/output" \
	-e LIBGUESTFS_DEBUG=1 -e LIBGUESTFS_TRACE=1 -it image-build virt-sparsify \
	output/image-$(shell uname -m)/{packer-rocky_linux,domcloud-$(shell uname -m).qcow2}
	cd output/image-$(shell uname -m) && find . -type f -exec sha256sum {} > checksums.txt \;
