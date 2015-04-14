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

# Setup locations
topdir=$(cd `dirname $0`; pwd)
exampledir=$(cd $topdir/../examples; pwd)
functions=${topdir}/functions
tmpdir=$HOME/fueltmp
deployiso=${tmpdir}/deploy.iso

# Define common functions
. ${functions}/common.sh

exit_handler() {
  # Remove safety catch
  kill $killpid
}

####### MAIN ########

if [ "`whoami`" != "root" ]; then
  error_exit "You need be root to run this script"
fi

if [ $# -eq 0 -o $# -gt 2 ]; then
  error_exit "Argument error"
fi

# Setup tmpdir
if [ -d $tmpdir ]; then
  rm -Rf $tmpdir || error_exit "Coul not remove tmpdir $tmpdir"
fi

mkdir $tmpdir || error_exit "Could not create tmpdir $tmpdir"  

if [ ! -f $1 ]; then
  error_exit "Could not find ISO file $1"
else
  isofile=$(cd `dirname $1`; echo `pwd`/`basename $1`)
fi

# If no DEA specified, use the example one
if [ $# -eq 1 ]; then
  deafile=${exampledir}/libvirt_dea.yaml
else
  deafile=$(cd `dirname $2`; echo `pwd`/`basename $2`)
fi

if [ ! -f $deafile ]; then
  error-exit "Could not find DEA file $deafile"
fi


# Enable safety catch at three hours
(sleep 3h; kill $$) &
killpid=$!

# Enable exit handler
trap exit_handler exit


# Stop all VMs
for node in controller1 controller2 controller3 compute4 compute5 fuel-master
do
  virsh destroy $node >/dev/null 2>&1
done

# Install the Fuel master
# (Convert to functions at later stage)
echo "Patching iso file"
${functions}/patch-iso.sh $isofile $deployiso $tmpdir || error_exit "Failed to patch ISO"
# Swap isofiles from now on
isofile=$deployiso
. ${functions}/install_iso.sh
. ${functions}/deploy_env.sh

echo "Waiting for two minutes for deploy to stabilize"
sleep 2m

echo "Verifying node status after deployment"
set -o pipefail
# Any node with non-ready status?
ssh root@10.20.0.2 fuel node | tail -n +3 | cut -d "|" -f 2 | \
  sed 's/ //g' | grep -v ready | wc -l | grep -q "^0$"
if [ $? -ne 0 ]; then
  error_exit "Deployment failed verification"
else
  echo "Deployment verified"
fi

