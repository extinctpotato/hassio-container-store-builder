GO ?= go

distro.tar: containers docker-image-store-gen/disg
	docker-image-store-gen/disg -unshare -tarpath dst -path dist -out $@

skopeo/bin/skopeo:
	$(MAKE) -C skopeo bin/skopeo

docker-image-store-gen/disg:
	cd docker-image-store-gen && $(GO) build ./cmd/disg

.PHONY: containers
containers: skopeo/bin/skopeo
	mkdir -p dl dst dist
	./fetch-container-image.sh aarch64 raspberrypi4-64 stable.json dl dst
