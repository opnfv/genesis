from hp.hp_adapter import HpAdapter
from libvirt.libvirt_adapter import LibvirtAdapter

class DeploymentHardwareAdapter(object):
    def __new__(cls, server_type, *args):
        if cls is DeploymentHardwareAdapter:
            if server_type == 'esxi':  return EsxiAdapter(*args)
            if server_type == 'hp': return HpAdapter(*args)
            if server_type == 'dell': return DellAdapter(*args)
            if server_type == 'libvirt': return LibvirtAdapter(*args)
        return super(DeploymentHardwareAdapter, cls).__new__(cls)


class HardwareAdapter(object):

    def power_off_blades(self, shelf, blade_list):
        raise NotImplementedError

    def power_off_blade(self, shelf, blade):
        raise NotImplementedError

    def power_on_blades(self, shelf, blade_list):
        raise NotImplementedError

    def power_on_blade(self, shelf, blade):
        raise NotImplementedError

    def power_cycle_blade(self):
        raise NotImplementedError

    def set_boot_order_blades(self, shelf, blade_list):
        raise NotImplementedError

    def set_boot_order_blade(self, shelf, blade):
        raise NotImplementedError

    def reset_to_factory_defaults(self):
        raise NotImplementedError

    def configure_networking(self):
        raise NotImplementedError

    def get_blade_mac_addresses(self, shelf, blade):
        raise NotImplementedError

    def get_hardware_info(self, shelf, blade):
        raise NotImplementedError


class EsxiAdapter(HardwareAdapter):

    def __init__(self):
        self.environment = {1: {1: {'mac': ['00:50:56:8c:05:85']},
                                2: {'mac': ['00:50:56:8c:21:92']}}}

    def get_blade_mac_addresses(self, shelf, blade):
        return self.environment[shelf][blade]['mac']


class DellAdapter(HardwareAdapter):
    pass
