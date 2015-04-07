import common
import os
import yaml
import io
import re

N = common.N
E = common.E
R = common.R
RO = common.RO
exec_cmd = common.exec_cmd
parse = common.parse
err = common.err

class ConfigureSettings(object):

    def __init__(self, yaml_config_dir, env_id):
        self.yaml_config_dir = yaml_config_dir
        self.env_id = env_id

    def download_settings(self):
        exec_cmd('fuel --env %s settings --download' % self.env_id)

    def upload_settings(self):
        exec_cmd('fuel --env %s settings --upload' % self.env_id)


    def config_settings(self):
        self.download_settings()
        self.modify_settings()
        self.upload_settings()

    # Fix console speed
    def fix_console_speed(data):
        # First remove all console= from the kernel cmdline
        cmdline = data["editable"]["kernel_params"]["kernel"]["value"]
        pat = re.compile(r"console=[\w,]+\s+")
        repl = 1
        while repl != 0:
            cmdline, repl = pat.subn("", cmdline)

        # Then add the console info we want
        cmdline = re.sub(r"^", "console=tty0 console=ttyS0,115200 ", cmdline)
        data["editable"]["kernel_params"]["kernel"]["value"] = cmdline

    # Initialize kernel audit
    def initialize_kernel_audit(data):
        cmdline = data["editable"]["kernel_params"]["kernel"]["value"]
        cmdline = "audit=1 " + cmdline
        data["editable"]["kernel_params"]["kernel"]["value"] = cmdline

    # Add crashkernel parameter to boot parameters. W/o this we can't
    # make crash dumps after initial deploy. Standard grub setup will add
    # crashkernel= options - with bad values but that is another issue - but
    # that only enables crash dumps after first reboot
    def add_crashkernel_support(data):
        cmdline = data["editable"]["kernel_params"]["kernel"]["value"]
        cmdline += " crashkernel=256M"
        data["editable"]["kernel_params"]["kernel"]["value"] = cmdline


    def modify_settings(self):

        filename = "%s/settings_%d.yaml" % (self.yaml_config_dir, self.env_id)
        if not os.path.isfile(filename):
            err("Failed to find %s\n" % filename)

        with io.open(filename) as stream:
            data = yaml.load(stream)

        self.fix_console_speed(data)

        self.initialize_kernel_audit(data)

        self.add_crashkernel_support(data)

        # Make sure we have the correct libvirt type
        data["editable"]["common"]["libvirt_type"]["value"] = "kvm"


        # Save the settings into the file from which we loaded them
        with io.open(filename, "w") as stream:
            yaml.dump(data, stream, default_flow_style=False)





