#!/usr/bin/env bash

#Deploy script to install provisioning server for Foreman/QuickStack
#author: Tim Rozet (trozet@redhat.com)
#
#Uses Vagrant and VirtualBox
#VagrantFile uses bootsrap.sh which Installs Khaleesi
#Khaleesi will install and configure Foreman/QuickStack
#
#Pre-requisties:
#Supports 3 or 4 network interface configuration
#Target system must be RPM based
#Ensure the host's kernel is up to date (yum update)
#Provisioned nodes expected to have following order of network connections (note: not all have to exist, but order is maintained):
#eth0- admin network
#eth1- private network (+storage network in 3 NIC config)
#eth2- public network
#eth3- storage network
#script assumes /24 subnet mask

##VARS
reset=`tput sgr0`
blue=`tput setaf 4`
red=`tput setaf 1`
green=`tput setaf 2`

declare -A interface_arr
declare -A controllers_ip_arr
declare -A admin_ip_arr
declare -A public_ip_arr

vm_dir=/var/opt/opnfv
##END VARS

##FUNCTIONS
display_usage() {
  echo -e "\n\n${blue}This script is used to deploy Foreman/QuickStack Installer and Provision OPNFV Target System${reset}\n\n"
  echo -e "\n${green}Make sure you have the latest kernel installed before running this script! (yum update kernel +reboot)${reset}\n"
  echo -e "\nUsage:\n$0 [arguments] \n"
  echo -e "\n   -no_parse : No variable parsing into config. Flag. \n"
  echo -e "\n   -base_config : Full path of settings file to parse. Optional.  Will provide a new base settings file rather than the default.  Example:  -base_config /opt/myinventory.yml \n"
  echo -e "\n   -virtual : Node virtualization instead of baremetal. Flag. \n"
  echo -e "\n   -enable_virtual_dhcp : Run dhcp server instead of using static IPs.  Use this with -virtual only. \n"
  echo -e "\n   -static_ip_range : static IP range to define when using virtual and when dhcp is not being used (default), must at least a 20 IP block.  Format: '192.168.1.1,192.168.1.20' \n"
  echo -e "\n   -ping_site : site to use to verify IP connectivity from the VM when -virtual is used.  Format: -ping_site www.blah.com \n"
  echo -e "\n   -floating_ip_count : number of IP address from the public range to be used for floating IP. Default is 20.\n"
}

##verify vm dir exists
##params: none
function verify_vm_dir {
  if [ -d "$vm_dir" ]; then
    echo -e "\n\n${red}ERROR: VM Directory: $vm_dir already exists.  Environment not clean.  Please use clean.sh.  Exiting${reset}\n\n"
    exit 1
  else
    mkdir -p $vm_dir
  fi

  chmod 700 $vm_dir

  if [ ! -d $vm_dir ]; then
    echo -e "\n\n${red}ERROR: Unable to create VM Directory: $vm_dir  Exiting${reset}\n\n"
    exit -1
  fi
}

##find ip of interface
##params: interface name
function find_ip {
  ip addr show $1 | grep -Eo '^\s+inet\s+[\.0-9]+' | awk '{print $2}'
}

##finds subnet of ip and netmask
##params: ip, netmask
function find_subnet {
  IFS=. read -r i1 i2 i3 i4 <<< "$1"
  IFS=. read -r m1 m2 m3 m4 <<< "$2"
  printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 & m4))"
}

##verify subnet has at least n IPs
##params: subnet mask, n IPs
function verify_subnet_size {
  IFS=. read -r i1 i2 i3 i4 <<< "$1"
  num_ips_required=$2

  ##this function assumes you would never need more than 254
  ##we check here to make sure
  if [ "$num_ips_required" -ge 254 ]; then
    echo -e "\n\n${red}ERROR: allocating more than 254 IPs is unsupported...Exiting${reset}\n\n"
    return 1
  fi

  ##we just return if 3rd octet is not 255
  ##because we know the subnet is big enough
  if [ "$i3" -ne 255 ]; then
    return 0
  elif [ $((254-$i4)) -ge "$num_ips_required" ]; then
    return 0
  else
    echo -e "\n\n${red}ERROR: Subnet is too small${reset}\n\n"
    return 1
  fi
}

##finds last usable ip (broadcast minus 1) of a subnet from an IP and netmask
## Warning: This function only works for IPv4 at the moment.
##params: ip, netmask
function find_last_ip_subnet {
  IFS=. read -r i1 i2 i3 i4 <<< "$1"
  IFS=. read -r m1 m2 m3 m4 <<< "$2"
  IFS=. read -r s1 s2 s3 s4 <<< "$((i1 & m1)).$((i2 & m2)).$((i3 & m3)).$((i4 & m4))"
  printf "%d.%d.%d.%d\n" "$((255 - $m1 + $s1))" "$((255 - $m2 + $s2))" "$((255 - $m3 + $s3))" "$((255 - $m4 + $s4 - 1))"
}

##increments subnet by a value
##params: ip, value
##assumes low value
function increment_subnet {
  IFS=. read -r i1 i2 i3 i4 <<< "$1"
  printf "%d.%d.%d.%d\n" "$i1" "$i2" "$i3" "$((i4 | $2))"
}


##finds netmask of interface
##params: interface
##returns long format 255.255.x.x
function find_netmask {
  ifconfig $1 | grep -Eo 'netmask\s+[\.0-9]+' | awk '{print $2}'
}

##finds short netmask of interface
##params: interface
##returns short format, ex: /21
function find_short_netmask {
  echo "/$(ip addr show $1 | grep -Eo '^\s+inet\s+[\/\.0-9]+' | awk '{print $2}' | cut -d / -f2)"
}

##increments next IP
##params: ip
##assumes a /24 subnet
function next_ip {
  baseaddr="$(echo $1 | cut -d. -f1-3)"
  lsv="$(echo $1 | cut -d. -f4)"
  if [ "$lsv" -ge 254 ]; then
    return 1
  fi
  ((lsv++))
  echo $baseaddr.$lsv
}

##subtracts a value from an IP address
##params: last ip, ip_count
##assumes ip_count is less than the last octect of the address
subtract_ip() {
  IFS=. read -r i1 i2 i3 i4 <<< "$1"
  ip_count=$2
  if [ $i4 -lt $ip_count ]; then
    echo -e "\n\n${red}ERROR: Can't subtract $ip_count from IP address $1  Exiting${reset}\n\n"
    exit 1
  fi
  printf "%d.%d.%d.%d\n" "$i1" "$i2" "$i3" "$((i4 - $ip_count ))"
}

##removes the network interface config from Vagrantfile
##params: interface
##assumes you are in the directory of Vagrantfile
function remove_vagrant_network {
  sed -i 's/^.*'"$1"'.*$//' Vagrantfile
}

##check if IP is in use
##params: ip
##ping ip to get arp entry, then check arp
function is_ip_used {
  ping -c 5 $1 > /dev/null 2>&1
  arp -n | grep "$1 " | grep -iv incomplete > /dev/null 2>&1
}

##find next usable IP
##params: ip
function next_usable_ip {
  new_ip=$(next_ip $1)
  while [ "$new_ip" ]; do
    if ! is_ip_used $new_ip; then
      echo $new_ip
      return 0
    fi
    new_ip=$(next_ip $new_ip)
  done
  return 1
}

##increment ip by value
##params: ip, amount to increment by
##increment_ip $next_private_ip 10
function increment_ip {
  baseaddr="$(echo $1 | cut -d. -f1-3)"
  lsv="$(echo $1 | cut -d. -f4)"
  incrval=$2
  lsv=$((lsv+incrval))
  if [ "$lsv" -ge 254 ]; then
    return 1
  fi
  echo $baseaddr.$lsv
}

##translates yaml into variables
##params: filename, prefix (ex. "config_")
##usage: parse_yaml opnfv_ksgen_settings.yml "config_"
parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

##translates the command line paramaters into variables
##params: $@ the entire command line is passed
##usage: parse_cmd_line() "$@"
parse_cmdline() {
  if [[ ( $1 == "--help") ||  $1 == "-h" ]]; then
    display_usage
    exit 0
  fi

  echo -e "\n\n${blue}This script is used to deploy Foreman/QuickStack Installer and Provision OPNFV Target System${reset}\n\n"
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
        -no_parse)
                no_parse="TRUE"
                shift 1
            ;;
        -virtual)
                virtual="TRUE"
                shift 1
            ;;
        -enable_virtual_dhcp)
                enable_virtual_dhcp="TRUE"
                shift 1
            ;;
        -static_ip_range)
                static_ip_range=$2
                shift 2
            ;;
        -ping_site)
                ping_site=$2
                shift 2
            ;;
        -floating_ip_count)
                floating_ip_count=$2
                shift 2
            ;;
        *)
                display_usage
                exit 1
            ;;
    esac
  done

  if [ ! -z "$enable_virtual_dhcp" ] && [ ! -z "$static_ip_range" ]; then
    echo -e "\n\n${red}ERROR: Incorrect Usage.  Static IP range cannot be set when using DHCP!.  Exiting${reset}\n\n"
    exit 1
  fi

  if [ -z "$virtual" ]; then
    if [ ! -z "$enable_virtual_dhcp" ]; then
      echo -e "\n\n${red}ERROR: Incorrect Usage.  enable_virtual_dhcp can only be set when using -virtual!.  Exiting${reset}\n\n"
      exit 1
    elif [ ! -z "$static_ip_range" ]; then
      echo -e "\n\n${red}ERROR: Incorrect Usage.  static_ip_range can only be set when using -virtual!.  Exiting${reset}\n\n"
      exit 1
    fi
  fi

  if [ -z "$floating_ip_count" ]; then
    floating_ip_count=20
  fi
}

##disable selinux
##params: none
##usage: disable_selinux()
disable_selinux() {
  /sbin/setenforce 0
}

##Install the EPEL repository and additional packages
##params: none
##usage: install_EPEL()
install_EPEL() {
  # Install EPEL repo for access to many other yum repos
  # Major version is pinned to force some consistency for Arno
  yum install -y epel-release-7*

  # Install other required packages
  # Major versions are pinned to force some consistency for Arno
  if ! yum install -y binutils-2* gcc-4* make-3* patch-2* libgomp-4* glibc-headers-2* glibc-devel-2* kernel-headers-3* kernel-devel-3* dkms-2* psmisc-22*; then
    printf '%s\n' 'deploy.sh: Unable to install depdency packages' >&2
    exit 1
  fi
}

##Download and install virtual box
##params: none
##usage: install_vbox()
install_vbox() {
  ##install VirtualBox repo
  if cat /etc/*release | grep -i "Fedora release"; then
    vboxurl=http://download.virtualbox.org/virtualbox/rpm/fedora/\$releasever/\$basearch
  else
    vboxurl=http://download.virtualbox.org/virtualbox/rpm/el/\$releasever/\$basearch
  fi

  cat > /etc/yum.repos.d/virtualbox.repo << EOM
[virtualbox]
name=Oracle Linux / RHEL / CentOS-\$releasever / \$basearch - VirtualBox
baseurl=$vboxurl
enabled=1
gpgcheck=1
gpgkey=https://www.virtualbox.org/download/oracle_vbox.asc
skip_if_unavailable = 1
keepcache = 0
EOM

  ##install VirtualBox
  if ! yum list installed | grep -i virtualbox; then
    if ! yum -y install VirtualBox-4.3; then
      printf '%s\n' 'deploy.sh: Unable to install virtualbox package' >&2
      exit 1
    fi
  fi

  ##install kmod-VirtualBox
  if ! lsmod | grep vboxdrv; then
    sudo /etc/init.d/vboxdrv setup
    if ! lsmod | grep vboxdrv; then
      printf '%s\n' 'deploy.sh: Unable to install kernel module for virtualbox' >&2
      exit 1
    fi
  else
    printf '%s\n' 'deploy.sh: Skipping kernel module for virtualbox.  Already Installed'
  fi
}

##install Ansible using yum
##params: none
##usage: install_ansible()
install_ansible() {
  if ! yum list installed | grep -i ansible; then
    if ! yum -y install ansible-1*; then
      printf '%s\n' 'deploy.sh: Unable to install Ansible package' >&2
      exit 1
    fi
  fi
}

##install Vagrant RPM directly with the bintray.com site
##params: none
##usage: install_vagrant()
install_vagrant() {
  if ! rpm -qa | grep vagrant; then
    if ! rpm -Uvh https://dl.bintray.com/mitchellh/vagrant/vagrant_1.7.2_x86_64.rpm; then
      printf '%s\n' 'deploy.sh: Unable to install vagrant package' >&2
      exit 1
    fi
  else
    printf '%s\n' 'deploy.sh: Skipping Vagrant install as it is already installed.'
  fi

  ##add centos 7 box to vagrant
  if ! vagrant box list | grep opnfv/centos-7.0; then
    if ! vagrant box add opnfv/centos-7.0 --provider virtualbox; then
      printf '%s\n' 'deploy.sh: Unable to download centos7 box for Vagrant' >&2
      exit 1
    fi
  else
    printf '%s\n' 'deploy.sh: Skipping Vagrant box add as centos-7.0 is already installed.'
  fi

  ##install workaround for centos7
  if ! vagrant plugin list | grep vagrant-centos7_fix; then
    if ! vagrant plugin install vagrant-centos7_fix; then
      printf '%s\n' 'deploy.sh: Warning: unable to install vagrant centos7 workaround' >&2
    fi
  else
    printf '%s\n' 'deploy.sh: Skipping Vagrant plugin as centos7 workaround is already installed.'
  fi
}


##remove bgs vagrant incase it wasn't cleaned up
##params: none
##usage: clean_tmp()
clean_tmp() {
  rm -rf $vm_dir/foreman_vm
}

##clone genesis and move to node vm dir
##params: none
##usage: clone_bgs
clone_bgs() {
  cd /tmp/
  rm -rf /tmp/genesis/

  ##clone artifacts and move into foreman_vm dir
  if ! GIT_SSL_NO_VERIFY=true git clone https://gerrit.opnfv.org/gerrit/genesis.git; then
    printf '%s\n' 'deploy.sh: Unable to clone genesis repo' >&2
    exit 1
  fi

  mv -f /tmp/genesis/foreman/ci $vm_dir/foreman_vm
  rm -rf /tmp/genesis/
}

##validates the network settings and update VagrantFile with network settings
##params: none
##usage: configure_network()
configure_network() {
  cd $vm_dir/foreman_vm

  echo "${blue}Detecting network configuration...${reset}"
  ##detect host 1 or 3 interface configuration
  #output=`ip link show | grep -E "^[0-9]" | grep -Ev ": lo|tun|virbr|vboxnet" | awk '{print $2}' | sed 's/://'`
  output=`ifconfig | grep -E "^[a-zA-Z0-9]+:"| grep -Ev "lo|tun|virbr|vboxnet" | awk '{print $1}' | sed 's/://'`

  if [ ! "$output" ]; then
    printf '%s\n' 'deploy.sh: Unable to detect interfaces to bridge to' >&2
    exit 1
  fi

  ##virtual we only find 1 interface
  if [ $virtual ]; then
    ##find interface with default gateway
    this_default_gw=$(ip route | grep default | awk '{print $3}')
    echo "${blue}Default Gateway: $this_default_gw ${reset}"
    this_default_gw_interface=$(ip route get $this_default_gw | awk '{print $3}')

    ##find interface IP, make sure its valid
    interface_ip=$(find_ip $this_default_gw_interface)
    if [ ! "$interface_ip" ]; then
      echo "${red}Interface ${this_default_gw_interface} does not have an IP: $interface_ip ! Exiting ${reset}"
      exit 1
    fi

    ##set variable info
    if [ ! -z "$static_ip_range" ]; then
      new_ip=$(echo $static_ip_range | cut -d , -f1)
    else
      new_ip=$(next_usable_ip $interface_ip)
      if [ ! "$new_ip" ]; then
        echo "${red} Cannot find next IP on interface ${this_default_gw_interface} new_ip: $new_ip ! Exiting ${reset}"
        exit 1
      fi
    fi
    interface=$this_default_gw_interface
    public_interface=$interface
    interface_arr[$interface]=2
    interface_ip_arr[2]=$new_ip
    subnet_mask=$(find_netmask $interface)
    public_subnet_mask=$subnet_mask
    public_short_subnet_mask=$(find_short_netmask $interface)

    if ! verify_subnet_size $public_subnet_mask 25; then
      echo "${red} Not enough IPs in public subnet: $interface_ip_arr[2] ${public_subnet_mask}.  Need at least 25 IPs.  Please resize subnet! Exiting ${reset}"
      exit 1
    fi

    ##set that interface to be public
    sed -i 's/^.*eth_replace2.*$/  config.vm.network "public_network", ip: '\""$new_ip"\"', bridge: '\'"$interface"\'', netmask: '\""$subnet_mask"\"'/' Vagrantfile
    if_counter=1
  else
    ##find number of interfaces with ip and substitute in VagrantFile
    if_counter=0
    for interface in ${output}; do

      if [ "$if_counter" -ge 4 ]; then
        break
      fi
      interface_ip=$(find_ip $interface)
      if [ ! "$interface_ip" ]; then
        continue
      fi
      new_ip=$(next_usable_ip $interface_ip)
      if [ ! "$new_ip" ]; then
        continue
      fi
      interface_arr[$interface]=$if_counter
      interface_ip_arr[$if_counter]=$new_ip
      subnet_mask=$(find_netmask $interface)
      if [ "$if_counter" -eq 0 ]; then
        admin_subnet_mask=$subnet_mask
        if ! verify_subnet_size $admin_subnet_mask 5; then
          echo "${red} Not enough IPs in admin subnet: ${interface_ip_arr[$if_counter]} ${admin_subnet_mask}.  Need at least 5 IPs.  Please resize subnet! Exiting ${reset}"
          exit 1
        fi

      elif [ "$if_counter" -eq 1 ]; then
        private_subnet_mask=$subnet_mask
        private_short_subnet_mask=$(find_short_netmask $interface)

        if ! verify_subnet_size $private_subnet_mask 15; then
          echo "${red} Not enough IPs in private subnet: ${interface_ip_arr[$if_counter]} ${private_subnet_mask}.  Need at least 15 IPs.  Please resize subnet! Exiting ${reset}"
          exit 1
        fi
      elif [ "$if_counter" -eq 2 ]; then
        public_subnet_mask=$subnet_mask
        public_short_subnet_mask=$(find_short_netmask $interface)

        if ! verify_subnet_size $public_subnet_mask 25; then
          echo "${red} Not enough IPs in public subnet: ${interface_ip_arr[$if_counter]} ${public_subnet_mask}.  Need at least 25 IPs.  Please resize subnet! Exiting ${reset}"
          exit 1
        fi
      elif [ "$if_counter" -eq 3 ]; then
        storage_subnet_mask=$subnet_mask

        if ! verify_subnet_size $storage_subnet_mask 10; then
          echo "${red} Not enough IPs in storage subnet: ${interface_ip_arr[$if_counter]} ${storage_subnet_mask}.  Need at least 10 IPs.  Please resize subnet! Exiting ${reset}"
          exit 1
        fi
      else
        echo "${red}ERROR: interface counter outside valid range of 0 to 3: $if_counter ! ${reset}"
        exit 1
      fi
      sed -i 's/^.*eth_replace'"$if_counter"'.*$/  config.vm.network "public_network", ip: '\""$new_ip"\"', bridge: '\'"$interface"\'', netmask: '\""$subnet_mask"\"'/' Vagrantfile
      ((if_counter++))
    done
  fi
  ##now remove interface config in Vagrantfile for 1 node
  ##if 1, 3, or 4 interfaces set deployment type
  ##if 2 interfaces remove 2nd interface and set deployment type
  if [[ "$if_counter" == 1 || "$if_counter" == 2 ]]; then
    if [ $virtual ]; then
      deployment_type="single_network"
      echo "${blue}Single network detected for Virtual deployment...converting to three_network with internal networks! ${reset}"
      private_internal_ip=155.1.2.2
      admin_internal_ip=156.1.2.2
      private_subnet_mask=255.255.255.0
      private_short_subnet_mask=/24
      interface_ip_arr[1]=$private_internal_ip
      interface_ip_arr[0]=$admin_internal_ip
      admin_subnet_mask=255.255.255.0
      admin_short_subnet_mask=/24
      sed -i 's/^.*eth_replace1.*$/  config.vm.network "private_network", virtualbox__intnet: "my_private_network", ip: '\""$private_internal_ip"\"', netmask: '\""$private_subnet_mask"\"'/' Vagrantfile
      sed -i 's/^.*eth_replace0.*$/  config.vm.network "private_network", virtualbox__intnet: "my_admin_network", ip: '\""$admin_internal_ip"\"', netmask: '\""$private_subnet_mask"\"'/' Vagrantfile
      remove_vagrant_network eth_replace3
      deployment_type=three_network
    else
       echo "${blue}Single network or 2 network detected for baremetal deployment.  This is unsupported! Exiting. ${reset}"
       exit 1
    fi
  elif [ "$if_counter" == 3 ]; then
    deployment_type="three_network"
    remove_vagrant_network eth_replace3
  else
    deployment_type="multi_network"
  fi

  echo "${blue}Network detected: ${deployment_type}! ${reset}"

  if [ $virtual ]; then
    if [ -z "$enable_virtual_dhcp" ]; then
      sed -i 's/^.*disable_dhcp_flag =.*$/  disable_dhcp_flag = true/' Vagrantfile
      if [ $static_ip_range ]; then
        ##verify static range is at least 20 IPs
        static_ip_range_begin=$(echo $static_ip_range | cut -d , -f1)
        static_ip_range_end=$(echo $static_ip_range | cut -d , -f2)
        ##verify range is at least 20 ips
        ##assumes less than 255 range pool
        begin_octet=$(echo $static_ip_range_begin | cut -d . -f4)
        end_octet=$(echo $static_ip_range_end | cut -d . -f4)
        ip_count=$((end_octet-begin_octet+1))
        if [ "$ip_count" -lt 20 ]; then
          echo "${red}Static range is less than 20 ips: ${ip_count}, exiting  ${reset}"
          exit 1
        else
          echo "${blue}Static IP range is size $ip_count ${reset}"
        fi
      fi
    fi
  fi

  if route | grep default; then
    echo "${blue}Default Gateway Detected ${reset}"
    host_default_gw=$(ip route | grep default | awk '{print $3}')
    echo "${blue}Default Gateway: $host_default_gw ${reset}"
    default_gw_interface=$(ip route get $host_default_gw | awk '{print $3}')
    case "${interface_arr[$default_gw_interface]}" in
      0)
        echo "${blue}Default Gateway Detected on Admin Interface!${reset}"
        sed -i 's/^.*default_gw =.*$/  default_gw = '\""$host_default_gw"\"'/' Vagrantfile
        node_default_gw=$host_default_gw
        ;;
      1)
        echo "${red}Default Gateway Detected on Private Interface!${reset}"
        echo "${red}Private subnet should be private and not have Internet access!${reset}"
        exit 1
        ;;
      2)
        echo "${blue}Default Gateway Detected on Public Interface!${reset}"
        sed -i 's/^.*default_gw =.*$/  default_gw = '\""$host_default_gw"\"'/' Vagrantfile
        echo "${blue}Will setup NAT from Admin -> Public Network on VM!${reset}"
        sed -i 's/^.*nat_flag =.*$/  nat_flag = true/' Vagrantfile
        echo "${blue}Setting node gateway to be VM Admin IP${reset}"
        node_default_gw=${interface_ip_arr[0]}
        public_gateway=$default_gw
        ;;
      3)
        echo "${red}Default Gateway Detected on Storage Interface!${reset}"
        echo "${red}Storage subnet should be private and not have Internet access!${reset}"
        exit 1
        ;;
      *)
        echo "${red}Unable to determine which interface default gateway is on..Exiting!${reset}"
        exit 1
        ;;
    esac
  else
    #assumes 24 bit mask
    defaultgw=`echo ${interface_ip_arr[0]} | cut -d. -f1-3`
    firstip=.1
    defaultgw=$defaultgw$firstip
    echo "${blue}Unable to find default gateway.  Assuming it is $defaultgw ${reset}"
    sed -i 's/^.*default_gw =.*$/  default_gw = '\""$defaultgw"\"'/' Vagrantfile
    node_default_gw=$defaultgw
  fi

  if [ $base_config ]; then
    if ! cp -f $base_config opnfv_ksgen_settings.yml; then
      echo "{red}ERROR: Unable to copy $base_config to opnfv_ksgen_settings.yml${reset}"
      exit 1
    fi
  fi

  nodes=`sed -nr '/nodes:/{:start /workaround/!{N;b start};//p}' opnfv_ksgen_settings.yml | sed -n '/^  [A-Za-z0-9]\+:$/p' | sed 's/\s*//g' | sed 's/://g'`
  controller_nodes=`echo $nodes | tr " " "\n" | grep controller | tr "\n" " "`
  echo "${blue}Controller nodes found in settings: ${controller_nodes}${reset}"
  my_controller_array=( $controller_nodes )
  num_control_nodes=${#my_controller_array[@]}
  if [ "$num_control_nodes" -ne 3 ]; then
    if cat opnfv_ksgen_settings.yml | grep ha_flag | grep true; then
      echo "${red}Error: You must define exactly 3 control nodes when HA flag is true!${reset}"
      exit 1
    fi
  else
    echo "${blue}Number of Controller nodes detected: ${num_control_nodes}${reset}"
  fi

  if [ $no_parse ]; then
    echo "${blue}Skipping parsing variables into settings file as no_parse flag is set${reset}"

  else

    echo "${blue}Gathering network parameters for Target System...this may take a few minutes${reset}"
    ##Edit the ksgen settings appropriately
    ##ksgen settings will be stored in /vagrant on the vagrant machine
    ##if single node deployment all the variables will have the same ip
    ##interface names will be enp0s3, enp0s8, enp0s9 in chef/centos7

    sed -i 's/^.*default_gw:.*$/default_gw:'" $node_default_gw"'/' opnfv_ksgen_settings.yml

    ##replace private interface parameter
    ##private interface will be of hosts, so we need to know the provisioned host interface name
    ##we add biosdevname=0, net.ifnames=0 to the kickstart to use regular interface naming convention on hosts
    ##replace IP for parameters with next IP that will be given to controller
    if [ "$deployment_type" == "single_network" ]; then
      ##we also need to assign IP addresses to nodes
      ##for single node, foreman is managing the single network, so we can't reserve them
      ##not supporting single network anymore for now
      echo "{blue}Single Network type is unsupported right now.  Please check your interface configuration.  Exiting. ${reset}"
      exit 0

    elif [[ "$deployment_type" == "multi_network" || "$deployment_type" == "three_network" ]]; then

      if [ "$deployment_type" == "three_network" ]; then
        sed -i 's/^.*network_type:.*$/network_type: three_network/' opnfv_ksgen_settings.yml
      fi

      sed -i 's/^.*deployment_type:.*$/  deployment_type: '"$deployment_type"'/' opnfv_ksgen_settings.yml

      ##get ip addresses for private network on controllers to make dhcp entries
      ##required for controllers_ip_array global param
      next_private_ip=${interface_ip_arr[1]}
      type=_private
      control_count=0
      for node in controller1 controller2 controller3; do
        next_private_ip=$(next_usable_ip $next_private_ip)
        if [ ! "$next_private_ip" ]; then
          printf '%s\n' 'deploy.sh: Unable to find next ip for private network for control nodes' >&2
          exit 1
        fi
        sed -i 's/'"$node$type"'/'"$next_private_ip"'/g' opnfv_ksgen_settings.yml
        controller_ip_array=$controller_ip_array$next_private_ip,
        controllers_ip_arr[$control_count]=$next_private_ip
        ((control_count++))
      done

      next_public_ip=${interface_ip_arr[2]}
      foreman_ip=$next_public_ip

      ##if no dhcp, find all the Admin IPs for nodes in advance
      if [ $virtual ]; then
        if [ -z "$enable_virtual_dhcp" ]; then
          sed -i 's/^.*no_dhcp:.*$/no_dhcp: true/' opnfv_ksgen_settings.yml
          nodes=`sed -nr '/nodes:/{:start /workaround/!{N;b start};//p}' opnfv_ksgen_settings.yml | sed -n '/^  [A-Za-z0-9]\+:$/p' | sed 's/\s*//g' | sed 's/://g'`
          compute_nodes=`echo $nodes | tr " " "\n" | grep -v controller | tr "\n" " "`
          controller_nodes=`echo $nodes | tr " " "\n" | grep controller | tr "\n" " "`
          nodes=${controller_nodes}${compute_nodes}
          next_admin_ip=${interface_ip_arr[0]}
          type=_admin
          for node in ${nodes}; do
            next_admin_ip=$(next_ip $next_admin_ip)
            if [ ! "$next_admin_ip" ]; then
              echo "${red} Unable to find an unused IP in admin_network for $node ! ${reset}"
              exit 1
            else
              admin_ip_arr[$node]=$next_admin_ip
              sed -i 's/'"$node$type"'/'"$next_admin_ip"'/g' opnfv_ksgen_settings.yml
            fi
          done

          ##allocate node public IPs
          for node in ${nodes}; do
            next_public_ip=$(next_usable_ip $next_public_ip)
            if [ ! "$next_public_ip" ]; then
              echo "${red} Unable to find an unused IP in admin_network for $node ! ${reset}"
              exit 1
            else
              public_ip_arr[$node]=$next_public_ip
            fi
          done
        fi
      fi
      ##replace global param for controllers_ip_array
      controller_ip_array=${controller_ip_array%?}
      sed -i 's/^.*controllers_ip_array:.*$/  controllers_ip_array: '"$controller_ip_array"'/' opnfv_ksgen_settings.yml

      ##now replace all the VIP variables.  admin//private can be the same IP
      ##we have to use IP's here that won't be allocated to hosts at provisioning time
      ##therefore we increment the ip by 10 to make sure we have a safe buffer
      next_private_ip=$(increment_ip $next_private_ip 10)

      private_output=$(grep -E '*private_vip|loadbalancer_vip|db_vip|amqp_vip|*admin_vip' opnfv_ksgen_settings.yml)
      if [ ! -z "$private_output" ]; then
        while read -r line; do
          sed -i 's/^.*'"$line"'.*$/  '"$line $next_private_ip"'/' opnfv_ksgen_settings.yml
          next_private_ip=$(next_usable_ip $next_private_ip)
          if [ ! "$next_private_ip" ]; then
            printf '%s\n' 'deploy.sh: Unable to find next ip for private network for vip replacement' >&2
            exit 1
          fi
        done <<< "$private_output"
      fi

      ##replace odl_control_ip (non-HA only)
      odl_control_ip=${controllers_ip_arr[0]}
      sed -i 's/^.*odl_control_ip:.*$/  odl_control_ip: '"$odl_control_ip"'/' opnfv_ksgen_settings.yml

      ##replace controller_ip (non-HA only)
      sed -i 's/^.*controller_ip:.*$/  controller_ip: '"$odl_control_ip"'/' opnfv_ksgen_settings.yml

      ##replace foreman site
      sed -i 's/^.*foreman_url:.*$/  foreman_url:'" https:\/\/$foreman_ip"'\/api\/v2\//' opnfv_ksgen_settings.yml
      ##replace public vips
      ##no need to do this if no dhcp
      if [[ -z "$enable_virtual_dhcp" && ! -z "$virtual" ]]; then
        next_public_ip=$(next_usable_ip $next_public_ip)
      else
        next_public_ip=$(increment_ip $next_public_ip 10)
      fi

      public_output=$(grep -E '*public_vip' opnfv_ksgen_settings.yml)
      if [ ! -z "$public_output" ]; then
        while read -r line; do
          if echo $line | grep horizon_public_vip; then
            horizon_public_vip=$next_public_ip
          fi
          sed -i 's/^.*'"$line"'.*$/  '"$line $next_public_ip"'/' opnfv_ksgen_settings.yml
          next_public_ip=$(next_usable_ip $next_public_ip)
          if [ ! "$next_public_ip" ]; then
            printf '%s\n' 'deploy.sh: Unable to find next ip for public network for vip replcement' >&2
            exit 1
          fi
        done <<< "$public_output"
      fi

      ##replace public_network param
      public_subnet=$(find_subnet $next_public_ip $public_subnet_mask)
      sed -i 's/^.*public_network:.*$/  public_network:'" $public_subnet"'/' opnfv_ksgen_settings.yml
      ##replace private_network param
      private_subnet=$(find_subnet $next_private_ip $private_subnet_mask)
      sed -i 's/^.*private_network:.*$/  private_network:'" $private_subnet"'/' opnfv_ksgen_settings.yml
      ##replace storage_network
      if [ "$deployment_type" == "three_network" ]; then
        sed -i 's/^.*storage_network:.*$/  storage_network:'" $private_subnet"'/' opnfv_ksgen_settings.yml
      else
        next_storage_ip=${interface_ip_arr[3]}
        storage_subnet=$(find_subnet $next_storage_ip $storage_subnet_mask)
        sed -i 's/^.*storage_network:.*$/  storage_network:'" $storage_subnet"'/' opnfv_ksgen_settings.yml
      fi

      ##replace public_subnet param
      public_subnet=$public_subnet'\'$public_short_subnet_mask
      sed -i 's/^.*public_subnet:.*$/  public_subnet:'" $public_subnet"'/' opnfv_ksgen_settings.yml
      ##replace private_subnet param
      private_subnet=$private_subnet'\'$private_short_subnet_mask
      sed -i 's/^.*private_subnet:.*$/  private_subnet:'" $private_subnet"'/' opnfv_ksgen_settings.yml

      ##replace public_dns param to be foreman server
      sed -i 's/^.*public_dns:.*$/  public_dns: '${interface_ip_arr[2]}'/' opnfv_ksgen_settings.yml

      ##replace public_gateway
      if [ -z "$public_gateway" ]; then
        ##if unset then we assume its the first IP in the public subnet
        public_subnet=$(find_subnet $next_public_ip $public_subnet_mask)
        public_gateway=$(increment_subnet $public_subnet 1)
      fi
      sed -i 's/^.*public_gateway:.*$/  public_gateway:'" $public_gateway"'/' opnfv_ksgen_settings.yml

      ##we have to define an allocation range of the public subnet to give
      ##to neutron to use as floating IPs
      ##if static ip range, then we take the difference of the end range and current ip
      ## to be the allocation pool
      ##if not static ip, we will use the last 20 IP from the subnet
      ## note that this is not a really good idea because the subnet must be at least a /27 for this to work...
      public_subnet=$(find_subnet $next_public_ip $public_subnet_mask)
      if [ ! -z "$static_ip_range" ]; then
        begin_octet=$(echo $next_public_ip | cut -d . -f4)
        end_octet=$(echo $static_ip_range_end | cut -d . -f4)
        ip_diff=$((end_octet-begin_octet))
        if [ $ip_diff -le 0 ]; then
          echo "${red}ip range left for floating range is less than or equal to 0! $ipdiff ${reset}"
          exit 1
        else
          public_allocation_start=$(next_ip $next_public_ip)
          public_allocation_end=$static_ip_range_end
        fi
      else
        last_ip_subnet=$(find_last_ip_subnet $next_public_ip $public_subnet_mask)
        public_allocation_start=$(subtract_ip $last_ip_subnet $floating_ip_count )
        public_allocation_end=${last_ip_subnet}
      fi
      echo "${blue}Neutron Floating IP range: $public_allocation_start to $public_allocation_end ${reset}"

      sed -i 's/^.*public_allocation_start:.*$/  public_allocation_start:'" $public_allocation_start"'/' opnfv_ksgen_settings.yml
      sed -i 's/^.*public_allocation_end:.*$/  public_allocation_end:'" $public_allocation_end"'/' opnfv_ksgen_settings.yml

    else
      printf '%s\n' 'deploy.sh: Unknown network type: $deployment_type' >&2
      exit 1
    fi

    echo "${blue}Parameters Complete.  Settings have been set for Foreman. ${reset}"

  fi
}

##Configure bootstrap.sh to use the virtual Khaleesi playbook
##params: none
##usage: configure_virtual()
configure_virtual() {
  if [ $virtual ]; then
    echo "${blue} Virtual flag detected, setting Khaleesi playbook to be opnfv-vm.yml ${reset}"
    sed -i 's/opnfv.yml/opnfv-vm.yml/' bootstrap.sh
  fi
}

##Starts Foreman VM with Vagrant
##params: none
##usage: start_vagrant()
start_foreman() {
  echo "${blue}Starting Vagrant! ${reset}"

  ##stand up vagrant
  if ! vagrant up; then
    printf '%s\n' 'deploy.sh: Unable to complete Foreman VM install' >&2
    exit 1
  else
    echo "${blue}Foreman VM is up! ${reset}"
  fi
}

##start the VM if this is a virtual installation
##this function does nothing if baremetal servers are being used
##params: none
##usage: start_virtual_nodes()
start_virtual_nodes() {
  if [ $virtual ]; then

    ##Bring up VM nodes
    echo "${blue}Setting VMs up... ${reset}"
    nodes=`sed -nr '/nodes:/{:start /workaround/!{N;b start};//p}' opnfv_ksgen_settings.yml | sed -n '/^  [A-Za-z0-9]\+:$/p' | sed 's/\s*//g' | sed 's/://g'`
    ##due to ODL Helium bug of OVS connecting to ODL too early, we need controllers to install first
    ##this is fix kind of assumes more than I would like to, but for now it should be OK as we always have
    ##3 static controllers
    compute_nodes=`echo $nodes | tr " " "\n" | grep -v controller | tr "\n" " "`
    controller_nodes=`echo $nodes | tr " " "\n" | grep controller | tr "\n" " "`
    nodes=${controller_nodes}${compute_nodes}
    controller_count=0
    compute_wait_completed=false

    for node in ${nodes}; do
      cd /tmp/

      ##remove VM nodes incase it wasn't cleaned up
      rm -rf $vm_dir/$node
      rm -rf /tmp/genesis/

      ##clone genesis and move into node folder
      if ! GIT_SSL_NO_VERIFY=true git clone https://gerrit.opnfv.org/gerrit/genesis.git; then
        printf '%s\n' 'deploy.sh: Unable to clone vagrant repo' >&2
        exit 1
      fi

      mv -f /tmp/genesis/foreman/ci $vm_dir/$node
      rm -rf /tmp/genesis/

      cd $vm_dir/$node

      if [ $base_config ]; then
        if ! cp -f $base_config opnfv_ksgen_settings.yml; then
          echo "${red}ERROR: Unable to copy $base_config to opnfv_ksgen_settings.yml${reset}"
          exit 1
        fi
      fi

      ##parse yaml into variables
      eval $(parse_yaml opnfv_ksgen_settings.yml "config_")
      ##find node type
      node_type=config_nodes_${node}_type
      node_type=$(eval echo \$$node_type)

      ##trozet test make compute nodes wait 20 minutes
      if [ "$compute_wait_completed" = false ] && [ "$node_type" != "controller" ]; then
        echo "${blue}Waiting 20 minutes for Control nodes to install before continuing with Compute nodes..."
        compute_wait_completed=true
        sleep 1400
      fi

      ##find number of interfaces with ip and substitute in VagrantFile
      output=`ifconfig | grep -E "^[a-zA-Z0-9]+:"| grep -Ev "lo|tun|virbr|vboxnet" | awk '{print $1}' | sed 's/://'`

      if [ ! "$output" ]; then
        printf '%s\n' 'deploy.sh: Unable to detect interfaces to bridge to' >&2
        exit 1
      fi

      if_counter=0
      for interface in ${output}; do

        if [ -z "$enable_virtual_dhcp" ]; then
          if [ "$if_counter" -ge 1 ]; then
            break
          fi
        elif [ "$if_counter" -ge 4 ]; then
          break
        fi
        interface_ip=$(find_ip $interface)
        if [ ! "$interface_ip" ]; then
          continue
        fi
        case "${if_counter}" in
          0)
            mac_string=config_nodes_${node}_mac_address
            mac_addr=$(eval echo \$$mac_string)
            mac_addr=$(echo $mac_addr | sed 's/:\|-//g')
            if [ $mac_addr == "" ]; then
              echo "${red} Unable to find mac_address for $node! ${reset}"
              exit 1
            fi
            ;;
          1)
            if [ "$node_type" == "controller" ]; then
              mac_string=config_nodes_${node}_private_mac
              mac_addr=$(eval echo \$$mac_string)
              if [ $mac_addr == "" ]; then
                echo "${red} Unable to find private_mac for $node! ${reset}"
                exit 1
              fi
            else
              ##generate random mac
              mac_addr=$(echo -n 00-60-2F; dd bs=1 count=3 if=/dev/random 2>/dev/null |hexdump -v -e '/1 "-%02X"')
            fi
            mac_addr=$(echo $mac_addr | sed 's/:\|-//g')
            ;;
          *)
            mac_addr=$(echo -n 00-60-2F; dd bs=1 count=3 if=/dev/random 2>/dev/null |hexdump -v -e '/1 "-%02X"')
            mac_addr=$(echo $mac_addr | sed 's/:\|-//g')
            ;;
        esac
        this_admin_ip=${admin_ip_arr[$node]}
        sed -i 's/^.*eth_replace'"$if_counter"'.*$/  config.vm.network "private_network", virtualbox__intnet: "my_admin_network", ip: '\""$this_admin_ip"\"', netmask: '\""$admin_subnet_mask"\"', :mac => '\""$mac_addr"\"'/' Vagrantfile
        ((if_counter++))
      done
      ##now remove interface config in Vagrantfile for 1 node
      ##if 1, 3, or 4 interfaces set deployment type
      ##if 2 interfaces remove 2nd interface and set deployment type
      if [[ "$if_counter" == 1 || "$if_counter" == 2 ]]; then
        deployment_type="single_network"
        if [ "$node_type" == "controller" ]; then
            mac_string=config_nodes_${node}_private_mac
            mac_addr=$(eval echo \$$mac_string)
            if [ $mac_addr == "" ]; then
              echo "${red} Unable to find private_mac for $node! ${reset}"
              exit 1
            fi
        else
            ##generate random mac
            mac_addr=$(echo -n 00-60-2F; dd bs=1 count=3 if=/dev/random 2>/dev/null |hexdump -v -e '/1 "-%02X"')
        fi
        mac_addr=$(echo $mac_addr | sed 's/:\|-//g')
        if [ "$node_type" == "controller" ]; then
          new_node_ip=${controllers_ip_arr[$controller_count]}
          if [ ! "$new_node_ip" ]; then
            echo "{red}ERROR: Empty node ip for controller $controller_count ${reset}"
            exit 1
          fi
          ((controller_count++))
        else
          next_private_ip=$(next_ip $next_private_ip)
          if [ ! "$next_private_ip" ]; then
            echo "{red}ERROR: Could not find private ip for $node ${reset}"
            exit 1
          fi
          new_node_ip=$next_private_ip
        fi
        sed -i 's/^.*eth_replace1.*$/  config.vm.network "private_network", virtualbox__intnet: "my_private_network", :mac => '\""$mac_addr"\"', ip: '\""$new_node_ip"\"', netmask: '\""$private_subnet_mask"\"'/' Vagrantfile
        ##replace host_ip in vm_nodes_provision with private ip
        sed -i 's/^host_ip=REPLACE/host_ip='$new_node_ip'/' vm_nodes_provision.sh
        ##replace ping site
        if [ ! -z "$ping_site" ]; then
          sed -i 's/www.google.com/'$ping_site'/' vm_nodes_provision.sh
        fi
        ##find public ip info
        mac_addr=$(echo -n 00-60-2F; dd bs=1 count=3 if=/dev/random 2>/dev/null |hexdump -v -e '/1 "-%02X"')
        mac_addr=$(echo $mac_addr | sed 's/:\|-//g')
        this_public_ip=${public_ip_arr[$node]}

        if [ -z "$enable_virtual_dhcp" ]; then
          sed -i 's/^.*eth_replace2.*$/  config.vm.network "public_network", bridge: '\'"$public_interface"\'', :mac => '\""$mac_addr"\"', ip: '\""$this_public_ip"\"', netmask: '\""$public_subnet_mask"\"'/' Vagrantfile
        else
          sed -i 's/^.*eth_replace2.*$/  config.vm.network "public_network", bridge: '\'"$public_interface"\'', :mac => '\""$mac_addr"\"'/' Vagrantfile
        fi
        remove_vagrant_network eth_replace3
      elif [ "$if_counter" == 3 ]; then
        deployment_type="three_network"
        remove_vagrant_network eth_replace3
      else
        deployment_type="multi_network"
      fi
      ##modify provisioning to do puppet install, config, and foreman check-in
      ##substitute host_name and dns_server in the provisioning script
      host_string=config_nodes_${node}_hostname
      host_name=$(eval echo \$$host_string)
      sed -i 's/^host_name=REPLACE/host_name='$host_name'/' vm_nodes_provision.sh
      ##dns server should be the foreman server
      sed -i 's/^dns_server=REPLACE/dns_server='${interface_ip_arr[0]}'/' vm_nodes_provision.sh
      ## remove bootstrap and NAT provisioning
      sed -i '/nat_setup.sh/d' Vagrantfile
      sed -i 's/bootstrap.sh/vm_nodes_provision.sh/' Vagrantfile
      ## modify default_gw to be node_default_gw
      sed -i 's/^.*default_gw =.*$/  default_gw = '\""$node_default_gw"\"'/' Vagrantfile
      ## modify VM memory to be 4gig
      ##if node type is controller
      if [ "$node_type" == "controller" ]; then
        sed -i 's/^.*vb.memory =.*$/     vb.memory = 4096/' Vagrantfile
      fi
      echo "${blue}Starting Vagrant Node $node! ${reset}"
      ##stand up vagrant
      if ! vagrant up; then
        echo "${red} Unable to start $node ${reset}"
        exit 1
      else
        echo "${blue} $node VM is up! ${reset}"
      fi
    done
    echo "${blue} All VMs are UP! ${reset}"
    echo "${blue} Waiting for puppet to complete on the nodes... ${reset}"
    ##check puppet is complete
    ##ssh into foreman server, run check to verify puppet is complete
    pushd $vm_dir/foreman_vm
    if ! vagrant ssh -c "/opt/khaleesi/run.sh --no-logs --use /vagrant/opnfv_ksgen_settings.yml /opt/khaleesi/playbooks/validate_opnfv-vm.yml"; then
      echo "${red} Failed to validate puppet completion on nodes ${reset}"
      exit 1
    else
      echo "{$blue} Puppet complete on all nodes! ${reset}"
    fi
    popd
    ##add routes back to nodes
    for node in ${nodes}; do
      pushd $vm_dir/$node
      if ! vagrant ssh -c "route | grep default | grep $this_default_gw"; then
        echo "${blue} Adding public route back to $node! ${reset}"
        vagrant ssh -c "route add default gw $this_default_gw"
      fi
      popd
    done
    if [ ! -z "$horizon_public_vip" ]; then
      echo "${blue} Virtual deployment SUCCESS!! Foreman URL:  http://${foreman_ip}, Horizon URL: http://${horizon_public_vip} ${reset}"
    else
      echo "${blue} Virtual deployment SUCCESS!! Foreman URL:  http://${foreman_ip}, Horizon URL: http://${odl_control_ip} ${reset}"
    fi
  fi
}

##check to make sure nodes are powered off
##this function does nothing if virtual
##params: none
##usage: check_baremetal_nodes()
check_baremetal_nodes() {
  if [ $virtual ]; then
    echo "${blue}Skipping Baremetal node power status check as deployment is virtual ${reset}"
  else
    echo "${blue}Checking Baremetal nodes power state... ${reset}"
    if [ ! -z "$base_config" ]; then
      # Install ipmitool
      # Major version is pinned to force some consistency for Arno
      if ! yum list installed | grep -i ipmitool; then
        echo "${blue}Installing ipmitool...${reset}"
        if ! yum -y install ipmitool-1*; then
          echo "${red}Failed to install ipmitool!${reset}"
          exit 1
        fi
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
        ipmi_output=`ipmitool -I lanplus -P ${bmc_pass[$mynode]} -U ${bmc_user[$mynode]} -H ${bmc_ip[$mynode]} chassis status \
                    | grep "System Power" | cut -d ':' -f2 | tr -d [:blank:]`
        if [ "$ipmi_output" == "on" ]; then
          echo "${red}Error: Node is powered on: ${bmc_ip[$mynode]} ${reset}"
          echo "${red}Please run clean.sh before running deploy! ${reset}"
          exit 1
        elif [ "$ipmi_output" == "off" ]; then
          echo "${blue}Node: ${bmc_ip[$mynode]} is powered off${reset}"
        else
          echo "${red}Warning: Unable to detect node power state: ${bmc_ip[$mynode]} ${reset}"
        fi
      done
    else
      echo "${red}base_config was not provided for a baremetal install! Exiting${reset}"
      exit 1
    fi
  fi
}

##END FUNCTIONS

main() {
  parse_cmdline "$@"
  disable_selinux
  check_baremetal_nodes
  install_EPEL
  install_vbox
  install_ansible
  install_vagrant
  clean_tmp
  verify_vm_dir
  clone_bgs
  configure_network
  configure_virtual
  start_foreman
  start_virtual_nodes
}

main "$@"
