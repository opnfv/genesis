import time
import yaml
import io
import sys

import common
from dea import DeploymentEnvironmentAdapter
from configure_environment import ConfigureEnvironment
from deployment import Deployment

YAML_CONF_DIR = '/var/lib/opnfv'

N = common.N
E = common.E
R = common.R
RO = common.RO
exec_cmd = common.exec_cmd
parse = common.parse
err = common.err
check_file_exists = common.check_file_exists
log = common.log
commafy = common.commafy
ArgParser = common.ArgParser

class Deploy(object):

    def __init__(self, dea_file, macs_file):
        self.dea = DeploymentEnvironmentAdapter(dea_file)
        self.macs_file = macs_file
        self.macs_per_blade = {}
        self.blades = self.dea.get_node_ids()
        self.node_ids_dict = {}
        self.node_id_roles_dict = {}
        self.supported_release = None
        self.env_id = None
        self.wanted_release = self.dea.get_wanted_release()

    def cleanup_fuel_environments(self, env_list):
        WAIT_LOOP = 60
        SLEEP_TIME = 10
        for env in env_list:
            log('Deleting environment %s' % env[E['id']])
            exec_cmd('fuel env --env %s --delete' % env[E['id']])
        all_env_erased = False
        for i in range(WAIT_LOOP):
            env_list = parse(exec_cmd('fuel env list'))
            if env_list:
               time.sleep(SLEEP_TIME)
            else:
               all_env_erased = True
               break
        if not all_env_erased:
            err('Could not erase these environments %s'
                % [(env[E['id']], env[E['status']]) for env in env_list])

    def cleanup_fuel_nodes(self, node_list):
        for node in node_list:
            if node[N['status']] == 'discover':
                log('Deleting node %s' % node[N['id']])
                exec_cmd('fuel node --node-id %s --delete-from-db'
                         % node[N['id']])
                exec_cmd('cobbler system remove --name node-%s'
                         % node[N['id']], False)

    def check_previous_installation(self):
        log('Check previous installation')
        env_list = parse(exec_cmd('fuel env list'))
        if env_list:
            self.cleanup_fuel_environments(env_list)
            node_list = parse(exec_cmd('fuel node list'))
            if node_list:
                self.cleanup_fuel_nodes(node_list)

    def check_supported_release(self):
        log('Check supported release: %s' % self.wanted_release)
        release_list = parse(exec_cmd('fuel release -l'))
        for release in release_list:
            if release[R['name']] == self.wanted_release:
                self.supported_release = release
                break
        if not self.supported_release:
            err('This Fuel does not contain the following release: %s'
                % self.wanted_release)

    def check_prerequisites(self):
        log('Check prerequisites')
        self.check_supported_release()
        self.check_previous_installation()

    def get_mac_addresses(self):
        with io.open(self.macs_file, 'r') as stream:
            self.macs_per_blade = yaml.load(stream)

    def find_mac_in_dict(self, mac):
        for blade, mac_list in self.macs_per_blade.iteritems():
            if mac in mac_list:
                return blade

    def all_blades_discovered(self):
        for blade, node_id in self.node_ids_dict.iteritems():
            if not node_id:
                return False
        return True

    def not_discovered_blades_summary(self):
        summary = ''
        for blade, node_id in self.node_ids_dict.iteritems():
            if not node_id:
                summary += '\n[blade %s]' % blade
        return summary

    def node_discovery(self, node_list, discovered_macs):
        for node in node_list:
            if (node[N['status']] == 'discover' and
                node[N['online']] == 'True' and
                node[N['mac']] not in discovered_macs):
                discovered_macs.append(node[N['mac']])
                blade = self.find_mac_in_dict(node[N['mac']])
                if blade:
                    log('Blade %s discovered as Node %s with MAC %s'
                        % (blade, node[N['id']], node[N['mac']]))
                    self.node_ids_dict[blade] = node[N['id']]

    def discovery_waiting_loop(self, discovered_macs):
        WAIT_LOOP = 320
        SLEEP_TIME = 10
        all_discovered = False
        for i in range(WAIT_LOOP):
            node_list = parse(exec_cmd('fuel node list'))
            if node_list:
                self.node_discovery(node_list, discovered_macs)
            if self.all_blades_discovered():
                all_discovered = True
                break
            else:
                time.sleep(SLEEP_TIME)
        return all_discovered

    def wait_for_discovered_blades(self):
        log('Wait for discovered blades')
        discovered_macs = []
        for blade in self.blades:
            self.node_ids_dict[blade] = None
        all_discovered = self.discovery_waiting_loop(discovered_macs)
        if not all_discovered:
            err('Not all blades have been discovered: %s'
                % self.not_discovered_blades_summary())

    def assign_roles_to_cluster_node_ids(self):
        self.node_id_roles_dict = {}
        for blade, node_id in self.node_ids_dict.iteritems():
            roles = commafy(self.dea.get_node_role(blade))
            self.node_id_roles_dict[node_id] = (roles, blade)

    def configure_environment(self):
        config_env = ConfigureEnvironment(self.dea, YAML_CONF_DIR,
                                          self.supported_release[R['id']],
                                          self.node_id_roles_dict)
        config_env.configure_environment()
        self.env_id = config_env.env_id

    def deploy_cloud(self):
        dep = Deployment(self.dea, YAML_CONF_DIR, self.env_id,
                         self.node_id_roles_dict)
        dep.deploy()

    def deploy(self):
        self.get_mac_addresses()
        self.check_prerequisites()
        self.wait_for_discovered_blades()
        self.assign_roles_to_cluster_node_ids()
        self.configure_environment()
        self.deploy_cloud()

def parse_arguments():
    parser = ArgParser(prog='python %s' % __file__)
    parser.add_argument('dea_file', action='store',
                        help='Deployment Environment Adapter: dea.yaml')
    parser.add_argument('macs_file', action='store',
                        help='Blade MAC addresses: macs.yaml')
    args = parser.parse_args()
    check_file_exists(args.dea_file)
    check_file_exists(args.macs_file)
    return (args.dea_file, args.macs_file)

def main():

    dea_file, macs_file = parse_arguments()

    deploy = Deploy(dea_file, macs_file)
    deploy.deploy()

if __name__ == '__main__':
    main()