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

error_exit () {
  echo "$@"
  exit 1
}

netdir='../libvirt/networks'
vmdir='../libvirt/vms'
tmpfile=/tmp/foo

if [ ! -d $netdir ]; then
  error_exit "No net directory $netdir"
  exit 1
elif [ ! -d $vmdir ]; then
  error_exit "No VM directory $vmdir"
  exit 1
fi

if [ $# -ne 2 ]; then
  echo "Argument error."
  echo "`basename $0` <path to storage dir> <size in GB of disk per VM>"
  exit 1
fi

storagedir=$1
size=$2

if [ ! -d $storagedir ]; then
  error_exit "Could not find storagedir directory $storagedir"
fi

# Create storage space and patch it in
for vm in $vmdir/*
do
  storage=${storagedir}/`basename ${vm}`.raw
  if [ -f ${storage} ]; then
     error_exit "Storage already present: ${storage}"
  fi
  echo "Creating ${size} GB of storage in ${storage}"
  fallocate -l ${size}G ${storage} || \
    error_exit "Could not create storage"
  sed "s:<source file='disk.raw':<source file='${storage}':" $vm >$tmpfile
  virsh define $tmpfile
done

for net in $netdir/*
do
  virsh net-define $net
  virsh net-autostart `basename $net`
  virsh net-start `basename $net`
done
