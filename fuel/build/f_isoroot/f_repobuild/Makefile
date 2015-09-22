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
DOCKNAME = fuelrepo
DOCKVERSION = 1.0

.PHONY: all
all: .nailgun

.fuel-createmirror:
	sudo apt-get install -y rsync python dpkg-dev fakeroot openssl
	sudo ln -s `pwd` /var/www
	sudo mkdir /var/log/mirror-sync
	sudo chmod 777 /var/log/mirror-sync
	rm -rf tmpiso tmpdir
	mkdir tmpiso
	fuseiso ${ISOCACHE} tmpiso
	cp tmpiso/ubuntu/pool/main/f/fuel-createmirror/fuel-createmirror_6.1*.deb .
	fusermount -u tmpiso
	rm -rf tmpiso
	sudo dpkg -i fuel-createmirror_6.1*.deb
	sudo sed -i 's/DOCKER_MODE=true/DOCKER_MODE=false/' /etc/fuel-createmirror/common.cfg
	touch .fuel-createmirror


.PHONY: clean
clean:
	# Deliberately not cleaning nailgun directory to speed up multiple builds
	@rm -rf ../release/opnfv/nailgun fuel-createmirror_6.1*.deb

.PHONY: release
release:.nailgun
	@rm -Rf ../release/opnfv/nailgun
	@mkdir -p ../release/opnfv
	@cp -Rp nailgun ../release/opnfv/nailgun

.nailgun: .fuel-createmirror
	rm -Rf nailgun
	fakeroot /opt/fuel-createmirror-6.1/fuel-createmirror
	# Bug fix for https://bugs.launchpad.net/fuel/+bug/1476593
	find nailgun/mos-ubuntu -type d -exec chmod 755 {} \;
	touch .nailgun
