##############################################################################
# Copyright (c) 2015 Ericsson AB and others.
# stefan.k.berg@ericsson.com
# jonas.bjurel@ericsson.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

TOP := $(shell pwd)
BUILDTAG := loving_daniel

# Edit this to match the GENESIS / OPNFV in your environment
export OPNFV_PUPPET := /home/lmcdasm/MAR24/genesis/common/puppet-opnfv
include ../config.mk

.PHONY: all
all:
	@mkdir -p puppet/modules/opnfv/odl_docker
	@rm -rf tmp
	@mkdir -p tmp
	@cp -Rvp ${OPNFV_PUPPET}/manifests/templates/dockerfile tmp/.
	@docker build -t ${BUILDTAG} tmp/dockerfile/.
	@docker save ${BUILDTAG} > puppet/modules/opnfv/odl_docker/odl_docker_image.tar
	@wget ${DOCKER_REPO}/${DOCKER_TAG} -O  puppet/modules/opnfv/odl_docker/docker-latest
	@echo "OPFNV_PUPPET is: ${OPNFV_PUPPET}"
	@cp -Rvp ${OPNFV_PUPPET}/manifests/templates/dockerfile/compute_scripts  puppet/modules/opnfv

.PHONY: clean
clean:
	@rm -rf tmp
	@rm -rf release

.PHONY: build-clean
build-clean:
	@rm -rf tmp
	@rm -rf release
	@rm -rf puppet/modules/opnfv/odl_docker/odl_docker_image.tar
	@rm -rf puppet/modules/opnfv/odl_docker/docker-latest


.PHONY: release
release:
	# Fetch PP from OPNFV Common
	@cp -Rvp ${OPNFV_PUPPET}/common/puppet-opnfv/manifests/odl_docker.pp ${PUPPET_DEST}
	@cp -Rvp puppet/modules/* $(PUPPET_DEST)
