##############################################################################
# Copyright (c) 2015 Ericsson AB and others.
# stefan.k.berg@ericsson.com
# jonas.bjurel@ericsson.com
# dradez@redhat.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

SHELL = /bin/bash
############################################################################
# BEGIN of variables to customize
#
#Input args
export UNIT_TEST = FALSE
export INTERACTIVE = TRUE
export ISOSRC = file:$(shell pwd)/CentOS-7.0-1406-x86_64-Minimal.iso
export ISOCACHE = $(shell pwd)/$(shell basename $(ISOSRC))
export PRODNO = "OPNFV_BGS"
export REVSTATE = "P0000"
export NEWISO = $(shell pwd)/release/OPNFV-CentOS-7-x86_64-${REVSTATE}.iso
export VBOXRPM = $(shell pwd)/VirtualBox-4.3-4.3.26_98988_fedora18-1.x86_64.rpm
export VAGRANTRPM = $(shell pwd)/vagrant_1.7.2_x86_64.rpm

# Note! Invoke with "make REVSTATE=RXXXX all" to make release build!
# Invoke with ICOCACHE=/full/path/to/iso if cached ISO is in non-standard location.

#Build variables
export BUILD_BASE := $(shell pwd)
export CACHE_DIR := $(BUILD_BASE)/cache
export VERSION_FILE := $(BUILD_BASE)/.versions
export TOPDIR := $(shell pwd)

CENTDIR := $(TOPDIR)/centiso
#
# END of variables to customize
#############################################################################

SUBCLEAN = $(addsuffix .clean,$(SUBDIRS))


.PHONY: all
all: iso
	@echo "Versions of cached build results built by" $(shell hostname) "at" $(shell date -u) > $(VERSION_FILE)
	@echo "cache.mk" $(shell md5sum $(BUILD_BASE)/cache.mk | cut -f1 -d " ") >> $(VERSION_FILE)
	@echo "config.mk" $(shell md5sum $(BUILD_BASE)/config.mk | cut -f1 -d " ") >> $(VERSION_FILE)

############################################################################
# BEGIN of Include definitions
#
include config.mk
include cache.mk
#
# END Include definitions
#############################################################################

$(ISOCACHE):
	#cp ~/Downloads/opnfv_iso/CentOS-7.0-1406-x86_64-Minimal.iso $(ISOCACHE)

.PHONY: mount-centiso umount-centiso
mount-centiso: $(ISOCACHE)
	@echo "Mounting CentOS ISO in $(CENTDIR)"
	@mkdir -p $(CENTDIR)
	@fuseiso $(ISOCACHE) $(CENTDIR)

umount-centiso:
	@set +e
	@echo "Unmounting CentOS ISO from $(CENTDIR)"
	@fusermount -u $(CENTDIR)
	@rmdir $(CENTDIR)
	@set -e

.PHONY: build-clean $(SUBCLEAN)
build-clean: $(SUBCLEAN)
	@rm -Rf centos
	@rm -Rf release
	@rm -Rf newiso
	@rm -f $(NEWISO)

.PHONY: clean $(SUBCLEAN)
clean:  clean-cache $(SUBCLEAN)
	@rm -f *.iso
	@rm -Rf release
	@rm -Rf newiso
	@rm -f $(NEWISO)
	@rm -f $(BUILD_BASE)/.versions

$(SUBCLEAN): %.clean:
	$(MAKE) -C $* -f Makefile clean

# Todo: Make things smarter - we shouldn't need to clean everything
# betwen make invocations.
.PHONY: iso
iso:	build-clean mount-centiso $(ISOCACHE) $(VBOXRPM) $(VAGRANTRPM)
	@mkdir centos release
	cp -r $(CENTDIR)/* centos
	@make umount-centiso
	# modify the installer iso's contents
	@rm -rf centos/repodata
	@cp -f isolinux.cfg centos/isolinux/isolinux.cfg
	@cp $(VBOXRPM) centos/Packages
	@cp $(VAGRANTRPM) centos/Packages
	# regenerate yum repo data
	@echo "Generating new yum metadata"
	createrepo centos/Packages -g ../../c7-opnfv-x86_64-comps.xml -o centos
	# build the iso
	@echo "Building OPNFV iso"
	mkisofs -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table -V "OPNFV CentOS 7 x86_64" -R -J -v -T -o $(NEWISO) centos
	@printf "\n\nISO is built at $(NEWISO)\n\n"
