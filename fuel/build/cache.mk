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

#export BUILD_BASE = $(shell pwd)
#export CACHE_DIR = "$(BUILD_BASE)/cache"

CACHEDIRS := opendaylight/f_odl/package

CACHEFILES := opendaylight/.odl-build-history
CACHEFILES += opendaylight/.odl-build.log
CACHEFILES += .versions
CACHEFILES += fuel-6.0.1.iso
#CACHEFILES += $(ISOSRC)

CACHECLEAN = $(addsuffix .clean,$(CACHEDIRS))

.PHONY: prepare-cache
prepare-cache: make-cache-dir $(CACHEDIRS) $(CACHEFILES)

.PHONY: make-cache-dir
make-cache-dir:
	@rm -rf ${CACHE_DIR}
	@mkdir ${CACHE_DIR}


.PHONY: clean-cache
clean-cache: $(CACHECLEAN)
	@rm -rf ${CACHE_DIR}

.PHONY: $(CACHEDIRS)
$(CACHEDIRS):
	@mkdir -p $(dir ${CACHE_DIR}/$@)
	@if [ ! -d ${BUILD_BASE}/$@ ]; then\
	   mkdir -p $(dir ${BUILD_BASE}/$@);\
 	   ln -s ${BUILD_BASE}/$@ ${CACHE_DIR}/$@;\
	   rm -rf ${BUILD_BASE}/$@;\
	else\
	   ln -s ${BUILD_BASE}/$@ ${CACHE_DIR}/$@;\
	fi

.PHONY: $(CACHEFILES)
$(CACHEFILES):
	@mkdir -p $(dir ${CACHE_DIR}/$@)
	@if [ ! -f ${BUILD_BASE}/$@ ]; then\
	   mkdir $(dir ${BUILD_BASE}/$@);\
	   echo " " > ${BUILD_BASE}/$@;\
 	   ln -s ${BUILD_BASE}/$@ ${CACHE_DIR}/$@;\
	   rm -f ${BUILD_BASE}/$@;\
	else\
	   ln -s ${BUILD_BASE}/$@ ${CACHE_DIR}/$@;\
	fi

.PHONY: validate-cache
validate-cache:
#	if [ $(shell md5sum ${BUILD_BASE}/config.mk) -ne $(shell cat ${CACHE_DIR}/.versions | grep config.mk awk '{print $NF}') ]; then\
	   echo "Cache does not match current config.mk definition, cache must be rebuilt";\
	   exit 1;\
	fi;

#	if [ $(shell md5sum ${BUILD_BASE}/cache.mk) -ne $(shell cat ${CACHE_DIR}/.versions | grep config.mk awk '{print $NF}') ]; then\
	   echo "Cache does not match current cache.mk definition, cache must be rebuilt";\
	   exit 1;\
	fi;

#	$(MAKE) -C opendaylight validate-cache
#	if [ $? -ne 0 ]; then\
	   echo "Cache does not match current OpenDaylight version, cach must be rebuilt";\
	   exit 1;\
	fi;

#       $(SUBDIRS)

.PHONY: $(CACHECLEAN)
$(CACHECLEAN): %.clean:
	rm -f ${CACHE_DIR}/$*
