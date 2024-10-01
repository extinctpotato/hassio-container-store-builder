GO ?= go
JQ ?= jq

OUT_DIR ?= out
ARCH ?= aarch64
MACHINE ?= raspberrypi4-64
CONTAINER_DIR = $(OUT_DIR)/$(ARCH)/$(MACHINE)
CONTAINERS := $(foreach container,$(shell $(JQ) -r '.images | keys | join(" ")' stable.json),$(CONTAINER_DIR)/$(container).tar)

DISG_OPTIONS =
# Mainly useful in the context of running in CI environments where (very likely):
#
#  1) we're already running as the root user,
#  2) we're inside a container (i.e. the nested namespace situation -- not impossible to pull off, just finicky).
#
ifneq ($(DISG_NO_UNSHARE), y)
	DISG_OPTIONS += -unshare
endif

$(OUT_DIR)/$(ARCH)-$(MACHINE)-distro.img.xz: $(OUT_DIR)/$(ARCH)-$(MACHINE)-distro.tar
	virt-make-fs -t ext4 -s 2G $< $(basename $@) 
	xz $(basename $@)

$(OUT_DIR)/$(ARCH)-$(MACHINE)-distro.tar: $(CONTAINERS) docker-image-store-gen/disg
	docker-image-store-gen/disg -tarpath $(CONTAINER_DIR) -path $(CONTAINER_DIR)/dist $(DISG_OPTIONS) -taglatest -out $@

skopeo/bin/skopeo:
	DISABLE_DOCS=1 \
		     BUILDTAGS=containers_image_openpgp \
		     GOFLAGS="-buildvcs=false" \
		     EXTRA_LDFLAGS="-X=github.com/containers/image/v5/signature.systemDefaultPolicyPath=$(PWD)/skopeo/default-policy.json" \
		     $(MAKE) -C skopeo bin/skopeo

docker-image-store-gen/disg:
	cd docker-image-store-gen && GOFLAGS="-buildvcs=false" $(GO) build ./cmd/disg

$(CONTAINER_DIR)/%.tar: skopeo/bin/skopeo
	mkdir -p $(@D)
	PATH=$(PATH):$(PWD)/skopeo/bin ./fetch-container-image.sh $(ARCH) $(MACHINE) stable.json $(@D) $*

.PHONY: list-containers
list-containers:
	echo $(CONTAINERS)
