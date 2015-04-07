#!/bin/bash
# Deploy in deployFuel has the "configure host-network,
# install fuel, configure vm and start it" meaning
set -o xtrace
set -o errexit
set -o nounset
set -o pipefail

if [ $# -ne 2 ]; then
    echo "Usage: $0 <iso-file> <interface>"
    exit 1
fi

readonly iso_file=$1
readonly interface=$2
readonly vm_name="fuel_opnfv"
readonly ssh_fuel_vm="sshpass -p r00tme
                          ssh -o UserKnownHostsFile=/dev/null
                              -o StrictHostKeyChecking=no
                              -q
                              root@192.168.0.11"
readonly RUN_INSTALL="${RUN_INSTALL:-false}"
readonly DEV="${DEV:-false}"

# poll is not real timeout, commands can take some undefined time to execute
# it is a count of how many times to try while sleeping shortly
# in between checks
readonly poll_virtinstall=1800
readonly poll_fuel_startup=1200
readonly poll_deployment=2150
readonly fuel_logfile="/var/log/puppet/bootstrap_admin_node.log"

cat >$interface.xml <<EOF
<network>
  <name>$interface</name>
  <forward dev='$interface' mode='bridge'>
    <interface dev='$interface'/>
  </forward>
</network>
EOF

cleanup_previous_run() {
    echo "Cleaning up previous run"
    set +eu
    virsh net-destroy $interface > /dev/null 2>&1
    virsh net-undefine $interface > /dev/null 2>&1
    virsh destroy $vm_name > /dev/null 2>&1
    virsh undefine $vm_name > /dev/null 2>&1
    set -eu
}

create_disk_and_install() {
    rm -rf $vm_name.qcow2
    qemu-img create -f qcow2 -o preallocation=metadata $vm_name.qcow2 60G
    virt-install --connect=qemu:///system \
        --name=$vm_name \
        --network=network:$interface \
        --ram 2048 --vcpus=4,cores=2 --check-cpu --hvm \
        --disk path=$vm_name.qcow2,format=qcow2,device=disk,bus=virtio \
        --noautoconsole --vnc \
        --cdrom $iso_file
}

wait_for_virtinstall() {
    # Workaround for virt-install --wait which restarts vm
    # too fast too attach disk
    echo "Waiting for virt-install to finish..."
    set +eu
    stopped=false
    for i in $(seq 0 $poll_virtinstall); do
        virsh_out=`virsh list | grep "$vm_name"`
        if [ -z "$virsh_out" ]; then
            stopped=true
            break
        fi
        sleep 2
    done
    set -eu
}

wait_for_fuel_startup() {
    echo "Wait for fuel to start up..."
    for i in $(seq 0 $poll_fuel_startup); do
        sleep 2 && echo -n "$i "
        $ssh_fuel_vm grep complete $fuel_logfile &&
            echo "Fuel bootstrap is done, deployment should have started now" &&
            return 0
    done
    return 1
}


cleanup_previous_run
virsh net-define $interface.xml
virsh net-start $interface
create_disk_and_install
wait_for_virtinstall

echo "Starting $vm_name after installation in 6s..." && sleep 6s
set +eu

virsh start $vm_name
if ! wait_for_fuel_startup; then
    echo "Fuel failed to start up"
    exit 1
fi
