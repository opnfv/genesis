##############################################################################
# Copyright (c) 2015 Ericsson AB and others.
# stefan.k.berg@ericsson.com
# jonas.bjurel@ericsson.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Recreate disk - needed for the reboot to work
fueldisk=`virsh dumpxml fuel-master | \
  grep fuel-master.raw | sed "s/.*'\(.*\)'.*/\1/"`
disksize=`ls -l $fueldisk | awk '{ print $5 }'`
rm -f $fueldisk
fallocate -l $disksize $fueldisk

bootorder_hddvd fuel-master
sleep 3
addisofile fuel-master $isofile
sleep 3
virsh start fuel-master

# wait for node up
echo "Waiting for Fuel master to accept SSH"
while true
do
  ssh root@10.20.0.2 date 2>/dev/null
  if [ $? -eq 0 ]; then
    break
  fi
  sleep 10
done

# Wait until fuelmenu is up
echo "Waiting for fuelmenu to come up"
menuPid=""
while [ -z "$menuPid" ]
do
  menuPid=`ssh root@10.20.0.2 "ps -ef" 2>&1 | grep fuelmenu | grep -v grep | awk '{ print $2 }'`
  sleep 10
done

# This is where we would inject our own astute.yaml

echo "Found menu as PID $menuPid, now killing it"
ssh root@10.20.0.2 "kill $menuPid" 2>/dev/null

# Wait until installation complete
echo "Waiting for bootstrap of Fuel node to complete"
while true
do
  ssh root@10.20.0.2 "ps -ef" 2>/dev/null \
    | grep -q /usr/local/sbin/bootstrap_admin_node
  if [ $? -ne 0 ]; then
    break
  fi
  sleep 10
done

echo "Waiting two minutes for Fuel to stabilize"
sleep 2m
