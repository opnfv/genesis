##############################################################################
# Copyright (c) 2015 Ericsson AB and others.
# stefan.k.berg@ericsson.com
# jonas.bjurel@ericsson.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Deploy!

scp -q $deafile root@10.20.0.2:. || error_exit "Could not copy DEA file to Fuel"
echo "Uploading build tools to Fuel server"
ssh root@10.20.0.2 rm -rf tools || error_exit "Error cleaning old tools structure"
scp -qrp $topdir/tools root@10.20.0.2:. || error_exit "Error copying tools"

# Refuse to run if environment already present
envcnt=`fuel env | tail -n +3 | grep -v '^$' | wc -l`
if [ $envcnt -ne 0 ]; then
  error_exit "Environment count is $envcnt"
fi

# Refuse to run if any nodes are up
nodeCnt=`noNodesUp`
if [ $nodeCnt -ne 0 ]; then
  error_exit "Nodes are up (node count: $nodeCnt)"
fi

# Extract release ID for Ubuntu environment
ubuntucnt=`fuel release | grep Ubuntu | wc -l`
if [ $ubuntucnt -ne 1 ]; then
  error_exit "Not exacly one Ubuntu release found"
fi

ubuntuid=`fuel release | grep Ubuntu | awk '{ print $1 }'`

# Create environment
fuel env create --name Foobar --rel $ubuntuid --mode ha --network-mode neutron  --net-segment-type vlan || error_exit "Error creating environment"
envId=`ssh root@10.20.0.2 fuel env | tail -n +3 | awk '{ print $1 }'` || error_exit "Could not get environment id"


echo "Running transplant #1"
ssh root@10.20.0.2 "cd tools; ./transplant1.sh ../`basename $deafile`" || error_exit "Error running transplant sequence #1"

# Spin up VMs
for node in controller1 controller2 controller3 compute4 compute5
do
  echo "Starting VM $node"
  virsh start $node >/dev/null 2>&1 || error_exit "Could not virsh start $node"
  sleep 10
done

for node in controller1 controller2 controller3
do
  echo -n "Waiting for Fuel to detect $node"
  waitForHost $node
  echo "Setting role for $node"
  fuel node set --node-id `getNodeId $node` --role controller,mongo --env $envId || error_exit "Could not set role for $node"
done

for node in compute4 compute5
do
  echo -n "Waiting for Fuel to detect $node"
  waitForHost $node
  echo "Setting role for $node"
  fuel node set --node-id `getNodeId $node` --role compute --env $envId || error_exit "Could not set role for $node"
done

# Inject node network config
echo "Running transplant #2"
ssh root@10.20.0.2 "cd tools; ./transplant2.sh ../`basename $deafile`" || error_exit "Error running transplant sequence #2"

# Run pre-deploy with default input
# Need to set terminal as script does "clear"
ssh root@10.20.0.2 "TERM=vt100 /opt/opnfv/pre-deploy.sh < /dev/null" || error_exit "Pre-deploy failed"

# Deploy
echo "Deploying!"
ssh root@10.20.0.2 "fuel deploy-changes --env $envId" >/dev/null 2>&1 || error_exit "Deploy failed"
echo "Deployment completed"
