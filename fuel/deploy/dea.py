import yaml
import io

class DeploymentEnvironmentAdapter(object):
    def __init__(self):
        self.dea_struct = None
        self.blade_ids_per_shelves = {}
        self.blades_per_shelves = {}
        self.shelf_ids = []
        self.networks = {}

    def parse_yaml(self, yaml_path):
        with io.open(yaml_path) as yaml_file:
            self.dea_struct = yaml.load(yaml_file)
        self.collect_shelf_and_blade_info()
        self.collect_network_info()

    def get_no_of_blades(self):
        no_of_blades = 0
        for shelf in self.dea_struct['shelf']:
            no_of_blades += len(shelf['blade'])
        return no_of_blades

    def get_server_type(self):
        return self.dea_struct['server']['type']

    def get_server_info(self):
        return (self.dea_struct['server']['type'],
                self.dea_struct['server']['mgmt_ip'],
                self.dea_struct['server']['username'],
                self.dea_struct['server']['password'])

    def get_environment_name(self):
        return self.dea_struct['name']

    def get_shelf_ids(self):
        return self.shelf_ids

    def get_blade_ids_per_shelf(self, shelf_id):
        return self.blade_ids_per_shelves[shelf_id]

    def get_blade_ids_per_shelves(self):
        return self.blade_ids_per_shelves

    def collect_shelf_and_blade_info(self):
        self.blade_ids_per_shelves = {}
        self.blades_per_shelves = {}
        self.shelf_ids = []
        for shelf in self.dea_struct['shelf']:
             self.shelf_ids.append(shelf['id'])
             blade_ids = self.blade_ids_per_shelves[shelf['id']] = []
             blades = self.blades_per_shelves[shelf['id']] = {}
             for blade in shelf['blade']:
                 blade_ids.append(blade['id'])
                 blades[blade['id']] = blade

    def is_controller(self, shelf_id, blade_id):
        blade = self.blades[shelf_id][blade_id]
        return (True if 'role' in blade and blade['role'] == 'controller'
                else False)

    def is_compute_host(self, shelf_id, blade_id):
        blade = self.blades[shelf_id][blade_id]
        return True if 'role' not in blade else False

    def collect_network_info(self):
        self.networks = {}
        for network in self.dea_struct['network']:
            self.networks[network['name']] = network

    def get_networks(self):
        return self.networks