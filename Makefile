GO ?= go
JQ ?= jq

DL_DIR ?= dl
ARCH ?= aarch64
MACHINE ?= raspberrypi4-64
TARGET_DIR = $(DL_DIR)/$(ARCH)/$(MACHINE)
CONTAINERS := $(foreach container,$(shell $(JQ) -r '.images | keys | join(" ")' stable.json),$(DL_DIR)/$(ARCH)/$(MACHINE)/$(container).tar)

distro.tar: $(CONTAINERS) docker-image-store-gen/disg
	docker-image-store-gen/disg -unshare -tarpath $(TARGET_DIR) -path dist -out $@

skopeo/bin/skopeo:
	$(MAKE) -C skopeo bin/skopeo

docker-image-store-gen/disg:
	cd docker-image-store-gen && $(GO) build ./cmd/disg

$(TARGET_DIR)/%.tar: skopeo/bin/skopeo
	mkdir -p $(@D)
	./fetch-container-image.sh $(ARCH) $(MACHINE) stable.json $(@D) $*

.PHONY: list-containers
list-containers:
	echo $(CONTAINERS)
