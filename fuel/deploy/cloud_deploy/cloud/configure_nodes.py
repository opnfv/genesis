import common
import yaml
import io
import glob

N = common.N
E = common.E
R = common.R
RO = common.RO
exec_cmd = common.exec_cmd
parse = common.parse
err = common.err
check_file_exists = common.check_file_exists
LOG = common.LOG


class ConfigureNodes(object):

    def __init__(self, yaml_config_dir, env_id, node_id_roles_dict, dea):
        self.yaml_config_dir = yaml_config_dir
        self.env_id = env_id
        self.node_id_roles_dict = node_id_roles_dict
        self.dea = dea

    def config_nodes(self):
        LOG.debug('Configure nodes\n')
        for node_id, roles_shelf_blade in self.node_id_roles_dict.iteritems():
            exec_cmd('fuel node set --node-id %s --role %s --env %s'
                     % (node_id, ','.join(roles_shelf_blade[0]), self.env_id))

        self.download_deployment_config()
        self.modify_node_network_schemes()
        self.upload_deployment_config()

        for node_id, roles_shelf_blade in self.node_id_roles_dict.iteritems():
            self.download_interface_config(node_id)
            self.modify_node_interface(node_id)
            self.upload_interface_config(node_id)

    def modify_node_network_schemes(self):
        LOG.debug('Modify node network schemes in environment %s\n' % self.env_id)
        for node_file in glob.glob('%s/deployment_%s/*.yaml'
                                   % (self.yaml_config_dir, self.env_id)):
             check_file_exists(node_file)

             if 'compute' in node_file:
                 node_type = 'compute'
             else:
                 node_type = 'controller'

             network_scheme = self.dea.get_network_scheme(node_type)

             with io.open(node_file) as stream:
                 node = yaml.load(stream)

             node['network_scheme']['transformations'] = network_scheme

             with io.open(node_file, 'w') as stream:
                 yaml.dump(node, stream, default_flow_style=False)


    def download_deployment_config(self):
        LOG.debug('Download deployment config for environment %s\n' % self.env_id)
        r, c = exec_cmd('fuel deployment --env %s --default --dir %s'
                        % (self.env_id, self.yaml_config_dir))

    def upload_deployment_config(self):
        LOG.debug('Upload deployment config for environment %s\n' % self.env_id)
        r, c = exec_cmd('fuel deployment --env %s --upload --dir %s'
                        % (self.env_id, self.yaml_config_dir))

    def download_interface_config(self, node_id):
        LOG.debug('Download interface config for node %s\n' % node_id)
        r, c = exec_cmd('fuel node --env %s --node %s --network --download '
                        '--dir %s' % (self.env_id, node_id,
                                      self.yaml_config_dir))

    def upload_interface_config(self, node_id):
        LOG.debug('Upload interface config for node %s\n' % node_id)
        r, c = exec_cmd('fuel node --env %s --node %s --network --upload '
                        '--dir %s' % (self.env_id, node_id,
                                      self.yaml_config_dir))

    def modify_node_interface(self, node_id):
        LOG.debug('Modify interface config for node %s\n' % node_id)
        interface_yaml = (self.yaml_config_dir + '/node_%s/interfaces.yaml'
                          % node_id)

        with io.open(interface_yaml) as stream:
            interfaces = yaml.load(stream)

        net_name_id = {}
        for interface in interfaces:
            for network in interface['assigned_networks']:
                 net_name_id[network['name']] = network['id']

        interface_config = self.dea.get_interfaces()

        for interface in interfaces:
            interface['assigned_networks'] = []
            for net_name in interface_config[interface['name']]:
                net = {}
                net['id'] = net_name_id[net_name]
                net['name'] = net_name
                interface['assigned_networks'].append(net)

        with io.open(interface_yaml, 'w') as stream:
            yaml.dump(interfaces, stream, default_flow_style=False)