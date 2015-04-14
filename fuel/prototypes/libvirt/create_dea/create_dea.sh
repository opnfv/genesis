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

if [ $# -lt 1 ]; then
  error_exit "Argument error"
fi
deafile=$1
shift

if [ $# -ne 0 ]; then
  comment="$@"
fi

if [ -f "$deafile" ]; then
  error_exit "$deafile already exists"
fi

if [ `fuel env | tail -n +3 | grep -v '^$' | wc -l` -ne 1 ]; then
  error_exit "Not exactly one environment"
fi
envId=`fuel env | tail -n +3 | grep -v '^$' | awk '{ print $1 }'`

computeId=`fuel node | grep compute | grep True | head -1 | awk '{ print $1}'`
controllerId=`fuel node | grep controller | grep True | head -1 | awk '{ print $1}'`

if [ -z "$computeId" ]; then
  error_exit "Could not find any compute node"
elif [ -z "$controllerId" ]; then
  error_exit "Could not find any controller node"
fi

fuel deployment --env $envId --download --dir $tmpDir > /dev/null || \
  error_exit "Could not get deployment info"
fuel settings --env $envId --download --dir $tmpDir > /dev/null || \
  error_exit "Could not get settings"
fuel network --env $envId --download --dir $tmpDir > /dev/null || \
  error_exit "Could not get network settings"

echo "version: 1.0" > $deafile
echo "created: `date`" >> $deafile
if [ -n "$comment" ]; then
  echo "comment: $comment" >> $deafile
fi

reap_network_scheme.py $tmpDir/deployment_${envId}/*controller_${controllerId}.yaml $deafile controller || \
  error_exit "Could not extract network scheme for controller"
reap_network_scheme.py $tmpDir/deployment_${envId}/compute_${computeId}.yaml $deafile compute || \
  error_exit "Could not extract network scheme for controller"
reap_network_settings.py $tmpDir/network_${envId}.yaml $deafile network || \
  error_exit "Could not extract network settings"
reap_settings.py $tmpDir/settings_${envId}.yaml $deafile settings || \
  error_exit "Could not extract settings"

fuel node --node-id $controllerId --network --download --dir $tmpDir || \
  error_exit "Could not get network info for node $controllerId"
reap_interfaces.py $tmpDir/node_${controllerId}/interfaces.yaml $deafile || \
  error_exit "Could not extract interfaces"


echo "DEA file is available at $deafile"

