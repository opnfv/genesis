import common
import os
import shutil
import yaml


from configure_settings import ConfigureSettings
from configure_network import ConfigureNetwork

N = common.N
E = common.E
R = common.R
RO = common.RO
exec_cmd = common.exec_cmd
parse = common.parse
err = common.err

class ConfigureEnvironment(object):

    def __init__(self, dea, yaml_config_dir):
        self.env_id = None
        self.dea = dea
        self.yaml_config_dir = yaml_config_dir
        self.env_name = dea.get_environment_name()

    def env_exists(self, env_name):
        env_list = parse(exec_cmd('fuel env --list'))
        for env in env_list:
            if env[E['name']] == env_name and env[E['status']] == 'new':
                return True
        return False

    def get_env_id(self, env_name):
        env_list = parse(exec_cmd('fuel env --list'))
        for env in env_list:
            if env[E['name']] == env_name:
                return env[E['id']]

    def configure_environment(self, dea):
        exec_cmd('fuel env -c --name %s --release %s --mode ha --net neutron '
                 '--nst vlan' % (self.env_name,
                                 self.supported_release[R['id']]))

        self.env_id = self.get_env_id(self.env_name)
        if not self.env_exists(self.env_name):
            err("Failed to create environment %s" % self.env_name)

        self.config_settings()
        self.config_network()

    def config_settings(self):
        if os.path.exists(self.yaml_config_dir):
            shutil.rmtree(self.yaml_config_dir)
        os.makedirs(self.yaml_config_dir)

        settings = ConfigureSettings(self.yaml_config_dir, self.env_id)
        settings.config_settings()


    def config_network(self):
        network_yaml=self.yaml_config_dir + '/network_%s.yaml' % self.env_id
        os.remove(network_yaml)

        network = ConfigureNetwork(self.yaml_config_dir, network_yaml,
                                   self.env_id, self.dea)
        network.config_network()




