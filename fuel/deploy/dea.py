import yaml

class DeploymentEnvironmentAdapter(object):
    def __init__(self):
        self.dea_struct = None
        self.blade_ids = {}
        self.blades = {}
        self.shelf_ids = []

    def parse_yaml(self, yaml_path):
        with open(yaml_path) as yaml_file:
            self.dea_struct = yaml.load(yaml_file)
        self.collect_shelf_and_blade_info()

    def get_no_of_blades(self):
        no_of_blades = 0
        for shelf in self.dea_struct['shelf']:
            no_of_blades += len(shelf['blade'])
        return no_of_blades

    def get_server_type(self):
        return self.dea_struct['server_type']

    def get_environment_name(self):
        return self.dea_struct['name']

    def get_shelf_ids(self):
        return self.shelf_ids

    def get_blade_ids(self, shelf_id):
        return self.blade_ids[shelf_id]

    def collect_shelf_and_blade_info(self):
        self.blade_ids = {}
        self.blades = {}
        self.shelf_ids = []
        for shelf in self.dea_struct['shelf']:
             self.shelf_ids.append(shelf['id'])
             blade_ids = self.blade_ids[shelf['id']] = []
             blades = self.blades[shelf['id']] = {}
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