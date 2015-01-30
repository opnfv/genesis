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
PACKAGE := foobar
VERSION := 1.0-1

.PHONY: all
all:	release/pool/main/$(PACKAGE)_$(VERSION).deb

release/pool/main/$(PACKAGE)_$(VERSION).deb:
	@mkdir -p tmp/src
	@mkdir -p release/pool/main
	@cp -r $(PACKAGE)_$(VERSION) tmp/src
	@gzip -9 tmp/src/$(PACKAGE)_$(VERSION)/usr/share/doc/$(PACKAGE)/changelog.Debian
	@fakeroot dpkg-deb --build tmp/src/$(PACKAGE)_$(VERSION)
	@lintian tmp/src/$(PACKAGE)_$(VERSION).deb
	@cp tmp/src/$(PACKAGE)_$(VERSION).deb release/pool/main

.PHONY: clean
clean:
	@rm -rf tmp
	@rm -rf release
	@rm -f ../release/packages/ubuntu/pool/main/$(PACKAGE)_$(VERSION).deb


.PHONY: release
release:release/pool/main/$(PACKAGE)_$(VERSION).deb
	@cp release/pool/main/$(PACKAGE)_$(VERSION).deb ../release/packages/ubuntu/pool/main
	@cp -Rvp puppet/modules/* ../release/puppet/modules
