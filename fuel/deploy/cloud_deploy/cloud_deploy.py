import os
import io
import yaml

from cloud import common
from cloud.dea import DeploymentEnvironmentAdapter
from hardware_adapters.dha import DeploymentHardwareAdapter
from ssh_client import SSHClient

exec_cmd = common.exec_cmd
err = common.err
check_file_exists = common.check_file_exists
LOG = common.LOG

class CloudDeploy(object):

    def __init__(self, fuel_ip, fuel_username, fuel_password):
        self.fuel_ip = fuel_ip
        self.fuel_username = fuel_username
        self.fuel_password = fuel_password
        self.shelf_blades_dict = {}
        self.macs_per_shelf_dict = {}

    def copy_to_fuel_master(self, dir_path=None, file_path=None, target='~'):
        if dir_path:
            path = '-r ' + dir_path
        elif file_path:
            path = file_path
        LOG.debug('Copying %s to Fuel Master %s' % (path, target))
        if path:
            exec_cmd('sshpass -p %s scp -o UserKnownHostsFile=/dev/null'
                     ' -o StrictHostKeyChecking=no -o ConnectTimeout=15'
                     ' %s %s@%s:%s'
                     % (self.fuel_password, path, self.fuel_username,
                        self.fuel_ip, target))

    def run_cloud_deploy(self, deploy_dir, deploy_app):
        LOG.debug('START CLOUD DEPLOYMENT')
        ssh = SSHClient(self.fuel_ip, self.fuel_username, self.fuel_password)
        ssh.open()
        ssh.run('python %s/%s' % (deploy_dir, deploy_app))
        ssh.close()

    def power_off_blades(self, dea):
        for shelf, blade_list in self.shelf_blades_dict.iteritems():
            type, mgmt_ip, username, password = dea.get_shelf_info(shelf)
            dha = DeploymentHardwareAdapter(type, mgmt_ip, username, password)
            dha.power_off_blades(shelf, blade_list)

    def power_on_blades(self, dea):
        for shelf, blade_list in self.shelf_blades_dict.iteritems():
            type, mgmt_ip, username, password = dea.get_shelf_info(shelf)
            dha = DeploymentHardwareAdapter(type, mgmt_ip, username, password)
            dha.power_on_blades(shelf, blade_list)

    def set_boot_order(self, dea):
        for shelf, blade_list in self.shelf_blades_dict.iteritems():
            type, mgmt_ip, username, password = dea.get_shelf_info(shelf)
            dha = DeploymentHardwareAdapter(type, mgmt_ip, username, password)
            dha.set_boot_order_blades(shelf, blade_list)

    def get_mac_addresses(self, dea, macs_yaml):
        self.macs_per_shelf_dict = {}
        for shelf, blade_list in self.shelf_blades_dict.iteritems():
            type, mgmt_ip, username, password = dea.get_shelf_info(shelf)
            dha = DeploymentHardwareAdapter(type, mgmt_ip, username, password)
            self.macs_per_shelf_dict[shelf] = dha.get_blades_mac_addresses(
                shelf, blade_list)

        with io.open(macs_yaml, 'w') as stream:
            yaml.dump(self.macs_per_shelf_dict, stream,
                      default_flow_style=False)

    def collect_blade_ids_per_shelves(self, dea):
        self.shelf_blades_dict = dea.get_blade_ids_per_shelves()



def main():

    fuel_ip = '10.20.0.2'
    fuel_username = 'root'
    fuel_password = 'r00tme'
    deploy_dir = '~/cloud'

    cloud = CloudDeploy(fuel_ip, fuel_username, fuel_password)

    base_dir = os.path.dirname(os.path.realpath(__file__))
    deployment_dir = base_dir + '/cloud'
    macs_yaml = base_dir + '/macs.yaml'
    dea_yaml = base_dir + '/dea.yaml'
    check_file_exists(dea_yaml)

    cloud.copy_to_fuel_master(dir_path=deployment_dir)
    cloud.copy_to_fuel_master(file_path=dea_yaml, target=deploy_dir)

    dea = DeploymentEnvironmentAdapter()
    dea.parse_yaml(dea_yaml)

    cloud.collect_blade_ids_per_shelves(dea)

    cloud.power_off_blades(dea)

    cloud.set_boot_order(dea)

    cloud.power_on_blades(dea)

    cloud.get_mac_addresses(dea, macs_yaml)
    check_file_exists(dea_yaml)

    cloud.copy_to_fuel_master(file_path=macs_yaml, target=deploy_dir)

    cloud.run_cloud_deploy(deploy_dir, 'deploy.py')


if __name__ == '__main__':
    main()