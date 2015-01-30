##############################################################################
# Copyright (c) 2015 Ericsson AB and others.
# stefan.k.berg@ericsson.com
# jonas.bjurel@ericsson.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

CONTEXT1 := opnfv.org/ubuntu:12.04
CONTEXT2 := opnfv.org/ubuntu-builder:12.04

.PHONY: docker all

all:	create-docker-ubuntu populate-docker-ubuntu
	./runcontext ${CONTEXT2} make test

.PHONY:	create-docker-ubuntu
create-docker-ubuntu:
	/usr/bin/docker run --rm -i -t ${CONTEXT1} date || \
	sudo mkimage/mkimage.sh -t opnfv.org/ubuntu:12.04 debootstrap --include=ubuntu-minimal --components=main,universe precise

.PHONY: populate-docker-ubuntu
populate-docker-ubuntu:
	/usr/bin/docker build --rm=true -t opnfv.org/ubuntu-builder:12.04 ubuntu-builder
	/usr/bin/docker tag -f opnfv.org/ubuntu-builder:12.04 opnfv.org/ubuntu-builder

.PHONY:	test
test:
	@hostname
	@date
