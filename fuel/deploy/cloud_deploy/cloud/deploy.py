import time
import yaml
import io
import os

import common
from dea import DeploymentEnvironmentAdapter
from configure_environment import ConfigureEnvironment
from deployment import Deployment

SUPPORTED_RELEASE = 'Juno on CentOS 6.5'

N = common.N
E = common.E
R = common.R
RO = common.RO
exec_cmd = common.exec_cmd
parse = common.parse
err = common.err
check_file_exists = common.check_file_exists
LOG = common.LOG

class Deploy(object):

    def __init__(self, yaml_config_dir):
        self.supported_release = None
        self.yaml_config_dir = yaml_config_dir
        self.macs_per_shelf_dict = {}
        self.node_ids_dict = {}
        self.node_id_roles_dict = {}
        self.env_id = None
        self.shelf_blades_dict = {}

    def cleanup_fuel_environments(self, env_list):
        WAIT_LOOP = 60
        SLEEP_TIME = 10
        for env in env_list:
            LOG.debug('Deleting environment %s\n' % env[E['id']])
            exec_cmd('fuel env --env %s --delete' % env[E['id']])
        all_env_erased = False
        for i in range(WAIT_LOOP):
            env_list = parse(exec_cmd('fuel env list'))
            if env_list[0][0]:
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
                LOG.debug('Deleting node %s\n' % node[N['id']])
                exec_cmd('fuel node --node-id %s --delete-from-db'
                         % node[N['id']])
                exec_cmd('cobbler system remove --name node-%s'
                         % node[N['id']])

    def check_previous_installation(self):
        LOG.debug('Check previous installation\n')
        env_list = parse(exec_cmd('fuel env list'))
        if env_list[0][0]:
            self.cleanup_fuel_environments(env_list)
            node_list = parse(exec_cmd('fuel node list'))
            if node_list[0][0]:
                self.cleanup_fuel_nodes(node_list)

    def check_supported_release(self):
        LOG.debug('Check supported release: %s\n' % SUPPORTED_RELEASE)
        release_list = parse(exec_cmd('fuel release -l'))
        for release in release_list:
            if release[R['name']] == SUPPORTED_RELEASE:
                self.supported_release = release
                break
        if not self.supported_release:
            err('This Fuel does not contain the following '
                'release: %s\n' % SUPPORTED_RELEASE)

    def check_prerequisites(self):
        LOG.debug('Check prerequisites\n')
        self.check_supported_release()
        self.check_previous_installation()

    def find_mac_in_dict(self, mac):
        for shelf, blade_dict in self.macs_per_shelf_dict.iteritems():
            for blade, mac_list in blade_dict.iteritems():
                if mac in mac_list:
                    return shelf, blade

    def all_blades_discovered(self):
        for shelf, blade_dict in self.node_ids_dict.iteritems():
            for blade, node_id in blade_dict.iteritems():
                if not node_id:
                    return False
        return True

    def not_discovered_blades_summary(self):
        summary = ''
        for shelf, blade_dict in self.node_ids_dict.iteritems():
            for blade, node_id in blade_dict.iteritems():
                if not node_id:
                    summary += '[shelf %s, blade %s]\n' % (shelf, blade)
        return summary

    def collect_blade_ids_per_shelves(self, dea):
        self.shelf_blades_dict = dea.get_blade_ids_per_shelves()

    def node_discovery(self, node_list, discovered_macs):
        for node in node_list:
            if (node[N['status']] == 'discover' and
                node[N['online']] == 'True' and
                node[N['mac']] not in discovered_macs):
                discovered_macs.append(node[N['mac']])
                shelf_blade = self.find_mac_in_dict(node[N['mac']])
                if shelf_blade:
                    self.node_ids_dict[shelf_blade[0]][shelf_blade[1]] = \
                        node[N['id']]

    def discovery_waiting_loop(self, discovered_macs):
        WAIT_LOOP = 180
        SLEEP_TIME = 10
        all_discovered = False
        for i in range(WAIT_LOOP):
            node_list = parse(exec_cmd('fuel node list'))
            if node_list[0][0]:
                self.node_discovery(node_list, discovered_macs)
            if self.all_blades_discovered():
                all_discovered = True
                break
            else:
                time.sleep(SLEEP_TIME)
        return all_discovered

    def wait_for_discovered_blades(self):
        LOG.debug('Wait for discovered blades\n')
        discovered_macs = []
        for shelf, blade_list in self.shelf_blades_dict.iteritems():
            self.node_ids_dict[shelf] = {}
            for blade in blade_list:
                self.node_ids_dict[shelf][blade] = None
        all_discovered = self.discovery_waiting_loop(discovered_macs)
        if not all_discovered:
            err('Not all blades have been discovered: %s\n'
                % self.not_discovered_blades_summary())

    def get_mac_addresses(self, macs_yaml):
        with io.open(macs_yaml, 'r') as stream:
            self.macs_per_shelf_dict = yaml.load(stream)

    def assign_roles_to_cluster_node_ids(self, dea):
        self.node_id_roles_dict = {}
        for shelf, blades_dict in self.node_ids_dict.iteritems():
            for blade, node_id in blades_dict.iteritems():
                role_list = []
                if dea.has_role('controller', shelf, blade):
                    role_list.extend(['controller', 'mongo'])
                    if dea.has_role('cinder', shelf, blade):
                        role_list.extend(['cinder'])
                elif dea.has_role('compute', shelf, blade):
                    role_list.extend(['compute'])
                self.node_id_roles_dict[node_id] = (role_list, shelf, blade)

    def configure_environment(self, dea):
        config_env = ConfigureEnvironment(dea, self.yaml_config_dir,
                                          self.supported_release[R['id']],
                                          self.node_id_roles_dict)
        config_env.configure_environment()
        self.env_id = config_env.env_id

    def deploy(self, dea):
        dep = Deployment(dea, self.yaml_config_dir, self.env_id,
                         self.node_id_roles_dict)
        dep.deploy()


def main():

    base_dir = os.path.dirname(os.path.realpath(__file__))
    dea_yaml = base_dir + '/dea.yaml'
    check_file_exists(dea_yaml)
    macs_yaml = base_dir + '/macs.yaml'
    check_file_exists(macs_yaml)

    yaml_config_dir = '/var/lib/opnfv/pre_deploy'

    deploy = Deploy(yaml_config_dir)
    dea = DeploymentEnvironmentAdapter()
    dea.parse_yaml(dea_yaml)

    deploy.get_mac_addresses(macs_yaml)

    deploy.collect_blade_ids_per_shelves(dea)

    deploy.check_prerequisites()

    deploy.wait_for_discovered_blades()

    deploy.assign_roles_to_cluster_node_ids(dea)

    deploy.configure_environment(dea)

    deploy.deploy(dea)


if __name__ == '__main__':
    main()