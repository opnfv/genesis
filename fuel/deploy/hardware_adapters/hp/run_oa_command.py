import socket
import paramiko
import logging

LOG = logging.getLogger(__name__)
out_hdlr = logging.FileHandler(__file__.split('.')[0] + '.log', mode='w')
out_hdlr.setFormatter(logging.Formatter('%(levelname)s: %(message)s'))
LOG.addHandler(out_hdlr)
LOG.setLevel(logging.DEBUG)

class RunOACommand:

    def __init__(self, mgmt_ip, username, password):
        self.ssh = None
        self.mgmt_ip = mgmt_ip
        self.username = username
        self.password = password
        self.error_message = ""

    def connected(self):
        return self.ssh is not None

    def close(self):
        if self.connected():
            self.ssh.close()
            self.ssh = None
        self.error_message = ""

    def connect(self):
        LOG.info("Trying to connect to OA at %s" % self.mgmt_ip)
        try:
            self.ssh.connect(self.mgmt_ip,
                             username=self.username,
                             password=self.password,
                             look_for_keys=False,
                             allow_agent=False)
            return True
        except socket.error, (err, message):
            self.error_message += ("Can not talk to OA %s: %s\n" %
                                   (self.mgmt_ip, message))
        except Exception as e:
            self.error_message += ("Can not talk to OA %s: %s\n" %
                                   (self.mgmt_ip, e.args))
            LOG.error("Failed to connect to OA at %s" % self.mgmt_ip)
        return False

    # Return None if this most likely is not an OA
    #        False if we failed to connect to an active OA
    #        True if connected
    def connect_to_active(self):
        self.error_message = "OA connect failed with these errors:\n"

        self.ssh = paramiko.SSHClient()
        self.ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        initial_mgmt_ip = self.mgmt_ip
        if not self.connect(self.mgmt_ip, self.username, self.password):
            octets = self.mgmt_ip.split(".")
            self.mgmt_ip = "%s.%s.%s.%s" % (octets[0],
                                            octets[1],
                                            octets[2],
                                            str(int(octets[3]) + 1))
            if not self.connect(self.mgmt_ip, self.username, self.password):
                self.ssh = None
                LOG.error("Failed to connect to OA at %s (and %s)" %
                          (initial_mgmt_ip, self.mgmt_ip))
                return None

        output = self.send_command("show oa status")
        for line in output:
            if "Standby" in line:
                self.ssh.close()
                self.error_message += (
                    "%s is the standby OA, trying next OA\n" % self.mgmt_ip)
                LOG.info("%s is the standby OA" % self.mgmt_ip)
                if self.mgmt_ip != initial_mgmt_ip:
                    self.error_message += (
                        "Can only talk to OA %s which is the standby OA\n" %
                        self.mgmt_ip)
                    self.ssh = None
                    return False
                else:
                    octets = self.mgmt_ip.split(".")
                    self.mgmt_ip = "%s.%s.%s.%s" % (octets[0],
                                                    octets[1],
                                                    octets[2],
                                                    str(int(octets[3]) + 1))
                    if not self.connect(self.mgmt_ip, self.username,
                                        self.password):
                        self.ssh = None
                        return False
        LOG.info("Connected to active OA at %s" % self.mgmt_ip)
        self.error_message = ""
        return True

    def send_command(self, cmd):
        if not self.connected():
            self.error_message = (
                "Not connected, cannot send command %s\n" % (cmd))
            raise

        LOG.info('Sending "%s" to %s' % (cmd, self.mgmt_ip))
        stdin, stdout, stderr = self.ssh.exec_command(cmd)
        output = []
        for line in stdout.read().splitlines():
            if line != '':
                output.append(line)
        return output

    def __exit__(self, type, value, traceback):
        if self.connected():
            self.close()
            self.ssh = None