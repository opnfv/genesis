
class DeploymentHardwareAdapter(object):
    def __new__(cls, server_type):
        if cls is DeploymentHardwareAdapter:
            if server_type == 'esxi':  return EsxiAdapter()
            if server_type == 'hp': return HpAdapter()
            if server_type == 'dell': return DellAdapter()
            if server_type == 'libvirt': return LibvirtAdapter()
        return super(DeploymentHardwareAdapter, cls).__new__(cls)


class HardwareAdapter(object):

    def power_off_blades(self):
        raise NotImplementedError

    def power_on_blades(self):
        raise NotImplementedError

    def power_cycle_blade(self):
        raise NotImplementedError

    def set_boot_order(self):
        raise NotImplementedError

    def reset_to_factory_defaults(self):
        raise NotImplementedError

    def configure_networking(self):
        raise NotImplementedError

    def get_blade_mac_addresses(self, shelf_id, blade_id):
        raise NotImplementedError

    def get_blade_hardware_info(self, shelf_id, blade_id):
        raise NotImplementedError


class EsxiAdapter(HardwareAdapter):
    pass

class LibvirtAdapter(HardwareAdapter):
    pass

class HpAdapter(HardwareAdapter):
    pass

class DellAdapter(HardwareAdapter):
    pass
