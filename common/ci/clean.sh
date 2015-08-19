#!/usr/bin/env bash

#Common clean script to uninstall provisioning server
#author: Tim Rozet (trozet@redhat.com)
#
#Removes Libvirt, KVM, Vagrant, VirtualBox
#
#Destroys Vagrant VMs running in $vm_dir/
#Shuts down all nodes found in Khaleesi settings
#Removes hypervisor kernel modules (VirtualBox & KVM/Libvirt)

##VARS
reset=`tput sgr0`
blue=`tput setaf 4`
red=`tput setaf 1`
green=`tput setaf 2`

vm_dir=/var/opt/opnfv
##END VARS

##FUNCTIONS
display_usage() {
  echo -e "\n\n${blue}This script is used to uninstall and clean the OPNFV Target System${reset}\n\n"
  echo -e "\nUsage:\n$0 [arguments] \n"
  echo -e "\n   -no_parse : No variable parsing into config. Flag. \n"
  echo -e "\n   -base_config : Full path of ksgen settings file to parse. Required.  Will provide BMC info to shutdown hosts.  Example:  -base_config /opt/myinventory.yml \n"
}

##END FUNCTIONS

if [[ ( $1 == "--help") ||  $1 == "-h" ]]; then
    display_usage
    exit 0
fi

echo -e "\n\n${blue}This script is used to uninstall and clean the OPNFV Target System${reset}\n\n"
echo "Use -h to display help"
sleep 2

while [ "`echo $1 | cut -c1`" = "-" ]
do
    echo $1
    case "$1" in
        -base_config)
                base_config=$2
                shift 2
            ;;
        *)
                display_usage
                exit 1
            ;;
esac
done

if [ ! -z "$base_config" ]; then
  # Install ipmitool
  # Major version is pinned to force some consistency for Arno
  if ! yum list installed | grep -i ipmitool; then
    if ! yum -y install ipmitool-1*; then
      echo "${red}Unable to install ipmitool!${reset}"
      exit 1
    fi
  else
    echo "${blue}Skipping ipmitool as it is already installed!${reset}"
  fi

  ###find all the bmc IPs and number of nodes
  node_counter=0
  output=`grep bmc_ip $base_config | grep -Eo '[0-9]+.[0-9]+.[0-9]+.[0-9]+'`
  for line in ${output} ; do
    bmc_ip[$node_counter]=$line
    ((node_counter++))
  done

  max_nodes=$((node_counter-1))

  ###find bmc_users per node
  node_counter=0
  output=`grep bmc_user $base_config | sed 's/\s*bmc_user:\s*//'`
  for line in ${output} ; do
    bmc_user[$node_counter]=$line
    ((node_counter++))
  done

  ###find bmc_pass per node
  node_counter=0
  output=`grep bmc_pass $base_config | sed 's/\s*bmc_pass:\s*//'`
  for line in ${output} ; do
    bmc_pass[$node_counter]=$line
    ((node_counter++))
  done
  for mynode in `seq 0 $max_nodes`; do
    echo "${blue}Node: ${bmc_ip[$mynode]} ${bmc_user[$mynode]} ${bmc_pass[$mynode]} ${reset}"
    if ipmitool -I lanplus -P ${bmc_pass[$mynode]} -U ${bmc_user[$mynode]} -H ${bmc_ip[$mynode]} chassis power off; then
      echo "${blue}Node: $mynode, ${bmc_ip[$mynode]} powered off!${reset}"
    else
      echo "${red}Error: Unable to power off $mynode, ${bmc_ip[$mynode]} ${reset}"
      exit 1
    fi
  done
else
  echo "${blue}Skipping Baremetal node poweroff as base_config was not provided${reset}"
fi
###check to see if vbox is installed
vboxpkg=`rpm -qa | grep VirtualBox`
if [ $? -eq 0 ]; then
  skip_vagrant=0
else
  skip_vagrant=1
fi

###legacy VM location check
###remove me later
if [ -d /tmp/bgs_vagrant ]; then
  cd /tmp/bgs_vagrant
  vagrant destroy -f
  rm -rf /tmp/bgs_vagrant
fi

###destroy vagrant
if [ $skip_vagrant -eq 0 ]; then
  if [ -d $vm_dir ]; then
    ##all vm directories
    for vm in $( ls $vm_dir ); do
      cd $vm_dir/$vm
      if vagrant destroy -f; then
        echo "${blue}Successfully destroyed $vm Vagrant VM ${reset}"
      else
        echo "${red}Unable to destroy $vm Vagrant VM! Attempting to killall vagrant if process is hung ${reset}"
        killall vagrant
        echo "${blue}Checking if vagrant was already destroyed and no process is active...${reset}"
        if ps axf | grep vagrant; then
          echo "${red}Vagrant process still exists after kill...exiting ${reset}"
          exit 1
        else
          echo "${blue}Vagrant process doesn't exist.  Moving on... ${reset}"
        fi
      fi

      ##Vagrant boxes appear as VboxHeadless processes
      ##try to gracefully destroy the VBox VM if it still exists
      if vboxmanage list runningvms | grep $vm; then
        echo "${red} $vm VBoxHeadless process still exists...Removing${reset}"
        vbox_id=$(vboxmanage list runningvms | grep $vm | awk '{print $1}' | sed 's/"//g')
        vboxmanage controlvm $vbox_id poweroff
        if vboxmanage unregistervm --delete $vbox_id; then
          echo "${blue}$vm VM is successfully deleted! ${reset}"
        else
          echo "${red} Unable to delete VM $vm ...Exiting ${reset}"
          exit 1
        fi
      else
        echo "${blue}$vm VM is successfully deleted! ${reset}"
      fi
    done
  else
    echo "${blue}${vm_dir} doesn't exist, no VMs in OPNFV directory to destroy! ${reset}"
  fi

  echo "${blue}Checking for any remaining virtual box processes...${reset}"
  ###kill virtualbox
  if ps axf | grep virtualbox; then
    echo "${blue}virtualbox processes are still running. Killing any remaining VirtualBox processes...${reset}"
    killall virtualbox
  fi

  ###kill any leftover VMs (brute force)
  if ps axf | grep VBoxHeadless; then
    echo "${blue}VBoxHeadless processes are still running. Killing any remaining VBoxHeadless processes...${reset}"
    killall VBoxHeadless
  fi

  ###remove virtualbox
  echo "${blue}Removing VirtualBox... ${reset}"
  yum -y remove $vboxpkg

else
  echo "${blue}Skipping Vagrant destroy + VBox Removal as VirtualBox package is already removed ${reset}"
fi

###remove working vm directory
echo "${blue}Removing working VM directory: $vm_dir ${reset}"
rm -rf $vm_dir

###check to see if libvirt is installed
echo "${blue}Checking if libvirt/KVM is installed"
if rpm -qa | grep -iE 'libvirt|kvm'; then
  echo "${blue}Libvirt/KVM is installed${reset}"
  echo "${blue}Checking for any QEMU/KVM VMs...${reset}"
  vm_count=0
  while read -r line; do ((vm_count++)); done < <(virsh list --all | sed 1,2d | head -n -1)
  if [ $vm_count -gt 0 ]; then
    echo "${blue}VMs Found: $vm_count${reset}"
    vm_runnning=0
    while read -r line; do ((vm_running++)); done < <(virsh list --all | sed 1,2d | head -n -1| grep -i running)
    echo "${blue}Powering off $vm_running VM(s)${reset}"
    while read -r vm; do
      if ! virsh destroy $vm; then
        echo "${red}WARNING: Unable to power off VM ${vm}${reset}"
      else
        echo "${blue}VM $vm powered off!${reset}"
      fi
    done < <(virsh list --all | sed 1,2d | head -n -1| grep -i running | sed 's/^[ \t]*//' | awk '{print $2}')
    echo "${blue}Destroying libvirt VMs...${reset}"
    while read -r vm; do
      if ! virsh undefine --remove-all-storage $vm; then
        echo "${red}ERROR: Unable to remove the VM ${vm}${reset}"
        exit 1
      else
        echo "${blue}VM $vm removed!${reset}"
      fi
    done < <(virsh list --all | sed 1,2d | head -n -1| awk '{print $2}')
  else
    echo "${blue}No VMs found for removal"
  fi
  echo "${blue}Removing libvirt and kvm packages"
  yum -y remove libvirt-*
  yum -y remove *qemu*
else
  echo "${blue}libvirt/KVM is not installed${reset}"
fi

###remove kernel modules
echo "${blue}Removing kernel modules ${reset}"
for kernel_mod in vboxnetadp vboxnetflt vboxpci vboxdrv kvm_intel kvm; do
  if ! rmmod $kernel_mod; then
    if rmmod $kernel_mod 2>&1 | grep -i 'not currently loaded'; then
      echo "${blue} $kernel_mod is not currently loaded! ${reset}"
    else
      echo "${red}Error trying to remove Kernel Module: $kernel_mod ${reset}"
      exit 1
    fi
  else
    echo "${blue}Removed Kernel Module: $kernel_mod ${reset}"
  fi
done