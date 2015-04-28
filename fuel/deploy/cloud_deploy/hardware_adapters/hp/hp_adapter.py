import re
import time
from netaddr import EUI, mac_unix
from cloud import common
from ssh_client import SSHClient

LOG = common.LOG
err = common.err

S = {'bay': 0, 'ilo_name': 1, 'ilo_ip': 2, 'status': 3, 'power': 4,
     'uid_partner': 5}

class HpAdapter(object):

    def __init__(self, mgmt_ip, username, password):
        self.mgmt_ip = mgmt_ip
        self.username = username
        self.password = password

    class mac_dhcp(mac_unix):
        word_fmt = '%.2x'

    def next_ip(self):
        digit_list = self.mgmt_ip.split('.')
        digit_list[3] = str(int(digit_list[3]) + 1)
        self.mgmt_ip = '.'.join(digit_list)

    def connect(self):
        verified_ips = [self.mgmt_ip]
        ssh = SSHClient(self.mgmt_ip, self.username, self.password)
        try:
            ssh.open()
        except Exception:
            self.next_ip()
            verified_ips.append(self.mgmt_ip)
            ssh = SSHClient(self.mgmt_ip, self.username, self.password)
            try:
                ssh.open()
            except Exception as e:
                err('Could not connect to HP Onboard Administrator through '
                    'these IPs: %s, reason: %s' % (verified_ips, e))

        lines = self.clean_lines(ssh.execute('show oa status'))
        for line in lines:
            if 'Role:   Standby' in line:
                ssh.close()
                if self.mgmt_ip != verified_ips[0]:
                    err('Can only talk to OA %s which is the standby OA\n'
                        % self.mgmt_ip)
                else:
                    LOG.debug('%s is the standby OA, trying next OA\n'
                              % self.mgmt_ip)
                    self.next_ip()
                    verified_ips.append(self.mgmt_ip)
                    ssh = SSHClient(self.mgmt_ip, self.username, self.password)
                    try:
                        ssh.open()
                    except Exception as e:
                        err('Could not connect to HP Onboard Administrator'
                            ' through these IPs: %s, reason: %s'
                            % (verified_ips, e))

            elif 'Role:   Active' in line:
                return ssh
        err('Could not reach Active OA through these IPs %s' % verified_ips)

    def get_blades_mac_addresses(self, shelf, blade_list):
        macs_per_blade_dict = {}
        LOG.debug('Getting MAC addresses for shelf %s, blades %s'
                  % (shelf, blade_list))
        ssh = self.connect()
        for blade in blade_list:
            lines = self.clean_lines(
                ssh.execute('show server info %s' % blade))
            left, right = self.find_mac(lines, shelf, blade)

            left = EUI(left, dialect=self.mac_dhcp)
            right = EUI(right, dialect=self.mac_dhcp)
            macs_per_blade_dict[blade] = [str(left), str(right)]
        ssh.close()
        return macs_per_blade_dict

    def find_mac(self, printout, shelf, blade):
        left = False
        right = False
        for line in printout:
            if ('No Server Blade Installed' in line or
                'Invalid Arguments' in line):
                err('Blade %d in shelf %d does not exist' % (blade, shelf))

            seobj = re.search(r'LOM1:1-a\s+([0-9A-F:]+)', line, re.I)
            if seobj:
                left = seobj.group(1)
            else:
                seobj = re.search(r'LOM1:2-a\s+([0-9A-F:]+)', line, re.I)
                if seobj:
                    right = seobj.group(1)
            if left and right:
                return left, right

    def get_hardware_info(self, shelf, blade=None):
        ssh = self.connect()
        if ssh and not blade:
            ssh.close()
            return 'HP'

        lines = self.clean_lines(ssh.execute('show server info %s' % blade))
        ssh.close()

        match = r'Product Name:\s+(.+)\Z'
        if not re.search(match, str(lines[:])):
            LOG.debug('Blade %s in shelf %s does not exist\n' % (blade, shelf))
            return False

        for line in lines:
            seobj = re.search(match, line)
            if seobj:
                return 'HP %s' % seobj.group(1)
        return False

    def power_off_blades(self, shelf, blade_list):
        return self.set_state(shelf, 'locked', blade_list)

    def power_on_blades(self, shelf, blade_list):
        return self.set_state(shelf, 'unlocked', blade_list)

    def set_boot_order_blades(self, shelf, blade_list):
        return self.set_boot_order(shelf, blade_list=blade_list)

    def parse(self, lines):
        parsed_list = []
        for l in lines[5:-2]:
             parsed = []
             cluttered = [e.strip() for e in l.split(' ')]
             for p in cluttered:
                 if p:
                     parsed.append(p)
             parsed_list.append(parsed)
        return parsed_list

    def set_state(self, shelf, state, blade_list):
        if state not in ['locked', 'unlocked']:
            LOG.debug('Incorrect state: %s' % state)
            return None

        LOG.debug('Setting state %s for blades %s in shelf %s'
                  % (state, blade_list, shelf))

        blade_list = sorted(blade_list)
        ssh = self.connect()

        LOG.debug('Check if blades are present')
        server_list = self.parse(
            self.clean_lines(ssh.execute('show server list')))

        for blade in blade_list:
            if server_list[S['status']] == 'Absent':
                LOG.debug('Blade %s in shelf %s is missing. '
                          'Set state %s not performed\n'
                          % (blade, shelf, state))
                blade_list.remove(blade)

        bladelist = ','.join(blade_list)

        # Use leading upper case on On/Off so it can be reused in match
        force = ''
        if state == 'locked':
            powerstate = 'Off'
            force = 'force'
        else:
            powerstate = 'On'
        cmd = 'power%s server %s' % (powerstate, bladelist)
        if force:
            cmd += ' %s' % force

        LOG.debug(cmd)
        ssh.execute(cmd)

        # Check that all blades reach the state which can take some time,
        # so re-try a couple of times
        LOG.debug('Check if state %s successfully set' % state)

        WAIT_LOOP = 2
        SLEEP_TIME = 3

        set_blades = []

        for i in range(WAIT_LOOP):
            server_list = self.parse(
                self.clean_lines(ssh.execute('show server list')))

            for blade in blade_list:
                for server in server_list:
                    if (server[S['bay']] == blade and
                        server[S['power']] == powerstate):
                        set_blades.append(blade)
                        break

            all_set = set(blade_list) == set(set_blades)
            if all_set:
                break
            else:
                time.sleep(SLEEP_TIME)

        ssh.close()

        if all_set:
            LOG.debug('State %s successfully set on blades %s in shelf %d'
                      % (state, set_blades, shelf))
            return True
        else:
            LOG.debug('Could not set state %s on blades %s in shelf %s\n'
                      % (state, set(blade_list) - set(set_blades), shelf))
        return False


    def clean_lines(self, printout):
        lines = []
        for p in [l.strip() for l in printout.splitlines()]:
            if p:
                lines.append(p)
        return lines


    def set_boot_order_blades(self, shelf, blade_list, boot_dev_list=None):

        boot_dict = {'Hard Drive': 'hdd',
                     'PXE NIC': 'pxe',
                     'CD-ROM': 'cd',
                     'USB': 'usb',
                     'Diskette Driver': 'disk'}

        boot_options = [b for b in boot_dict.itervalues()]
        diff = list(set(boot_dev_list) - set(boot_options))
        if diff:
            err('The following boot options %s are not valid' % diff)

        blade_list = sorted(blade_list)
        LOG.debug('Setting boot order %s for blades %s in shelf %s'
                  % (boot_dev_list, blade_list, shelf))

        ssh = self.connect()

        LOG.debug('Check if blades are present')
        server_list = self.parse(
            self.clean_lines(ssh.execute('show server list')))

        for blade in blade_list:
            if server_list[S['status']] == 'Absent':
                LOG.debug('Blade %s in shelf %s is missing. '
                          'Change boot order %s not performed.\n'
                          % (blade, shelf, boot_dev_list))
                blade_list.remove(blade)

        bladelist = ','.join(blade_list)

        for boot_dev in reversed(boot_dev_list):
            ssh.execute('set server boot first %s %s' % (boot_dev, bladelist))

        LOG.debug('Check if boot order is successfully set')

        success_list = []
        boot_keys = [b for b in boot_dict.iterkeys()]
        for blade in blade_list:
            lines = self.clean_lines(ssh.execute('show server boot %s'
                                                 % blade))
            boot_order = lines[lines.index('IPL Devices (Boot Order):')+1:]
            boot_list = []
            success = False
            for b in boot_order:
                for k in boot_keys:
                    if k in b:
                        boot_list.append(boot_dict[k])
                        break
                if boot_list == boot_dev_list:
                    success = True
                    break

            success_list.append(success)
            if success:
                LOG.debug('Boot order %s successfully set on blade %s in '
                          'shelf %s\n' % (boot_dev_list, blade, shelf))
            else:
                LOG.debug('Failed to set boot order %s on blade %s in '
                          'shelf %s\n' % (boot_dev_list, blade, shelf))

        ssh.close()
        return all(success_list)
