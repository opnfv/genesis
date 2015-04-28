from lxml import etree
from cloud import common
from ssh_client import SSHClient

exec_cmd = common.exec_cmd
err = common.err
LOG = common.LOG


class LibvirtAdapter(object):

    def __init__(self, mgmt_ip, username, password):
        self.mgmt_ip = mgmt_ip
        self.username = username
        self.password = password
        self.parser = etree.XMLParser(remove_blank_text=True)

    def power_off_blades(self, shelf, blade_list):
        ssh = SSHClient(self.mgmt_ip, self.username, self.password)
        ssh.open()
        for blade in blade_list:
            LOG.debug('Power off blade %s in shelf %s' % (blade, shelf))
            vm_name = 's%s_b%s' % (shelf, blade)
            resp = ssh.execute('virsh destroy %s' % vm_name)
            LOG.debug('response: %s' % resp)
        ssh.close()

    def power_on_blades(self, shelf, blade_list):
        ssh = SSHClient(self.mgmt_ip, self.username, self.password)
        ssh.open()
        for blade in blade_list:
            LOG.debug('Power on blade %s in shelf %s' % (blade, shelf))
            vm_name = 's%s_b%s' % (shelf, blade)
            resp = ssh.execute('virsh start %s' % vm_name)
            LOG.debug('response: %s' % resp)
        ssh.close()

    def set_boot_order_blades(self, shelf, blade_list, boot_dev_list=None):
        if not boot_dev_list:
            boot_dev_list = ['network', 'hd']
        ssh = SSHClient(self.mgmt_ip, self.username, self.password)
        ssh.open()
        temp_dir= ssh.execute('mktemp -d').strip()
        for blade in blade_list:
            LOG.debug('Set boot order %s on blade %s in shelf %s'
                  % (boot_dev_list, blade, shelf))
            vm_name = 's%s_b%s' % (shelf, blade)
            resp = ssh.execute('virsh dumpxml %s' % vm_name)
            xml_dump = etree.fromstring(resp, self.parser)
            os = xml_dump.xpath('/domain/os')
            for o in os:
                for bootelem in ['boot', 'bootmenu']:
                    boot = o.xpath(bootelem)
                    for b in boot:
                        b.getparent().remove(b)
                for dev in boot_dev_list:
                    b = etree.Element('boot')
                    b.set('dev', dev)
                    o.append(b)
                bmenu = etree.Element('bootmenu')
                bmenu.set('enable', 'no')
                o.append(bmenu)
            tree = etree.ElementTree(xml_dump)
            xml_file = temp_dir + '/%s.xml' % vm_name
            with open(xml_file, 'w') as f:
                tree.write(f, pretty_print=True, xml_declaration=True)
            ssh.execute('virsh define %s' % xml_file)
        ssh.execute('rm -fr %s' % temp_dir)
        ssh.close()

    def get_blades_mac_addresses(self, shelf, blade_list):
        LOG.debug('Get the MAC addresses of blades %s in shelf %s'
              % (blade_list, shelf))
        macs_per_blade_dict = {}
        ssh = SSHClient(self.mgmt_ip, self.username, self.password)
        ssh.open()
        for blade in blade_list:
            vm_name = 's%s_b%s' % (shelf, blade)
            mac_list = macs_per_blade_dict[blade] = []
            resp = ssh.execute('virsh dumpxml %s' % vm_name)
            xml_dump = etree.fromstring(resp)
            interfaces = xml_dump.xpath('/domain/devices/interface')
            for interface in interfaces:
                macs = interface.xpath('mac')
                for mac in macs:
                    mac_list.append(mac.get('address'))
        ssh.close()
        return macs_per_blade_dict

    def load_image_file(self, shelf=None, blade=None, vm=None,
                        image_path=None):
        if shelf and blade:
            vm_name = 's%s_b%s' % (shelf, blade)
        else:
            vm_name = vm

        LOG.debug('Load media file %s into %s '
                  % (image_path, 'vm %s' % vm if vm else 'blade %s in shelf %s'
                                                         % (shelf, blade)))

        ssh = SSHClient(self.mgmt_ip, self.username, self.password)
        ssh.open()
        temp_dir= ssh.execute('mktemp -d').strip()
        resp = ssh.execute('virsh dumpxml %s' % vm_name)
        xml_dump = etree.fromstring(resp)

        disks = xml_dump.xpath('/domain/devices/disk')
        for disk in disks:
            if disk.get('device') == 'cdrom':
                disk.set('type', 'file')
                sources = disk.xpath('source')
                for source in sources:
                    disk.remove(source)
                source = etree.SubElement(disk, 'source')
                source.set('file', image_path)
        tree = etree.ElementTree(xml_dump)
        xml_file = temp_dir + '/%s.xml' % vm_name
        with open(xml_file, 'w') as f:
            tree.write(f, pretty_print=True, xml_declaration=True)
        ssh.execute('virsh define %s' % xml_file)
        ssh.execute('rm -fr %s' % temp_dir)
        ssh.close()

    def eject_image_file(self, shelf=None, blade=None, vm=None):
        if shelf and blade:
            vm_name = 's%s_b%s' % (shelf, blade)
        else:
            vm_name = vm

        LOG.debug('Eject media file from %s '
                  % 'vm %s' % vm if vm else 'blade %s in shelf %s'
                                            % (shelf, blade))

        ssh = SSHClient(self.mgmt_ip, self.username, self.password)
        ssh.open()
        temp_dir= ssh.execute('mktemp -d').strip()
        resp = ssh.execute('virsh dumpxml %s' % vm_name)
        xml_dump = etree.fromstring(resp)

        disks = xml_dump.xpath('/domain/devices/disk')
        for disk in disks:
            if disk.get('device') == 'cdrom':
                disk.set('type', 'block')
                sources = disk.xpath('source')
                for source in sources:
                    disk.remove(source)
        tree = etree.ElementTree(xml_dump)
        xml_file = temp_dir + '/%s.xml' % vm_name
        with open(xml_file, 'w') as f:
            tree.write(f, pretty_print=True, xml_declaration=True)
        ssh.execute('virsh define %s' % xml_file)
        ssh.execute('rm -fr %s' % temp_dir)
        ssh.close()
