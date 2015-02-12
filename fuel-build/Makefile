##############################################################################
# Copyright (c) 2015 Ericsson AB and others.
# stefan.k.berg@ericsson.com
# jonas.bjurel@ericsson.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

############################################################################
# BEGIN of variables to customize
#
SHELL = /bin/bash
ISOSRC = file:$(shell pwd)/fuel-5.1.1.iso
ISOCACHE = $(shell pwd)/$(shell basename $(ISOSRC))
PRODUCT_NAME = "OPNFV_BGS"
VERSION = "P0000"
NEWISO = $(shell pwd)/release/opnfv-${VERSION}.iso
DOCKERIMG = opnfv.org/ubuntu-builder:14.04
# Note! Invoke with "make VERSION=RXXXX iso" to make release build!
# Invoke with ICOCACHE=/full/path/to/iso if cached ISO is in non-standard location.
#
# END of variables to customize
#############################################################################
TOPDIR := $(shell pwd)
ORIGDIR := $(TOPDIR)/origiso

SUBDIRS := f_isoroot
SUBDIRS += f_opnfv_puppet
SUBDIRS += f_osnaily
SUBDIRS += f_l23network
SUBDIRS += f_resolvconf
SUBDIRS += f_ntp

# f_example is only an example of how to generate a .deb package and
# should not be enabled in official builds.
#SUBDIRS += f_example

SUBCLEAN = $(addsuffix .clean,$(SUBDIRS))

.PHONY: all
all:	
	@docker version >/dev/null 2>&1 || (echo 'No Docker installation available'; exit 1)
	@make -C docker
	@docker/runcontext $(DOCKERIMG) $(MAKE) $(MAKEFLAGS) iso

$(ISOCACHE):
	# Clone Fuel to non-persistent location and build
	cd /tmp && git clone https://github.com/stackforge/fuel-main
	cd /tmp/fuel-main && git checkout 5.1.1
	# Setup cgroups for docker-in-docker
	sudo /root/enable_dockerx2
	# Patch to fix race condition when doing "Docker-in-Docker" build
	cd /tmp/fuel-main && patch -p1 < $(TOPDIR)/fuel-main.patches
	# Remove Docker optimizations, otherwise multistrap will fail during
	# Fuel build.
	sudo rm -f /etc/apt/apt.conf.d/docker*
	#
	cd /tmp/fuel-main && ./prepare-build-env.sh
	cd /tmp/fuel-main && make iso
	mv /tmp/fuel-main/build/artifacts/fuel*.iso .

.PHONY: mount-origiso umount-origiso
mount-origiso: $(ISOCACHE)
	@echo "Mounting original ISO in $(ORIGDIR)"
	@mkdir -p $(ORIGDIR)
	@fuseiso $(ISOCACHE) $(ORIGDIR)

umount-origiso:
	@echo "Unmounting original ISO from $(ORIGDIR)"
	@fusermount -u $(ORIGDIR)
	@rmdir $(ORIGDIR)

.PHONY: $(SUBDIRS)
$(SUBDIRS):
	@mkdir -p release/packages/ubuntu/pool/main release/puppet/modules release/isoroot
	$(MAKE) -C $@ -f Makefile release

.PHONY: patch-packages
patch-packages:
	ORIGISO=$(ISOCACHE) VERSION=$(VERSION) $(MAKE) -C $@ -f Makefile release

.PHONY: clean $(SUBCLEAN)
clean: $(SUBCLEAN)
	$(MAKE) -C patch-packages -f Makefile clean
	@rm -Rf release
	@rm -Rf newiso
	@rm -f $(NEWISO)

$(SUBCLEAN): %.clean:
	$(MAKE) -C $* -f Makefile clean

# Todo: Make things smarter - we shouldn't need to clean everything
# betwen make invocations.
.PHONY: iso
iso:	clean $(ISOCACHE) $(SUBDIRS) patch-packages
	install/install.sh iso $(ISOCACHE) $(NEWISO) $(PRODUCT_NAME) $(VERSION)
	@printf "\n\nProduct ISO is $(NEWISO)\n\n"
