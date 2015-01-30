##############################################################################
# Copyright (c) 2015 Ericsson AB and others.
# stefan.k.berg@ericsson.com
# jonas.bjurel@ericsson.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

FROM opnfv.org/ubuntu:12.04
ADD install.sh /root/install.sh
RUN /root/install.sh

ADD ./enable_dockerx2 /root/enable_dockerx2
RUN chmod +x /root/enable_dockerx2
VOLUME /var/lib/docker
CMD ["/root/enable_dockerx2"]
