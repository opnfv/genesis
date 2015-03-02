##############################################################################
# Copyright (c) 2015 Ericsson AB and others.
# daniel.smith@ericsson.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

TOP := $(shell pwd)
include ../config.mk

PACKAGE := openjdk-8-jre
VERSION := 8u40~b09-1_amd64
DEB_NAME := $(PACKAGE)_$(VERSION).deb

.PHONY: all
all:    release/pool/main/$(DEB_NAME)

release/pool/main/$(DEB_NAME):
ifeq ($(JAVA_MAIN_REPO),)
	@echo "No config-spec target for Java, nothing to build"
else
	@mkdir -p release/pool/main && \
	cd release/pool/main && \
	wget -N $(JAVA_MAIN_REPO)/$(DEB_NAME)
endif

.PHONY: clean
clean:
	@rm -rf release
	@rm -f $(DEB_DEST)/$(DEB_NAME)


.PHONY: release
release:release/pool/main/$(DEB_NAME)
ifneq ($(JAVA_MAIN_REPO),)
	@cp release/pool/main/$(DEB_NAME) $(DEB_DEST)
	@cp -Rvp puppet/modules/* $(PUPPET_DEST)
endif

