import os
import shutil
import io
import re
import sys
import netaddr
import uuid
import yaml

from dea import DeploymentEnvironmentAdapter
from dha import DeploymentHardwareAdapter
from install_fuel_master import InstallFuelMaster
from deploy_env import CloudDeploy
from setup_execution_environment import ExecutionEnvironment
import common

log = common.log
exec_cmd = common.exec_cmd
err = common.err
check_file_exists = common.check_file_exists
check_dir_exists = common.check_dir_exists
create_dir_if_not_exists = common.create_dir_if_not_exists
check_if_root = common.check_if_root
ArgParser = common.ArgParser

FUEL_VM = 'fuel'
PATCH_DIR = 'fuel_patch'
WORK_DIR = 'deploy'
CWD = os.getcwd()

class cd:
    def __init__(self, new_path):
        self.new_path = os.path.expanduser(new_path)

    def __enter__(self):
        self.saved_path = CWD
        os.chdir(self.new_path)

    def __exit__(self, etype, value, traceback):
        os.chdir(self.saved_path)


class AutoDeploy(object):

    def __init__(self, without_fuel, storage_dir, pxe_bridge, iso_file,
                 dea_file, dha_file):
        self.without_fuel = without_fuel
        self.storage_dir = storage_dir
        self.pxe_bridge = pxe_bridge
        self.iso_file = iso_file
        self.dea_file = dea_file
        self.dha_file = dha_file
        self.dea = DeploymentEnvironmentAdapter(dea_file)
        self.dha = DeploymentHardwareAdapter(dha_file)
        self.fuel_conf = {}
        self.fuel_node_id = self.dha.get_fuel_node_id()
        self.fuel_username, self.fuel_password = self.dha.get_fuel_access()
        self.tmp_dir = None

    def modify_ip(self, ip_addr, index, val):
        ip_str = str(netaddr.IPAddress(ip_addr))
        decimal_list = map(int, ip_str.split('.'))
        decimal_list[index] = val
        return '.'.join(map(str, decimal_list))

    def collect_fuel_info(self):
        self.fuel_conf['ip'] = self.dea.get_fuel_ip()
        self.fuel_conf['gw'] = self.dea.get_fuel_gateway()
        self.fuel_conf['dns1'] = self.dea.get_fuel_dns()
        self.fuel_conf['netmask'] = self.dea.get_fuel_netmask()
        self.fuel_conf['hostname'] = self.dea.get_fuel_hostname()
        self.fuel_conf['showmenu'] = 'yes'

    def install_fuel_master(self):
        log('Install Fuel Master')
        new_iso = '%s/deploy-%s' \
                  % (self.tmp_dir, os.path.basename(self.iso_file))
        self.patch_iso(new_iso)
        self.iso_file = new_iso
        self.install_iso()

    def install_iso(self):
        fuel = InstallFuelMaster(self.dea_file, self.dha_file,
                                 self.fuel_conf['ip'], self.fuel_username,
                                 self.fuel_password, self.fuel_node_id,
                                 self.iso_file, WORK_DIR)
        fuel.install()

    def patch_iso(self, new_iso):
        tmp_orig_dir = '%s/origiso' % self.tmp_dir
        tmp_new_dir = '%s/newiso' % self.tmp_dir
        self.copy(tmp_orig_dir, tmp_new_dir)
        self.patch(tmp_new_dir, new_iso)

    def copy(self, tmp_orig_dir, tmp_new_dir):
        log('Copying...')
        os.makedirs(tmp_orig_dir)
        os.makedirs(tmp_new_dir)
        exec_cmd('fuseiso %s %s' % (self.iso_file, tmp_orig_dir))
        with cd(tmp_orig_dir):
            exec_cmd('find . | cpio -pd %s' % tmp_new_dir)
        with cd(tmp_new_dir):
            exec_cmd('fusermount -u %s' % tmp_orig_dir)
        shutil.rmtree(tmp_orig_dir)
        exec_cmd('chmod -R 755 %s' % tmp_new_dir)

    def patch(self, tmp_new_dir, new_iso):
        log('Patching...')
        patch_dir = '%s/%s' % (CWD, PATCH_DIR)
        ks_path = '%s/ks.cfg.patch' % patch_dir

        with cd(tmp_new_dir):
            exec_cmd('cat %s | patch -p0' % ks_path)
            shutil.rmtree('.rr_moved')
            isolinux = 'isolinux/isolinux.cfg'
            log('isolinux.cfg before: %s'
                % exec_cmd('grep netmask %s' % isolinux))
            self.update_fuel_isolinux(isolinux)
            log('isolinux.cfg after: %s'
                % exec_cmd('grep netmask %s' % isolinux))

            iso_linux_bin = 'isolinux/isolinux.bin'
            exec_cmd('mkisofs -quiet -r -J -R -b %s '
                     '-no-emul-boot -boot-load-size 4 '
                     '-boot-info-table -hide-rr-moved '
                     '-x "lost+found:" -o %s .'
                     % (iso_linux_bin, new_iso))

    def update_fuel_isolinux(self, file):
        with io.open(file) as f:
            data = f.read()
        for key, val in self.fuel_conf.iteritems():
            pattern = r'%s=[^ ]\S+' % key
            replace = '%s=%s' % (key, val)
            data = re.sub(pattern, replace, data)
        with io.open(file, 'w') as f:
            f.write(data)

    def deploy_env(self):
        dep = CloudDeploy(self.dha, self.fuel_conf['ip'], self.fuel_username,
                          self.fuel_password, self.dea_file, WORK_DIR)
        return dep.deploy()

    def setup_execution_environment(self):
        exec_env = ExecutionEnvironment(self.storage_dir, self.pxe_bridge,
                                        self.dha_file, self.dea)
        exec_env.setup_environment()

    def create_tmp_dir(self):
        self.tmp_dir = '%s/fueltmp-%s' % (CWD, str(uuid.uuid1()))
        os.makedirs(self.tmp_dir)

    def deploy(self):
        check_if_root()
        self.collect_fuel_info()
        if not self.without_fuel:
            self.setup_execution_environment()
            self.create_tmp_dir()
            self.install_fuel_master()
            shutil.rmtree(self.tmp_dir)
        return self.deploy_env()

def check_bridge(pxe_bridge, dha_path):
    with io.open(dha_path) as yaml_file:
        dha_struct = yaml.load(yaml_file)
    if dha_struct['adapter'] != 'libvirt':
        log('Using Linux Bridge %s for booting up the Fuel Master VM'
            % pxe_bridge)
        r = exec_cmd('ip link show %s' % pxe_bridge)
        if pxe_bridge in r and 'state UP' not in r:
            err('Linux Bridge {0} is not Active, '
                'bring it UP first: [ip link set dev {0} up]' % pxe_bridge)

def parse_arguments():
    parser = ArgParser(prog='python %s' % __file__)
    parser.add_argument('-nf', dest='without_fuel', action='store_true',
                        default=False,
                        help='Do not install Fuel Master (and Node VMs when '
                             'using libvirt)')
    parser.add_argument('iso_file', nargs='?', action='store',
                        default='%s/OPNFV.iso' % CWD,
                        help='ISO File [default: OPNFV.iso]')
    parser.add_argument('dea_file', action='store',
                        help='Deployment Environment Adapter: dea.yaml')
    parser.add_argument('dha_file', action='store',
                        help='Deployment Hardware Adapter: dha.yaml')
    parser.add_argument('storage_dir', nargs='?', action='store',
                        default='%s/images' % CWD,
                        help='Storage Directory [default: images]')
    parser.add_argument('pxe_bridge', nargs='?', action='store',
                        default='pxebr',
                        help='Linux Bridge for booting up the Fuel Master VM '
                             '[default: pxebr]')

    args = parser.parse_args()

    check_file_exists(args.dea_file)
    check_file_exists(args.dha_file)

    if not args.without_fuel:
        log('Using OPNFV ISO file: %s' % args.iso_file)
        check_file_exists(args.iso_file)
        log('Using image directory: %s' % args.storage_dir)
        create_dir_if_not_exists(args.storage_dir)
        log('Using bridge %s to boot up Fuel Master VM on it'
            % args.pxe_bridge)
        check_bridge(args.pxe_bridge, args.dha_file)

    return (args.without_fuel, args.storage_dir, args.pxe_bridge,
            args.iso_file, args.dea_file, args.dha_file)


def main():
    without_fuel, storage_dir, pxe_bridge, iso_file, dea_file, dha_file = \
        parse_arguments()

    d = AutoDeploy(without_fuel, storage_dir, pxe_bridge, iso_file,
                   dea_file, dha_file)
    sys.exit(d.deploy())

if __name__ == '__main__':
    main()