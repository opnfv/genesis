##############################################################################
# Copyright (c) 2015 Ericsson AB and others.
# stefan.k.berg@ericsson.com
# jonas.bjurel@ericsson.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Common functions

error_exit () {
  echo "Error: $@" >&2
  exit 1
}

ssh() {
  SSHPASS="r00tme" sshpass -e ssh -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no -o ConnectTimeout=15 "$@"
}

scp() {
  SSHPASS="r00tme" sshpass -e scp  -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no -o ConnectTimeout=15 "$@"
}

noNodesUp () {
  fuel node | grep True | wc -l
}

fuel () {
  ssh root@10.20.0.2 "fuel $@"
}

# Return MAC id for virsh node
getNodeId() {
  virsh dumpxml $1 | grep "mac address"  | head -1 | sed "s/.*'..:..:..:..:\(.*\)'.*/\1/"
}

# Wait for node with virtid name to come up
waitForHost() {
  mac=`getNodeId $1`

  while true
  do
    fuel node --node-id $mac 2>/dev/null | grep -q True && break
    sleep 3
    echo -n "."
  done
  echo -e "\n"
}

# Currently not used!
# Wait for node count to increase
waitForNode() {
  local cnt
  local initCnt
  local expectCnt

  initCnt=`noNodesUp`
  expectCnt=$[initCnt+1]
  while true
  do
    cnt=`noNodesUp`
    if [ $cnt -eq $expectCnt ]; then
      break
    elif [ $cnt -lt $initCnt ]; then
      error_exit "Node count decreased while waiting, $initCnt -> $cnt"
    elif [ $cnt -gt $expectCnt ]; then
      error_exit "Node count exceeded expect count, $cnt > $expectCnt"
    fi
    sleep 3
    echo -n "."
  done
  echo -e "\n"
}

bootorder_dvdhd() {
  virsh dumpxml $1 | grep -v "<boot.*>" | \
  sed "/<\/os>/i\
    <boot dev='cdrom'/\>\n\
    <boot dev='hd'/\>\n\
    <bootmenu enable='no'/\>" > $tmpdir/vm.xml || error_exit "Could not set bootorder"
  virsh define $tmpdir/vm.xml || error_exit "Could not set bootorder"
}

bootorder_hddvd() {
  virsh dumpxml $1 | grep -v "<boot.*>" | \
  sed "/<\/os>/i\
    <boot dev='hd'/\>\n\
    <boot dev='cdrom'/\>\n\
    <bootmenu enable='no'/\>" > $tmpdir/vm.xml || error_exit "Could not set bootorder"
  virsh define $tmpdir/vm.xml || error_exit "Could not set bootorder"
}

addisofile() {
  virsh dumpxml $1 | grep -v '\.iso' | sed "s/<.*device='cdrom'.*/<disk type='file' device='cdrom'>/" | \
    sed "/<.*device='cdrom'.*/a       <source file='$2'/>" > $tmpdir/vm.xml \
      || error_exit "Could not add isofile"
  virsh define $tmpdir/vm.xml || error_exit "Could not add isofile"
}

removeisofile() {
  virsh dumpxml $1 | grep -v '\.iso' | sed "s/<.*device='cdrom'.*/<disk type='block' device='cdrom'>/" \
     > $tmpdir/vm.xml \
      || error_exit "Could not remove isofile"
  virsh define $tmpdir/vm.xml || error_exit "Could not remove isofile"
}
