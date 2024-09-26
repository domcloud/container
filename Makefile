init:
	packer init .
build-docker:
	packer build vc.pkr.hcl
run:
	docker compose run domcloud
build-image:
	sh ./imgprep.sh

build-image-in-docker:
	docker build -t image-build .
	docker run --privileged \
	-v "./output:/app/output" \
	image-build

convert-image-in-docker:
	docker run --privileged \
	-v "./output:/app/output" \
	-it image-build qemu-img convert \
	-f qcow2 output/image-$(shell uname -m)/domcloud.qcow2 -O vhdx output/image-$(shell uname -m)/domcloud.vhdx
	cd output/image-$(shell uname -m) && tar -czvf domcloud-$(shell uname -m).qcow2.tar.gz domcloud-$(shell uname -m).qcow2
	cd output/image-$(shell uname -m) && tar -czvf domcloud-$(shell uname -m).vhdx.tar.gz domcloud-$(shell uname -m).vhdx
	cd output/image-$(shell uname -m) && find . -type f -exec sha256sum {} > checksums.txt \;
