import common
import os
import yaml
import io
import re

N = common.N
E = common.E
R = common.R
RO = common.RO
exec_cmd = common.exec_cmd
parse = common.parse
err = common.err

P1 = re.compile('!\s.*')

class ConfigureNetwork(object):

    def __init__(self, yaml_config_dir, network_yaml, env_id, dea):
        self.yaml_config_dir = yaml_config_dir
        self.network_yaml = network_yaml
        self.env_id = env_id
        self.dea = dea

    def download_settings(self):
        exec_cmd('fuel network --env %s --download --dir %s'
                 % (self.env_id, self.yaml_config_dir))

    def upload_settings(self):
        exec_cmd('fuel network --env %s --upload --dir %s'
                 % (self.env_id, self.yaml_config_dir))

    def config_network(self):

        self.download_settings()

        self.apply_network_config()

        self.upload_settings()

        self.verify()

    def apply_network_config(self):

        with io.open(self.network_yaml) as stream:
            network_config = yaml.load(stream)
        networks = network_config['networks']

        net = self.dea.get_networks()
        net['fuelweb_admin'] = net['management']
        if 'vlan' in net['fuelweb_admin']:
            del net['fuelweb_admin']['vlan']
        del net['management']
        net_names = [n for n in net.iterkeys()]

        for i in range(len(networks)):
            if networks[i]['name'] == 'management':
                networks = networks[:i] + networks[i+1:]
                network_config['networks'] = networks
                break

        for network in networks:
            name = network['name']
            if name in net_names:
                if ('vlan' in net[name] and net[name]['vlan'] is not None):
                    network['vlan_start'] = net[name]['vlan']
                network['cidr'] = net[name]['cidr']
                network['ip_ranges'][0][0] = net[name]['start']
                network['ip_ranges'][0][1] = net[name]['end']

        with io.open(self.network_yaml, 'w') as stream:
            yaml.dump(network_config, stream, default_flow_style=False)

    def verify(self):
        ret = exec_cmd('mktemp -d')
        temp_dir = ret.splitlines()[0]

        exec_cmd('fuel network --env %s --download --dir %s'
                 % (self.env_id, temp_dir))

        ret = exec_cmd('diff -C0 %s %s'
                       % (self.network_yaml,
                          temp_dir + '/network_%s.yaml' % self.env_id))
        diff_list = []
        for l in ret.splitlines():
            m = P1.match(l)
            if m and '_vip' not in l:
                diff_list.append(l)
        if diff_list:
            err('Uploaded network yaml rejected by Fuel\n')
            