
======== PREREQUISITES ========

the following applications and python modules are required to be installed:

- example for Ubuntu environment:

sudo apt-get install -y libvirt-bin qemu-kvm tightvncserver virt-manager
sshpass fuseiso genisoimage blackbox xterm python-pip
sudo restart libvirt-bin
sudo pip install pyyaml netaddr paramiko lxml scp



======== PREPARE and RUN the OPNFV Autodeployment ========


--- Step.1 Prepare the DEA and DHA configuration files and the OPNFV ISO file

Make sure that you are using the right DEA - Deployment Environment Adapter and
DHA - Deployment Hardware Adapter configuration files, the ones provided are only templates
you will have to modify them according to your needs

- If wou wish to deploy OPNFV cloud environment on top of KVM/Libvirt
  virtualization use as example the following configuration files:

  =>   libvirt/conf/ha
                dea.yaml
                dha.yaml

  =>   libvirt/conf/multinode
                dea.yaml
                dha.yaml


- If you wish to deploy OPNFV cloud environment on baremetal
  use as example the following configuration files:

  =>   baremetal/conf/ericsson_montreal_lab/ha
                dea.yaml
                dha.yaml

  =>   baremetal/conf/ericsson_montreal_lab/multinode
                dea.yaml
                dha.yaml

  =>   baremetal/conf/linux_foundation_lab/ha
                dea.yaml
                dha.yaml

  =>   baremetal/conf/linux_foundation_lab/multinode
                dea.yaml
                dha.yaml


--- Step.2 Run Autodeployment:

usage: python deploy.py [-h] [-nf]
                        [iso_file] dea_file dha_file [storage_dir]
                        [pxe_bridge]

positional arguments:
  iso_file     ISO File [default: OPNFV.iso]
  dea_file     Deployment Environment Adapter: dea.yaml
  dha_file     Deployment Hardware Adapter: dha.yaml
  storage_dir  Storage Directory [default: images]
  pxe_bridge   Linux Bridge for booting up the Fuel Master VM [default: pxebr]

optional arguments:
  -h, --help   show this help message and exit
  -nf          Do not install Fuel Master (and Node VMs when using libvirt)


* WARNING:

If <storage_dir> is not specified, Autodeployment will use
"<current_working_dir>/images" as default, and it will create it,
if it hasn't been created before

If <pxe_bridge> is not specified, Autodeployment will use "pxebr" as default,
if the bridge does not exist, the application will terminate with an error message

IF <storage_dir> is not specified, Autodeployment will use "<current_working_dir>/OPNFV.iso"
as default, if the iso file does not exist, the application will terminate with an error message

<pxe_bridge> is not required for Autodeployment in virtual environment, even if it is specified
it will not be used at all


* EXAMPLES:

- Install Fuel Master and deploy OPNFV Cloud from scratch on Baremetal Environment

sudo python deploy.py ~/ISO/opnfv.iso ~/CONF/baremetal/dea.yaml ~/CONF/baremetal/dha.yaml /mnt/images pxebr


- Install Fuel Master and deploy OPNFV Cloud from scratch on Virtual Environment

sudo python deploy.py ~/ISO/opnfv.iso ~/CONF/virtual/dea.yaml ~/CONF/virtual/dha.yaml /mnt/images



- Deploy OPNFV Cloud on an already active Environment where Fuel Master VM is running
  so no need to install Fuel again

sudo python deploy.py -nf ~/CONF/baremetal/dea.yaml ~/CONF/baremetal/dha.yaml

sudo python deploy.py -nf ~/CONF/virtual/dea.yaml ~/CONF/virtual/dha.yaml

