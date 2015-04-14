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

netdir='../examples/networks'
vmdir='../examples/vms'

if [ -d $netdir ]; then
  echo "Net directory already present"
  exit 1
elif [ -d $vmdir ]; then
  echo "VM directory already present"
  exit 1
fi

mkdir -p $netdir
mkdir -p $vmdir

# Check that no VM is up
if virsh list | egrep -q "fuel-master|controller|compute" ; then
  echo "Can't dump while VMs are up:"
  virsh list | egrep "fuel-master|controller|compute"
  exit 1
fi

# Dump all networks in the fuell* namespace
for net in `virsh net-list --all | tail -n+3 | awk '{ print $1 }' | grep fuel`
do
  virsh net-dumpxml $net > $netdir/$net
done

# Dump all fuel-master, compute* and controller* VMs
for vm in `virsh list --all | tail -n+3 | awk '{ print $2 }' | egrep 'fuel-master|compute|controller'`
do
  virsh dumpxml $vm > $vmdir/$vm
done

# Remove all attached ISOs, generalize the rest of the setup
for vm in $vmdir/*
do
  sed -i '/.iso/d' $vm
  sed -i "s/<source file='.*raw'/<source file='disk.raw'/" $vm
  sed -i '/<uuid/d' $vm
  sed -i '/<mac/d' $vm
done

# Generalize all nets
for net in $netdir/*
do
  sed -i '/<uuid/d' $net
  sed -i '/<mac/d' $net
done
