#!/bin/bash
##############################################################################
# Copyright (c) 2015 Ericsson AB and others.
# stefan.k.berg@ericsson.com
# jonas.bjurel@ericsson.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

BASE_PACKAGES="make python-setuptools python-all dpkg-dev debhelper
fuseiso git genisoimage bind9-host wget curl lintian tmux lxc iptables
ca-certificates"

apt-get update || exit 1
apt-get upgrade -y || exit 1

apt-get install -y $BASE_PACKAGES || exit 1

echo "ALL ALL=NOPASSWD: ALL" > /etc/sudoers.d/open-sudo
chmod 0440 /etc/sudoers.d/open-sudo
