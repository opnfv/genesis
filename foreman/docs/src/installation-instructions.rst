:Authors: Tim Rozet (trozet@redhat.com)
:Version: 0.0.1

==============================================================
OPNFV Installation instructions for - Foreman/QuickStack@OPNFV
==============================================================

Abstract
========

This document describes how to install Foreman/QuickStack@OPNFV, it's dependencies and required system resources.

License
=======
All Foreman/QuickStack and "common" entities are protected by the Apache 2.0 License ( http://www.apache.org/licenses/ )

**Contents**

1   Version history

2   Introduction

3   Preface

4   Setup Requirements

5   Installation High-Level Overview - Baremetal Deployment

6   Installation High-Level Overview - VM Deployment

7   Installation Guide - Baremetal Deployment

8   Installation Guide - VM Deployment

9   Frequently Asked Questions

10  References

1   Version history
===================

+--------------------+--------------------+--------------------+--------------------+
| **Date**           | **Ver.**           | **Author**         | **Comment**        |
|                    |                    |                    |                    |
+--------------------+--------------------+--------------------+--------------------+
| 2015-05-07         | 0.0.1              | Tim Rozet          | First draft        |
|                    |                    |                    |                    |
+--------------------+--------------------+--------------------+--------------------+

2   Introduction
================

This document describes the steps to install an OPNFV R1 (Arno) reference platform, as defined by the Bootstrap/Getting-Started (BGS) Project using the Foreman/QuickStack installer.

The audience of this document is assumed to have good knowledge in network and Unix/Linux administration.

3   Preface
===========

Foreman/QuickStack uses the Foreman opensource project as a server managment tool, which in turn manages and executes Genesis/QuickStack.  Genesis/QuickStack consists of layers of puppet modules which are capable of provisioning out the OPNFV Target System (3 Controllers, n number of Compute nodes).

The Genesis repo contains the necessary tools to get install and deploy an OPNFV Target system using Foreman/QuickStack.  These tools consist of the Foreman/QuickStack bootable ISO, and the automatic deployment script (deploy.sh).

An OPNFV install requires a "jumphost" in order to operate.  The bootable ISO will allow you to install a customized CentOS 7 release to the jumphost, which then gives you the required packages needed to run deploy.sh.  If you already have a jumphost with CentOS 7 installed, you may choose to ignore the ISO step and instead move directly to running deploy.sh.  In this case, deploy.sh will install the necessary packages for you in order to execute.

deploy.sh installs Foreman/QuickStack VM server using Vagrant with VirtualBox as it's provider.  This VM is then used to provision out the OPNFV Target System (3 Controllers, n Compute nodes).  These nodes can be either virtual or baremetal, and this guide contains instructions on how to install both.


4   Setup Requirements
========================

4.1 Jumphost Requirements
-------------------------

The jumphost requirements are outlined below:

1.     CentOS 7 (from ISO or self-installed)

2.     Root access/permissions

3.     libvirt or other hypervisors disabled (no kernel modules loaded)

4.     3-4 NICs, untagged (no 802.1Q tagging), with IP addresses

5.     Internet access for downloading packages (with a default gateway configured)

6.     4 GB of RAM (Baremetal Deployment) or 24 GB of RAM (VM Deployment)

4.2 Network Requirements
------------------------

Network requirements include:

1.     No DHCP, or TFTP server running on networks used by OPNFV

2.     3-4 separate VLANS (untagged) with connectivity between Jumphost and nodes (Baremetal Deployment Only).  These make up the Admin, Private, Public and optional Storage Networks.

3.     Lights out OOB network access from Jumphost with IPMI node enablement (Baremetal Deployment Only)

4.     Admin or Public network has Internet access, meaning a gateway and DNS availability.

*Note: Storage network will be consolidated to the Private network if only 3 networks are used

4.3  Baremetal Node Requirements
--------------------------------

Baremetal Nodes require:

1.     IPMI enabled on OOB interface for power control

2.     BIOS Boot Priority should be PXE first then local hard disk

3.     BIOS PXE interface should include Admin network mentioned above.

4.4  Execution Requirements (Baremtal Deployment Only)
------------------------------------------------------

In order to execute deployment, one must need to gather the following information:

1.     IPMI IP Addresses for the nodes

2.     IPMI Login information for the nodes (user/pass)

3.     MAC Address of Admin interfaces on nodes

4.     MAC Address of Private interfaces on 3 nodes that will be controllers


5   Installation High-Level Overview - Baremetal Deployment
===========================================================

The setup presumes that you have 6 baremetal servers and have already setup connectivity on at least 3 interfaces for all servers via a TOR switch or other network implementation.

The physical TOR switches are **not** automatically configured from the OPNFV reference platform. All the networks involved in the OPNFV infra-structure as well as the provider networks and the private tenant VLANs needs to be manually configured.

The Jumphost can be installed using the bootable ISO.  The Jumphost should then be configured with an IP gateway on it's Admin or Public interface and configured with a working DNS server.  The Jumphost should also have routable access to the Lights Out network.

Deploy.sh is then executed in order to install the Foreman/QuickStack Vagrant VM.  Deploy.sh uses a configuration file with YAML format in order to know how to install and provision the OPNFV Target System.  The information gathered under section "4.4 Execution Requirements" is put into this configuration file.

Deploy.sh brings up a CentOS 7 Vagrant VM, provided by VirtualBox.  The VM then executes an Ansible project called Khaleesi in order to install Foreman and QuickStack.  Once the Foreman/QuickStack VM is up, Foreman will be configured with the nodes' information.  This includes MAC address, IPMI, OpenStack Type (Controller, Compute, OpenDaylight Controller) and other information.  At this point Khaleesi makes a REST API call to Foreman to instruct it to provision the hardware.

Foreman will then reboot the nodes via IPMI.  The nodes should already be set to PXE boot first off the Admin interface.  Foreman will then allow the nodes to PXE and install CentOS 7 as well as Puppet.  Foreman/QuickStack VM server runs a Puppet Master and the nodes query this master to get their appropriate OPNFV configuration.  The nodes will then reboot one more time and once back up, will DHCP on their Private, Public and Storage NICs to gain IP addresses.  The nodes will now check in via puppet and start installing OPNFV.

Khaleesi will wait until these nodes are fully provisioned and then return a success or failure based on the outcome of the puppet application.


6   Installation High-Level Overview - VM Deployment
====================================================

The VM nodes deployment operates almost the same way as the Baremetal Deployment with a few differences.  deploy.sh still installs Foreman/QuickStack VM the exact same way, however the part of the Khaleesi Ansible playbook which IPMI reboots/PXE boots the servers is ignored.  Instead, deploy.sh brings up N number more Vagrant VMs (where N is 3 Control Nodes + n compute).  These VMs already come up with CentOS7 so instead of re-provisioning the entire VM, deploy.sh initiates a small bash script which will signal to Foreman that those nodes are built and install/configure Puppet on them.

To Foreman these nodes look like they have just built and register the same way as baremetal nodes.


7   Installation Guide - Baremetal Deployment
=============================================

This section goes step-by-step on how to correctly install and provision the OPNFV target system to baremetal nodes.

7.1  Install Baremetal Jumphost
-------------------------------
1.  If your Jumphost does not have CentOS 7 already on it, or you would like to do a fresh install, then download the Foreman/QuickStack bootable ISO here <ISO LINK>

2.  Boot the ISO off of a USB or other installation media and walk through installing OPNFV CentOS 7

3.  After OS is installed login to your Jumphost as root

4.  Configure IP addresses on 3-4 interfaces that you have selected as your Admin, Private, Public, and Storage (optional) networks

5.  Configure the IP gateway to the internet either, preferably on the Public interface

6.  Configure your /etc/resolv.conf to point to a DNS server (8.8.8.8 is provided by Google)

7.  Disable selinux:

    - setenforce 0
    - sed -i 's/SELINUX=.*/SELINUX=permissive/' /etc/selinux/config

8.  Disable firewalld:

    - systemctl stop firewalld
    - systemctl disable firewalld

7.2  Creating an Inventory File
-------------------------------

You now need to take the MAC address/IPMI info gathered in section "4.4 Execution Requirements" and create the YAML Inventory (also known as Configuration) file for deploy.sh

1.  Copy the opnfv_ksgen_settings.yml file from /root/bgs_vagrant/ to another directory and rename it to be what you want EX: </root/my_ksgen_settings.yml>

2.  Edit the file in your favorite editor.  There is a lot of information in this file, but you really only need to be concerned with the "nodes:" dictionary.

3.  The nodes dictionary contains each baremetal host you want to deploy.  You can have 1 or more Compute nodes and must have 3 Controller nodes (these are already defined for you).  It is optional at this piont to add more Compute nodes into the dictionary.  You must use a different name, hostname, short_name and dictionary keyname for each node.

4.  Once you have decided on your node definitions you now need to modify the MAC address/IPMI info dependant to your hardware.  Edit the following values for each node:

    - mac_address: change to mac_address of that node's Admin NIC (Default 1st NIC)
    - bmc_ip: change to IP Address of BMC (out-of-band)/IPMI IP
    - bmc_mac: same as above, but MAC address
    - bmc_user: IPMI username
    - bmc_pass: IPMI password

5.  Also edit the following for only Controller nodes:

    - private_mac - change to mac_address of node's Private NIC (Default 2nd NIC)

6.  Save your changes.

7.3  Running deploy.sh
----------------------

You are now ready to deploy OPNFV!  deploy.sh will use your /tmp/ directory to store it's Vagrant VMs.  Your Foreman/QuickStack Vagrant VM will be running out of /tmp/bgs_vagrant.  

It is also recommended that you power off your nodes before running deploy.sh  If there are dhcp servers or other network services that are on those nodes it may conflict with the installation.  

Follow the steps below to execute:

1.  cd /root/bgs_vagrant

2.  ./deploy.sh -base_config </root/my_ksgen_settings.yml>

3.  It will take about 20-25 minutes to install Foreman/QuickStack VM.  If something goes wrong during this part of the process, it is most likely a problem with the setup of your Jumphost.  You will also notice different outputs in your shell.  When you see messages that say "TASK:" or "PLAY:" this is Khalessi running and installing Foreman/QuickStack inside of your VM or deploying your nodes.  Look for "PLAY [Deploy Nodes]" as a sign that Foreman/QuickStack is finished installing and now your nodes ar being rebuilt.

4.  Your nodes will take 40-60 minutes to re-install CentOS 7 and install/configure OPNFV.  When complete you will see "Finished: SUCCESS"

7.4  Verifying the setup
------------------------

Now that the installer has finished it is a good idea to check and make sure things are working correctly.  To access your Foreman/QuickStack VM:

1.  cd /tmp/bgs_vagrant

2.  'vagrant ssh' password is "vagrant"

3.  You are now in the VM and can check the status of foreman service, etc.  For example: 'systemctl status foreman'

4.  type "exit" and leave the Vagrant VM.  Now execute: 'cat /tmp/bgs_vagrant/opnfv_ksgen_settings.yml | grep foreman_url'

5.  This is your Foreman URL on your public interface.  You can go to your web browser, http://<foreman_ip>, login will be "admin"//"octopus".  This way you can look around in Foreman and check that your hosts are in a good state, etc.  

6.  In Foreman GUI, you can now go to Infrastructure -> Global Parameters.  This is a list of all the variables being handed to Puppet for configuring OPNFV.  Look for "horizon_public_vip".  This is your IP address to Horizon GUI.
**Note: You can find out more about how to ues Foreman by going to http://www.theforeman.org/ or by watching a walkthrough video here: https://bluejeans.com/s/89gb/

7.  Now go to your web browser and insert the Horizon Public VIP.  The login will be "admin//octopus"

8.  You are now able to follow the next section "7.5 OpenStack Verification"

7.5  OpenStack Verification
---------------------------

Now that you have Horizon access, let's make sure OpenStack the OPNFV Target System are working correctly:

1.  In Horizon, click Project -> Compute -> Volumes, Create Volume

2.  Make a volume "test_volume" and 1 GB

3.  Now in the left pane, click Compute -> Images, click Create Image

4.  Insert a name "cirros", Insert an Image Location "http://download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img"

5.  Select Format "QCOW2", select Public, then hit Create Image

6.  Now click Project -> Network -> Networks, click Create Network

7.  Enter a name "test_network", click Next

8.  Enter a subnet name "test_subnet", and enter Network Address 10.0.0.0/24, click Next

9.  Enter 10.0.0.5,10.0.0.9 under Allocation Pools, then hit Create

10. Now go to Project -> Compute -> Instances, click Launch Instance

11. Enter Instance Name "cirros1", select Instance Boot Source "Boot from image", and then select Image Name "cirros"

12. Click Launch, status should show "Spawning" while it is being built

13. You can now repeat setps 11 and 12, but create a "cirros2" named instance

14. Once both instances are up you can see their IP Addresses on the Instances page.  Click the Instance Name of cirros1.

15. Now click the "Console" tab and login as cirros//cubswin:)

16. Verify you can ping the IP address of cirros2

Congratulations you have successfully installed OPNFV!

8   Installation Guide - VM Deployment
=====================================

This section goes step-by-step on how to correctly install and provision the OPNFV target system to VM nodes.

8.1 Install Jumphost
--------------------
Follow section "7.1 Install Baremetal Jumphost"

8.2  Running deploy.sh
----------------------
You are now ready to deploy OPNFV!  deploy.sh will use your /tmp/ directory to store it's Vagrant VMs.  Your Foreman/QuickStack Vagrant VM will be running out of /tmp/bgs_vagrant.  Your compute and subsequent controller nodes will be running in:
- /tmp/compute
- /tmp/controller1
- /tmp/controller2
- /tmp/controller3

Each VM will be brought up and bridged to your Jumphost NICs.  deploy.sh will first bring up your Foreman/QuickStack Vagrant VM and afterwards it will bring up each of the nodes listed above, in order.

Follow the steps below to execute:

1.  cd /root/bgs_vagrant

2.  ./deploy.sh -virtual

3.  It will take about 20-25 minutes to install Foreman/QuickStack VM.  If something goes wrong during this part of the process, it is most likely a problem with the setup of your Jumphost.  You will also notice different outputs in your shell.  When you see messages that say "TASK:" or "PLAY:" this is Khalessi running and installing Foreman/QuickStack inside of your VM or deploying your nodes.  When you see "Foreman is up!", that means deploy will now move on to bringing up your other nodes.

4.  deploy.sh will now bring up your other nodes, look for logging messages like "Starting Vagrant Node <node name>", "<node name> VM is up!"  These are indicators of how far along in the process you are.  deploy will start each Vagrant VM, then run provisioning scripts to inform Foreman they are built and initiate Puppet.

5.  The speed at which nodes are provisioned is totally dependant on your Jumphost server specs.  When complete you will see "All VMs are UP!"

8.3 Verifying the setup
-----------------------
Please follow the instructions under section "7.4  Verifying the setup".

Also, for VM deployment you are able to easily access your nodes by going to /tmp/<node name> and then "vagrant ssh" (password is "vagrant").  You can use this to go to a controller and check OpenStack services, OpenDaylight, etc.

8.4 OpenStack Verification
--------------------------

Please follow the steps in section "7.5  OpenStack Verification"

9   Frequently Asked Questions
==============================

10  References
=============

10.1    OPNFV
-------------

10.2    OpenStack
-----------------

10.3    OpenDaylight
--------------------

10.4    Foreman
--------------
