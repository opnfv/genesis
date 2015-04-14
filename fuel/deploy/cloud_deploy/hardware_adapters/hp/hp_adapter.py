import re
import time
from netaddr import EUI, mac_unix
from cloud import common

from run_oa_command import RunOACommand

LOG = common.LOG

class HpAdapter(object):

    # Exception thrown at any kind of failure to get the requested
    # information.
    class NoInfoFoundError(Exception):
        pass

    # Totally failed to connect so a re-try with other HW should
    # be done. This exception should never escape this class.
    class InternalConnectError(Exception):
        pass

    # Format MAC so leading zeroes are displayed
    class mac_dhcp(mac_unix):
        word_fmt = "%.2x"

    def __init__(self, mgmt_ip, username, password):
        self.mgmt_ip = mgmt_ip
        self.username = username
        self.password = password
        self.oa_error_message = ''

    def get_blade_mac_addresses(self, shelf, blade):

        LOG.debug("Entering: get_mac_addr_hp(%d,%d)" % (shelf, blade))
        self.oa_error_message = ''
        oa = RunOACommand(self.mgmt_ip, self.username, self.password)

        LOG.debug("Connect to active OA for shelf %d" % shelf)
        try:
            res = oa.connect_to_active()
        except:
            raise self.InternalConnectError(oa.error_message)
        if res is None:
            raise self.InternalConnectError(oa.error_message)
        if not oa.connected():
            raise self.NoInfoFoundError(oa.error_message)

        cmd = ("show server info " + str(blade))

        LOG.debug("Send command to OA: %s" % cmd)
        try:
            serverinfo = oa.send_command(cmd)
        except:
            raise self.NoInfoFoundError(oa.error_message)
        finally:
            oa.close()

        (left, right) = self.find_mac(serverinfo, shelf, blade)

        left = EUI(left, dialect=self.mac_dhcp)
        right = EUI(right, dialect=self.mac_dhcp)
        return [str(left), str(right)]

    def get_blades_mac_addresses(self, shelf, blade_list):
        macs_per_blade_dict = {}
        LOG.debug("Getting MAC addresses for shelf %s, blades %s"
                  % (shelf, blade_list))
        self.oa_error_message = ''
        oa = RunOACommand(self.mgmt_ip, self.username, self.password)

        LOG.debug("Connect to active OA for shelf %d" % shelf)
        try:
            res = oa.connect_to_active()
        except:
            raise self.InternalConnectError(oa.error_message)
        if res is None:
            raise self.InternalConnectError(oa.error_message)
        if not oa.connected():
            raise self.NoInfoFoundError(oa.error_message)
        try:
            for blade in blade_list:
                LOG.debug("Send command to OA: %s" % cmd)
                cmd = ("show server info %s" % blade)
                printout = oa.send_command(cmd)
                left, right = self.find_mac(printout, shelf, blade)
                left = EUI(left, dialect=self.mac_dhcp)
                right = EUI(right, dialect=self.mac_dhcp)
                macs_per_blade_dict[blade] = [str(left), str(right)]
        except:
            raise self.NoInfoFoundError(oa.error_message)
        finally:
            oa.close()
        return macs_per_blade_dict

    def get_blade_hardware_info(self, shelf, blade=None):
        if blade:
            LOG.debug("Entering: get_hp_info(%d,%d)" % (shelf, blade))
        else:
            LOG.debug("Entering: get_hp_info(%d)" % shelf)

        self.oa_error_message = ''
        oa = RunOACommand(self.mgmt_ip, self.username, self.password)

        LOG.debug("Connect to active OA for shelf %d" % shelf)

        try:
            res = oa.connect_to_active()
        except:
            self.oa_error_message = oa.error_message
            return None
        if res is None:
            self.oa_error_message = oa.error_message
            return None
        if not oa.connected():
            self.oa_error_message = oa.error_message
            return None

        # If no blade specified we're done we know this is an HP at this point
        if not blade:
            oa.close()
            return "HP"

        check = "show server info %d" % blade
        LOG.debug("Send command to OA: %s" % check)
        output = oa.send_command("%s" % check)
        oa.close()

        match = r"Product Name:\s+(.+)\Z"
        if re.search(match, str(output[:])) is None:
            self.oa_error_message = ("Blade %d in shelf %d does not exist\n"
                                     % (blade, shelf))
            return None

        for line in output:
            seobj = re.search(match, line)
            if seobj:
                return "HP %s" % seobj.group(1)
        return False

    def power_off_blades(self, shelf, blade_list):
        return self.set_state(shelf, 'locked', blade_list=blade_list)

    def power_on_blades(self, shelf, blade_list):
        return self.set_state(shelf, 'unlocked', blade_list=blade_list)

    def set_boot_order_blades(self, shelf, blade_list):
        return self.set_boot_order(shelf, blade_list=blade_list)

    def power_off_blade(self, shelf, blade):
        return self.set_state(shelf, 'locked', one_blade=blade)

    def power_on_blade(self, shelf, blade):
        return self.set_state(shelf, 'unlocked', one_blade=blade)

    def set_boot_order_blade(self, shelf, blade):
        return self.set_boot_order(shelf, one_blade=blade)

    # Search HP's OA server info for MAC for left and right control
    def find_mac(self, printout, shelf, blade):
        left = False
        right = False
        for line in printout:
            if ("No Server Blade Installed" in line or
                    "Invalid Arguments" in line):
                raise self.NoInfoFoundError("Blade %d in shelf %d "
                                            "does not exist." % (blade, shelf))
            seobj = re.search(r"LOM1:1-a\s+([0-9A-F:]+)", line, re.I)
            if seobj:
                left = seobj.group(1)
            else:
                seobj = re.search(r"LOM1:2-a\s+([0-9A-F:]+)", line, re.I)
                if seobj:
                    right = seobj.group(1)
            if left and right:
                return left, right
        raise self.NoInfoFoundError("Could not find MAC for blade %d "
                                    "in shelf %d." % (blade, shelf))

    # Do power on or off on all configured blades in shelf
    # Return None to indicate that no connection do OA succeeded,
    # Return False to indicate some connection to OA succeeded,
    # or config error
    # Return True to indicate that power state succesfully updated
    # state: locked, unlocked
    def set_state(self, shelf, state, one_blade=None, blade_list=None):
        if state not in ['locked', 'unlocked']:
            return None

        if one_blade:
            LOG.debug("Entering: set_state_hp(%d,%s,%d)" %
                      (shelf, state, one_blade))
        else:
            LOG.debug("Entering: set_state_hp(%d,%s)" % (shelf, state))

        self.oa_error_message = ''

        oa = RunOACommand(self.mgmt_ip, self.username, self.password)

        LOG.debug("Connect to active OA for shelf %d" % shelf)

        try:
            res = oa.connect_to_active()
        except:
            self.oa_error_message = oa.error_message
            return None
        if res is None:
            self.oa_error_message = oa.error_message
            return None
        if not oa.connected():
            self.oa_error_message = oa.error_message
            return False

        if one_blade:
            blades = [one_blade]
        else:
            blades = sorted(blade_list)

        LOG.debug("Check if blades are present")

        check = "show server list"

        LOG.debug("Send command to OA: %s" % check)
        output = oa.send_command(check)
        first = True
        bladelist = ''
        for blade in blades:
            prog = re.compile(r"\s+" + str(blade) + r"\s+\[Absent\]",
                              re.MULTILINE)
            if prog.search(str(output[:])) is not None:
                oa.close()
                self.oa_error_message = ("Blade %d in shelf %d "
                                         % (blade, shelf))
                if one_blade:
                    self.oa_error_message += ("does not exist.\n"
                                         "Set state %s not performed.\n"
                                         % state)
                else:
                    self.oa_error_message += (
                        "specified but does not exist.\nSet "
                        "state %s not performed on shelf %d\n"
                        % (state, shelf))
                return False
            if not first:
                bladelist += ","
            else:
                first = False
            bladelist += str(blade)

        if blade_list:
            LOG.debug("All blades present")

        # Use leading upper case on On/Off so it can be reused in match
        extra = ""
        if state == "locked":
            powerstate = "Off"
            extra = "force"
        else:
            powerstate = "On"

        cmd = "power%s server %s" % (powerstate, bladelist)

        if extra != "":
            cmd += " %s" % extra

        LOG.debug("Send command to OA: %s" % cmd)

        try:
            oa.send_command(cmd)
        except:
            self.oa_error_message = oa.error_message
            oa.close()
            return False

        # Check that all blades reach the state which can take some time,
        # so re-try a couple of times
        LOG.debug("Check if state %s successfully set" % state)
        recheck = 2
        while True:
            LOG.debug("Send command to OA: %s" % check)
            try:
                output = oa.send_command(check)
            except:
                self.oa_error_message = oa.error_message
                oa.close()
                return False
            for blade in blades:
                match = (r"\s+" + str(blade) +
                         r"\s+\w+\s+\w+.\w+.\w+.\w+\s+\w+\s+%s" %
                         powerstate)
                prog = re.compile(match, re.MULTILINE)
                if prog.search(str(output[:])) is None:
                    recheck -= 1
                    if recheck >= 0:
                        # Re-try
                        time.sleep(3)
                        break
                    oa.close()
                    self.oa_error_message = (
                        "Could not set state %s on blade %d in shelf %d\n"
                        % (state, one_blade, shelf))
                    for line in output:
                        self.oa_error_message += line
                    return False
            else:
                # state reached for all blades, exit the infinite loop
                break

        if one_blade:
            LOG.debug("State %s successfully set on blade %d in shelf %d"
                      % (state, one_blade, shelf))
        else:
            LOG.debug("State %s successfully set on blades %s in shelf %d"
                      % (state, blade_list, shelf))
        oa.close()
        return True

    # Change boot order on all blades in shelf
    # Return None to indicate that no connection do OA succeeded,
    # Return False to indicate some connection to OA succeeded,
    # or config error,
    # Return True to indicate that boot order succesfully changed
    def set_boot_order(self, shelf, one_blade=None, blade_list=None):

        if one_blade:
            LOG.debug("Entering: set_bootorder_hp(%d,%d)" % (shelf, one_blade))
        else:
            LOG.debug("Entering: set_bootorder_hp(%d)" % shelf)

        self.oa_error_message = ''

        oa = RunOACommand(self.mgmt_ip, self.username, self.password)

        LOG.debug("Connect to active OA for shelf %d" % shelf)

        try:
            res = oa.connect_to_active()
        except:
            self.oa_error_message = oa.error_message
            return None
        if res is None:
            self.oa_error_message = oa.error_message
            return None
        if not oa.connected():
            self.oa_error_message = oa.error_message
            return False

        if one_blade:
            blades = [one_blade]
        else:
            blades = sorted(blade_list)

        LOG.debug("Check if blades are present")

        check = "show server list"

        LOG.debug("Send command to OA: %s" % check)

        output = oa.send_command(check)
        first = True
        bladelist = ''
        for blade in blades:
            prog = re.compile(r"\s+" + str(blade) + r"\s+\[Absent\]",
                              re.MULTILINE)
            if prog.search(str(output[:])) is not None:
                oa.close()
                self.oa_error_message = ("Blade %d in shelf %d "
                                         % (blade, shelf))
                if one_blade:
                    self.oa_error_message += (
                        "does not exist.\nChange boot order not performed.\n")
                else:
                    self.oa_error_message += (
                        "specified but does not exist.\n"
                        "Change boot order not performed on shelf %d\n"
                        % shelf)
                return False
            if not first:
                bladelist += ','
            else:
                first = False
            bladelist += str(blade)

        if blade_list:
            LOG.debug("All blades present")

        # Boot origins are pushed so first set boot from hard disk, then PXE
        # NB! If we want to support boot from SD we must add USB to the "stack"
        cmd1 = "set server boot first hdd %s" % bladelist
        cmd2 = "set server boot first pxe %s" % bladelist
        for cmd in [cmd1, cmd2]:

            LOG.debug("Send command to OA: %s" % cmd)
            try:
                output = oa.send_command(cmd)
            except:
                self.oa_error_message = oa.error_message
                for line in output:
                    self.oa_error_message += line
                oa.close()
                return False

        # Check that all blades got the correct boot order
        # Needs updating if USB is added
        LOG.debug("Check if boot order successfully set")
        match = (r"^.*Boot Order\):\',\s*\'(\\t)+PXE NIC 1\',\s*\'(\\t)"
                 r"+Hard Drive")
        prog = re.compile(match)
        for blade in blades:

            check = "show server boot %d" % blade

            LOG.debug("Send command to OA: %s" % check)
            try:
                output = oa.send_command(check)
            except:
                self.oa_error_message = oa.error_message
                oa.close()
                return False
            if prog.search(str(output[:])) is None:
                oa.close()
                self.oa_error_message = ("Failed to set boot order on blade "
                                         "%d in shelf %d\n" % (blade, shelf))
                for line in output:
                    self.oa_error_message += line
                return False
            LOG.debug("Boot order successfully set on blade %d in shelf %d"
                      % (blade, shelf))

        if blade_list:
            LOG.debug("Boot order successfully set on all configured blades "
                      "in shelf %d" % (shelf))
        oa.close()
        return True
