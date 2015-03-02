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

include config.mk

export BUILD_BASE = $(shell pwd)
export DEB_DEST := $(BUILD_BASE)/release/packages/ubuntu/pool/main
export PUPPET_DEST := $(BUILD_BASE)/release/puppet/modules

ISOSRC = file:$(shell pwd)/fuel-6.0.1.iso
ISOCACHE = $(shell pwd)/$(shell basename $(ISOSRC))
PRODNO = "OPNFV_BGS"
REVSTATE = "P0000"
NEWISO = $(shell pwd)/release/opnfv-${REVSTATE}.iso
DOCKERIMG = opnfv.org/ubuntu-builder:14.04
# Note! Invoke with "make REVSTATE=RXXXX iso" to make release build!
# Invoke with ICOCACHE=/full/path/to/iso if cached ISO is in non-standard location.
#
# END of variables to customize
#############################################################################
export TOPDIR := $(shell pwd)
ORIGDIR := $(TOPDIR)/origiso

SUBDIRS := f_isoroot
SUBDIRS += f_opnfv_puppet
SUBDIRS += f_osnaily
SUBDIRS += f_l23network
SUBDIRS += f_resolvconf
SUBDIRS += f_ntp
#SUBDIRS += f_gif
#SUBDIRS += f_libnss
#SUBDIRS += f_libpcs
#SUBDIRS += f_libxt
#SUBDIRS += f_comm_java
#SUBDIRS += f_ca_cert
#SUBDIRS += f_atk_wrap
#SUBDIRS += f_jre_head
#SUBDIRS += f_jre
#SUBDIRS += f_java
#SUBDIRS += f_odl



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
	cd /tmp && git clone $(FUEL_MAIN_REPO)
	cd /tmp/fuel-main && git checkout $(FUEL_MAIN_TAG)
	# Setup cgroups for docker-in-docker
	sudo /root/enable_dockerx2
	# Patch to fix race condition when doing "Docker-in-Docker" build
	cd /tmp/fuel-main && patch -p1 < $(TOPDIR)/fuel-main_1.patch
	# Patch to make the sandbox chroot in Fuel succeed with package
	# installation in a Docker build
	cd /tmp/fuel-main && patch -p1 < $(TOPDIR)/fuel-main_2.patch
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
	ORIGISO=$(ISOCACHE) REVSTATE=$(REVSTATE) $(MAKE) -C $@ -f Makefile release

.PHONY: prepare
prepare:
	$(MAKE) -C opendaylight -f Makefile setup

.PHONY: odl
odl:
	$(MAKE) -C opendaylight -f Makefile

.PHONY: build-clean $(SUBCLEAN)
build-clean: $(SUBCLEAN)
	$(MAKE) -C patch-packages -f Makefile clean
	@rm -Rf release
	@rm -Rf newiso
	@rm -f $(NEWISO)

.PHONY: clean $(SUBCLEAN)
clean: prepare $(SUBCLEAN)
	$(MAKE) -C patch-packages -f Makefile clean
	$(MAKE) -C opendaylight -f Makefile clean
	@rm -f *.iso
	@rm -Rf release
	@rm -Rf newiso
	@rm -f f_odl
	@rm -f $(NEWISO)

$(SUBCLEAN): %.clean:
	$(MAKE) -C $* -f Makefile clean

# Todo: Make things smarter - we shouldn't need to clean everything
# betwen make invocations.
.PHONY: iso
iso:	prepare build-clean odl $(ISOCACHE) $(SUBDIRS) patch-packages
	install/install.sh iso $(ISOCACHE) $(NEWISO) $(PRODNO) $(REVSTATE)
	@printf "\n\nProduct ISO is $(NEWISO)\n\n"
