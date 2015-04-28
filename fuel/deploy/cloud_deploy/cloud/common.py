import subprocess
import sys
import os
import logging

N = {'id': 0, 'status': 1, 'name': 2, 'cluster': 3, 'ip': 4, 'mac': 5,
     'roles': 6, 'pending_roles': 7, 'online': 8}
E = {'id': 0, 'status': 1, 'name': 2, 'mode': 3, 'release_id': 4,
     'changes': 5, 'pending_release_id': 6}
R = {'id': 0, 'name': 1, 'state': 2, 'operating_system': 3, 'version': 4}
RO = {'name': 0, 'conflicts': 1}

LOG = logging.getLogger(__name__)
LOG.setLevel(logging.DEBUG)
formatter = logging.Formatter('%(message)s')
out_handler = logging.StreamHandler(sys.stdout)
out_handler.setFormatter(formatter)
LOG.addHandler(out_handler)
out_handler = logging.FileHandler('autodeploy.log', mode='w')
out_handler.setFormatter(formatter)
LOG.addHandler(out_handler)

def exec_cmd(cmd):
    process = subprocess.Popen(cmd,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT,
                               shell=True)
    return process.communicate()[0], process.returncode

def run_proc(cmd):
    process = subprocess.Popen(cmd,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT,
                               shell=True)
    return process

def parse(printout, *args):
    parsed_list = []
    lines = printout[0].splitlines()
    for l in lines[2:]:
         parsed = [e.strip() for e in l.split('|')]
         parsed_list.append(parsed)
    return parsed_list

def err(error_message):
    LOG.error(error_message)
    sys.exit(1)

def check_file_exists(file_path):
    if not os.path.isfile(file_path):
        err('ERROR: File %s not found\n' % file_path)
