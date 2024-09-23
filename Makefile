build-docker:
	packer build vc.pkr.hcl
run:
	docker compose run domcloud
build-image:
	packer build vm.pkr.hcl
