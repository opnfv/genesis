import subprocess
import sys
import time
import os
from dha import DeploymentHardwareAdapter
from dea import DeploymentEnvironmentAdapter

SUPPORTED_RELEASE = 'Juno on CentOS 6.5'
N = {'id': 0, 'status': 1, 'name': 2, 'cluster': 3, 'ip': 4, 'mac': 5,
     'roles': 6, 'pending_roles': 7, 'online': 8}
E = {'id': 0, 'status': 1, 'name': 2, 'mode': 3, 'release_id': 4,
     'changes': 5, 'pending_release_id': 6}
R = {'id': 0, 'name': 1, 'state': 2, 'operating_system': 3, 'version': 4}
RO = {'name': 0, 'conflicts': 1}

def exec_cmd(cmd):
    process = subprocess.Popen(cmd,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT,
                               shell=True)
    return process.communicate()[0]

def parse(printout):
   parsed_list = []
   lines = printout.splitlines()
   for l in lines[2:]:
        parsed = [e.strip() for e in l.split('|')]
        parsed_list.append(parsed)
   return parsed_list

def err(error_message):
    sys.stderr.write(error_message)
    sys.exit(1)



class Deploy(object):

    def __init__(self):
        self.supported_release = None

    def get_id_list(self, list):
        return [l[0] for l in list]

    def cleanup_fuel_environments(self, env_list):
        WAIT_LOOP = 10
        SLEEP_TIME = 2
        id_list = self.get_id_list(env_list)
        for id in id_list:
            exec_cmd('fuel env --env %s --delete' % id)
            for i in range(WAIT_LOOP):
                if id in self.get_id_list(parse(exec_cmd('fuel env list'))):
                    time.sleep(SLEEP_TIME)
                else:
                    continue

    def cleanup_fuel_nodes(self, node_list):
        for node in node_list:
            if node[N['status']] == 'discover':
                exec_cmd('fuel node --node-id %s --delete-from-db'
                         % node[N['id']])
                exec_cmd('dockerctl shell cobbler cobbler system remove '
                         '--name node-%s' % node[N['id']])

    def check_previous_installation(self):
        env_list = parse(exec_cmd('fuel env list'))
        if env_list:
            self.cleanup_fuel_environments(env_list)
        node_list = parse(exec_cmd('fuel node list'))
        if node_list:
            self.cleanup_fuel_nodes(node_list)

    def check_supported_release(self):
        release_list= parse(exec_cmd('fuel release -l'))
        for release in release_list:
            if release[R['name']] == SUPPORTED_RELEASE:
                self.supported_release = release
                break
        if not self.supported_release:
            err("This Fuel doesn't contain the following "
                "release: %s\n" % SUPPORTED_RELEASE)

    def check_role_definitions(self):
        role_list= parse(exec_cmd('fuel role --release %s'
                                  % self.supported_release[R['id']]))
        roles = [role[RO['name']] for role in role_list]
        if 'compute' not in roles:
            err("Role compute does not exist in release %"
                % self.supported_release[R['name']])
        if 'controller' not in roles:
            err("Role controller does not exist in release %"
                % self.supported_release[R['name']])

    def check_prerequisites(self):
        self.check_supported_release()
        self.check_role_definitions()
        self.check_previous_installation()

    def count_discovered_nodes(self, node_list):
        discovered_nodes = 0
        for node in node_list:
            if node[N['status']] == 'discover':
                discovered_nodes += 1
        return discovered_nodes

    def wait_for_discovered_blades(self, no_of_blades):
        WAIT_LOOP = 10
        SLEEP_TIME = 2
        all_discovered = False
        node_list = parse(exec_cmd('fuel node list'))
        for i in range(WAIT_LOOP):
            if (self.count_discovered_nodes(node_list) < no_of_blades):
                time.sleep(SLEEP_TIME)
                node_list = parse(exec_cmd('fuel node list'))
            else:
                all_discovered = True
                break
        if not all_discovered:
            err("There are %s blades defined, but not all of "
                "them have been discovered\n" % no_of_blades)

    def assign_cluster_node_ids(self, dha, dea, controllers, compute_hosts):
        node_list= parse(exec_cmd('fuel node list'))
        for shelf_id in dea.get_shelf_ids():
            for blade_id in dea.get_blade_ids(shelf_id):
                blade_mac_list = dha.get_blade_mac_addresses(
                    shelf_id, blade_id)

                found = False
                for node in node_list:
                    if (node[N['mac']] in blade_mac_list and
                        node[N['status']] == 'discover'):
                        found = True
                        break
                if found:
                    if dea.is_controller(shelf_id, blade_id):
                        controllers.append(node[N['id']])
                    if dea.is_compute_host(shelf_id, blade_id):
                        compute_hosts.append(node[N['id']])
                else:
                    err("Could not find the Node ID for blade "
                        "with MACs %s or blade is not in "
                        "discover status\n" % blade_mac_list)

    def env_exists(self, env_name):
        env_list = parse(exec_cmd('fuel env --list'))
        for env in env_list:
            if env[E['name']] == env_name and env[E['status']] == 'new':
                return True
        return False

    def configure_environment(self, dea):
        env_name = dea.get_environment_name()
        exec_cmd('fuel env -c --name %s --release %s --mode ha --net neutron '
                 '--nst vlan' % (env_name, self.supported_release[R['id']]))

        if not self.env_exists(env_name):
            err("Failed to create environment %s" % env_name)



def main():

    yaml_path = exec_cmd('pwd').strip() + '/dea.yaml'
    deploy = Deploy()

    dea = DeploymentEnvironmentAdapter()

    if not os.path.isfile(yaml_path):
        sys.stderr.write("ERROR: File %s not found\n" % yaml_path)
        sys.exit(1)

    dea.parse_yaml(yaml_path)

    dha = DeploymentHardwareAdapter(dea.get_server_type())

    deploy.check_prerequisites()

    dha.power_off_blades()

    dha.configure_networking()

    dha.reset_to_factory_defaults()

    dha.set_boot_order()

    dha.power_on_blades()

    dha.get_blade_mac_addresses()

    deploy.wait_for_discovered_blades(dea.get_no_of_blades())

    controllers = []
    compute_hosts = []
    deploy.assign_cluster_node_ids(dha, dea, controllers, compute_hosts)

    deploy.configure_environment(dea)



if __name__ == '__main__':
    main()