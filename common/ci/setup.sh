#!/usr/bin/env bash

#Script that install prerequisites
#author: Szilard Cserey (szilard.cserey@ericsson.com)
#
#Installs qemu-kvm, libvirt and prepares networking for Fuel VM

##VARS
reset=`tput sgr0`
blue=`tput setaf 4`
red=`tput setaf 1`
green=`tput setaf 2`
private_interface='enp6s0'
public_interface='enp8s0'
pxe_bridge='pxebr'
fuel_gw_ip='10.20.0.1/16'
##END VARS

##FUNCTIONS
###check whether qemu-kvm is installed, otherwise install it
install_qemu_kvm() {
  echo "${blue}Checking whether qemu-kvm is installed, otherwise install it${reset}"
  if ! rpm -qa | grep -iE 'qemu-kvm'; then
    echo "${blue}qemu-kvm is not installed, installing...${reset}"
    yum -y install qemu-kvm
  else
    echo "${green}OK!${reset}"
  fi
}

###check whether libvirt is installed, otherwise install it
install_libvirt() {
  echo "${blue}Checking whether libvirt is installed, otherwise install it${reset}"
  if ! rpm -qa | grep -iE 'libvirt'; then
    echo "${blue}libvirt is not installed, installing...${reset}"
    yum -y install libvirt
  else
    echo "${green}OK!${reset}"
  fi
}

###check whether kvm kernel module is loaded, otherwise load it
load_kvm_kernel_mod() {
  echo "${blue}Checking whether kvm kernel module is loaded, otherwise load it${reset}"
  if ! lsmod | grep -iE 'kvm'; then
    if [[ `lscpu | grep 'Vendor ID' | awk 'BEGIN { FS = ":" } ; {print $2}' | tr -d ' '` == 'GenuineIntel' ]]; then
      echo "${blue}Intel processor identified, loading kernel module kvm-intel${reset}"
      kernel_mod='kvm-intel'
      modprobe ${kernel_mod}
    fi
    if [[ `lscpu | grep 'Vendor ID' | awk 'BEGIN { FS = ":" } ; {print $2}' | tr -d ' '` == 'AuthenticAMD' ]]; then
      echo "${blue}AMD processor identified, loading kernel module kvm-amd${reset}"
      kernel_mod='kvm-amd'
      modprobe ${kernel_mod}
    fi
    if ! lsmod | grep -iE 'kvm'; then
      echo "${red}Failed to load kernel module ${kernel_mod}!${reset}"
      exit 1
    fi
  else
    echo "${green}OK!${reset}"
  fi
}

###check whether libvirtd service is running otherwise start it
start_libvirtd_service() {
  echo "${blue}Checking whether libvirtd service is running otherwise start it${reset}"
  if ! sudo systemctl status libvirtd | grep -iE 'active \(running\)'; then
    echo "${blue}starting libvirtd service${reset}"
    systemctl start libvirtd
    if ! sudo systemctl status libvirtd | grep -iE 'active \(running\)'; then
      echo "${red}Failed to start libvirtd service!${reset}"
      exit 1
    fi
  else
    echo "${green}OK!${reset}"
  fi
}

#Check whether interface is UP
check_interface() {
  if [ -z $1 ]; then
    echo "${red}Cannot bring UP, No interface specified${reset}"
    exit 1
  fi
  local interface=$1
  echo "${blue}Checking whether interface ${interface} is UP${reset}"
  link_state=$(ip link show ${interface} | grep -oP 'state \K[^ ]+')
  if [[ ${link_state} != 'UP' ]]; then
    echo "${blue}${interface} state is ${link_state}. Bringing it UP!${reset}"
    ip link set dev ${interface} up
    sleep 5
    link_state=$(ip link show ${interface} | grep -oP 'state \K[^ ]+')
    if [[ ${link_state} == 'DOWN' ]]; then
      echo "${red}Could not bring UP interface ${interface} link state is ${link_state}${reset}"
      exit 1
    fi
  else
    echo "${green}OK!${reset}"
  fi
}

setup_pxe_bridge() {
  #Check whether private interface exists
  echo "${blue}Checking whether private interface ${private_interface} exists${reset}"
  if ! ip link show ${private_interface}; then
    echo "${red}Private interface ${private_interface} does not exists!${reset}"
    exit 1
  else
    echo "${green}OK!${reset}"
  fi

  #Check whether private interface is UP
  check_interface ${private_interface}

  pxe_vid=0
  pxe_interface="${private_interface}.${pxe_vid}"

  #Check whether VLAN 0 (PXE) interface exists
  echo "${blue}Checking whether VLAN 0 (PXE) interface ${pxe_interface} exists${reset}"
  if ! ip link show ${pxe_interface}; then
    echo "${blue}Creating  VLAN 0 (PXE) interface ${pxe_interface}${reset}"
    ip link add link ${private_interface} name ${pxe_interface} type vlan id ${pxe_vid}
  else
    echo "${green}OK!${reset}"
  fi

  #Check whether VLAN 0 (PXE) interface is UP
  check_interface ${pxe_interface}

  #Check whether PXE bridge exists
  echo "${blue}Checking whether PXE bridge ${pxe_bridge} exists${reset}"
  if brctl show ${pxe_bridge} 2>&1 | grep 'No such device'; then
    echo "${blue}Creating PXE bridge ${pxe_bridge}${reset}"
    brctl addbr ${pxe_bridge}
  else
    echo "${green}OK!${reset}"
  fi

  #Add VLAN 0 (PXE) interface to PXE bridge
  echo "${blue}Checking whether VLAN 0 (PXE) interface ${pxe_interface} is added to PXE bridge ${pxe_bridge} exists${reset}"
  if ! brctl show ${pxe_bridge} 2>&1 | grep ${pxe_interface}; then
    echo "${blue}Adding VLAN 0 (PXE) interface ${pxe_interface} to PXE bridge ${pxe_bridge}${reset}"
    brctl addif ${pxe_bridge} ${pxe_interface}
    if ! brctl show ${pxe_bridge} 2>&1 | grep ${pxe_interface}; then
      echo "${red}Could not add VLAN 0 (PXE) interface ${pxe_interface} to PXE bridge ${pxe_bridge}${reset}"
      exit 1
    fi
  else
    echo "${green}OK!${reset}"
  fi

  #Check whether PXE bridge is UP
  check_interface ${pxe_bridge}

  #Add Fuel Gateway IP Address to PXE bridge
  echo "${blue}Checking whether Fuel Gateway IP Address ${fuel_gw_ip} is assigned to PXE bridge ${pxe_bridge}${reset}"
  if ! ip addr show ${pxe_bridge} | grep ${fuel_gw_ip}; then
    echo "${blue}Adding Fuel Gateway IP Address ${fuel_gw_ip} to PXE bridge ${pxe_bridge}${reset}"
    sudo ip addr add ${fuel_gw_ip} dev ${pxe_bridge}
    if ! ip addr show ${pxe_bridge} | grep ${fuel_gw_ip}; then
      echo "${red}Could not add Fuel Gateway IP Address ${fuel_gw_ip} to PXE bridge ${pxe_bridge}${reset}"
      exit 1
    fi
  else
    echo "${green}OK!${reset}"
  fi
}
###check whether access to public network is granted
check_access_enabled_to_public_network() {
  #Check whether public interface exists
  echo "${blue}Checking whether public interface ${public_interface} exists${reset}"
  if ! ip link show ${public_interface}; then
    echo "${red}Public interface ${public_interface} does not exists!${reset}"
    exit 1
  else
    echo "${green}OK!${reset}"
  fi

  #Check whether public interface ${public_interface} is UP
  check_interface ${public_interface}

  echo "${blue}Checking whether access is granted to public network through interface ${public_interface}${reset}"
  if ! sudo iptables -t nat -L POSTROUTING -v | grep "MASQUERADE.*${public_interface}.*anywhere.*anywhere"; then
    echo "${blue}Enable access to public network through interface ${public_interface}${reset}"
    iptables -t nat -A POSTROUTING -o ${public_interface} -j MASQUERADE
  else
    echo "${green}OK!${reset}"
  fi
}
##END FUNCTIONS

main() {
  install_qemu_kvm
  install_libvirt
  load_kvm_kernel_mod
  start_libvirtd_service
  setup_pxe_bridge
  check_access_enabled_to_public_network
}

main "$@"
