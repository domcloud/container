init:
	packer init .
build-docker:
	packer build vc.pkr.hcl
run:
	docker compose run domcloud
build-image:
	PACKER_CACHE_DIR=./output/cache PACKER_LOG=1 packer build vm.$(shell uname -m).pkr.hcl
# docker build -t image-build .
# docker run -it --privileged \
# -v "./output:/app/output" \
# image-build

