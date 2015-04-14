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

cleanup () {
  if [ -n "$tmpDir" ]; then
    rm -Rf $tmpDir
  fi
}

trap cleanup exit

error_exit () {
  echo "Error: $@" >&2
  exit 1
}

tmpDir=`mktemp -d /tmp/deaXXXX`

export PATH=`dirname $0`:$PATH

if [ $# -ne 1 ]; then
  error_exit "Argument error"
fi
deaFile=$1

if [ ! -f "$deaFile" ]; then
  error_exit "Can't find $deaFile"
fi


if [ `fuel env | tail -n +3 | grep -v '^$' | wc -l` -ne 1 ]; then
  error_exit "Not exactly one environment"
fi
envId=`fuel env | tail -n +3 | grep -v '^$' | awk '{ print $1 }'`

# Phase 1: Graft deployment information
if [ "a" == "b" ]; then
fuel deployment --env $envId --default --dir $tmpDir || \
  error_exit "Could not dump environment"

for controller in `find $tmpDir -type f | grep -v compute`
do
  transplant_network_scheme.py $controller $deaFile controller || \
    error_exit "Failed to graft `basename $controller`"
done

for compute in `find $tmpDir -type f | grep compute`
do
  transplant_network_scheme.py $compute $deaFile compute || \
    error_exit "Failed to graft `basename $compute`"
done

fuel deployment --env $envId --upload --dir $tmpDir || \
  error_exit "Could not upload environment"
fi
# Phase 2: Graft interface information

for nodeId in `fuel node | grep True | awk '{ print $1}'`
do
  echo "Node $nodeId"
  fuel node --node-id $nodeId --network --download --dir $tmpDir || \
     error_exit "Could not download node $nodeId"

  transplant_interfaces.py ${tmpDir}/node_${nodeId}/interfaces.yaml $deaFile || \
     error_exit "Failed to graft interfaces"

  fuel node --node-id $nodeId --network --upload --dir $tmpDir || \
     error_exit "Could not upload node $nodeId"
done



