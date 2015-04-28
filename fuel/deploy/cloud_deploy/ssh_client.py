import paramiko
from cloud import common

TIMEOUT = 600
LOG = common.LOG

class SSHClient(object):

    def __init__(self, host, username, password):
        self.host = host
        self.username = username
        self.password = password
        self.client = None

    def open(self, timeout=TIMEOUT):
        self.client = paramiko.SSHClient()
        self.client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.client.connect(self.host, username=self.username,
                            password=self.password, timeout=timeout)

    def close(self):
        if self.client is not None:
            self.client.close()
            self.client = None

    def execute(self, command, sudo=False, timeout=TIMEOUT):
        if sudo and self.username != 'root':
            command = "sudo -S -p '' %s" % command
        stdin, stdout, stderr = self.client.exec_command(command,
                                                         timeout=timeout)
        if sudo:
            stdin.write(self.password + '\n')
            stdin.flush()
        return ''.join(''.join(stderr.readlines()) +
                       ''.join(stdout.readlines()))

    def run(self, command):
        transport = self.client.get_transport()
        transport.set_keepalive(1)
        chan = transport.open_session()
        chan.exec_command(command)

        while not chan.exit_status_ready():
            if chan.recv_ready():
                data = chan.recv(1024)
                while data:
                    print data
                    data = chan.recv(1024)

            if chan.recv_stderr_ready():
                error_buff = chan.recv_stderr(1024)
                while error_buff:
                    print error_buff
                    error_buff = chan.recv_stderr(1024)
        exit_status = chan.recv_exit_status()
        LOG.debug('Exit status %s' % exit_status)