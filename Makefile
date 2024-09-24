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
