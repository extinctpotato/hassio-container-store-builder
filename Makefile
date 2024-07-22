GO ?= go
JQ ?= jq

OUT_DIR ?= out
ARCH ?= aarch64
MACHINE ?= raspberrypi4-64
CONTAINER_DIR = $(OUT_DIR)/$(ARCH)/$(MACHINE)
CONTAINERS := $(foreach container,$(shell $(JQ) -r '.images | keys | join(" ")' stable.json),$(CONTAINER_DIR)/$(container).tar)

$(OUT_DIR)/$(ARCH)-$(MACHINE)-distro.tar: $(CONTAINERS) docker-image-store-gen/disg
	docker-image-store-gen/disg -unshare -tarpath $(CONTAINER_DIR) -path $(CONTAINER_DIR)/dist -out $@

skopeo/bin/skopeo:
	$(MAKE) -C skopeo bin/skopeo

docker-image-store-gen/disg:
	cd docker-image-store-gen && $(GO) build ./cmd/disg

$(CONTAINER_DIR)/%.tar: skopeo/bin/skopeo
	mkdir -p $(@D)
	./fetch-container-image.sh $(ARCH) $(MACHINE) stable.json $(@D) $*

.PHONY: list-containers
list-containers:
	echo $(CONTAINERS)
