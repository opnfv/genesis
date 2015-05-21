import yaml
import io
import sys
import os

import common
from environments.libvirt_environment import LibvirtEnvironment
from environments.virtual_fuel import VirtualFuel
from dea import DeploymentEnvironmentAdapter

exec_cmd = common.exec_cmd
err = common.err
log = common.log
check_dir_exists = common.check_dir_exists
check_file_exists = common.check_file_exists
check_if_root = common.check_if_root
ArgParser = common.ArgParser

class ExecutionEnvironment(object):
    def __new__(cls, storage_dir, pxe_bridge, dha_path, dea):

        with io.open(dha_path) as yaml_file:
            dha_struct = yaml.load(yaml_file)

        type = dha_struct['adapter']

        root_dir = os.path.dirname(os.path.realpath(__file__))

        if cls is ExecutionEnvironment:
            if type == 'libvirt':
                return LibvirtEnvironment(storage_dir, dha_path, dea, root_dir)

            if type == 'ipmi' or type == 'hp':
                return VirtualFuel(storage_dir, pxe_bridge, dha_path, root_dir)

        return super(ExecutionEnvironment, cls).__new__(cls)
