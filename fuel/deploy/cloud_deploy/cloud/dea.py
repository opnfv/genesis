import yaml
import io

class DeploymentEnvironmentAdapter(object):
    def __init__(self):
        self.dea_struct = None
        self.blade_ids_per_shelves = {}
        self.blades_per_shelves = {}
        self.shelf_ids = []
        self.info_per_shelves = {}
        self.network_names = []

    def parse_yaml(self, yaml_path):
        with io.open(yaml_path) as yaml_file:
            self.dea_struct = yaml.load(yaml_file)
        self.collect_shelf_and_blade_info()
        self.collect_shelf_info()
        self.collect_network_names()

    def get_no_of_blades(self):
        no_of_blades = 0
        for shelf in self.dea_struct['shelf']:
            no_of_blades += len(shelf['blade'])
        return no_of_blades

    def collect_shelf_info(self):
        self.info_per_shelves = {}
        for shelf in self.dea_struct['shelf']:
            self.info_per_shelves[shelf['id']] = shelf

    def get_shelf_info(self, shelf):
        return (self.info_per_shelves[shelf]['type'],
                self.info_per_shelves[shelf]['mgmt_ip'],
                self.info_per_shelves[shelf]['username'],
                self.info_per_shelves[shelf]['password'])

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

    def has_role(self, role, shelf, blade):
        blade = self.blades_per_shelves[shelf][blade]
        if role == 'compute':
            return True if 'roles' not in blade else False
        return (True if 'roles' in blade and role in blade['roles']
                else False)

    def collect_network_names(self):
        self.network_names = []
        for network in self.dea_struct['networks']['networks']:
            self.network_names.append(network['name'])

    def get_networks(self):
        return self.dea_struct['networks']

    def get_network_names(self):
        return self.network_names

    def get_settings(self):
        return self.dea_struct['settings']

    def get_network_scheme(self, node_type):
        return self.dea_struct[node_type]

    def get_interfaces(self):
        return self.dea_struct['interfaces']