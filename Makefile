init:
	packer init .
build-container:
	packer build vc.pkr.hcl
run-container:
	docker compose run domcloud
build-image-gtk:
	QEMU_DISPLAY=gtk sh ./imgprep.sh
build-image-cocoa:
	QEMU_DISPLAY=cocoa sh ./imgprep.sh

build-image:
	docker build -t image-build .
	docker run --privileged \
	-v "./output:/app/output" \
	image-build

UNAME_M := $(shell uname -m)
OUTPUT_DIR := output/image-$(UNAME_M)

VMDK_FILE := $(OUTPUT_DIR)/domcloud-$(UNAME_M).vmdk
QCOW2_FILE := $(OUTPUT_DIR)/domcloud-$(UNAME_M).qcow2
PACKER_FILE := $(OUTPUT_DIR)/packer-rocky_linux
CHECKSUM_FILE := $(OUTPUT_DIR)/checksums.txt

convert-image: $(VMDK_FILE) $(QCOW2_FILE) $(CHECKSUM_FILE)

$(VMDK_FILE): $(PACKER_FILE)
# Optimized ESXi 6.0 Compatible VMDK
	docker run --privileged \
	-v "./output:/app/output" \
	-it image-build qemu-img convert \
	-f qcow2 -O vmdk -o adapter_type=lsilogic,subformat=streamOptimized,compat6  \
	$(PACKER_FILE) $(VMDK_FILE)

$(QCOW2_FILE): $(PACKER_FILE)
# Optimized QCOW2 (Shrunk by ~1.5 GB)
	docker run --privileged \
	-v "./output:/app/output" \
	-e LIBGUESTFS_DEBUG=1 -e LIBGUESTFS_TRACE=1 -it image-build virt-sparsify \
	$(PACKER_FILE) $(QCOW2_FILE)

$(CHECKSUM_FILE): $(VMDK_FILE) $(QCOW2_FILE)
# Generate checksum
	cd $(OUTPUT_DIR) && find . -type f -exec sha256sum {} \; > checksums.txt
