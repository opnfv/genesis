import subprocess
import sys


N = {'id': 0, 'status': 1, 'name': 2, 'cluster': 3, 'ip': 4, 'mac': 5,
     'roles': 6, 'pending_roles': 7, 'online': 8}
E = {'id': 0, 'status': 1, 'name': 2, 'mode': 3, 'release_id': 4,
     'changes': 5, 'pending_release_id': 6}
R = {'id': 0, 'name': 1, 'state': 2, 'operating_system': 3, 'version': 4}
RO = {'name': 0, 'conflicts': 1}

def exec_cmd(cmd):
    process = subprocess.Popen(cmd,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT,
                               shell=True)
    return process.communicate()[0]

def parse(printout):
    parsed_list = []
    lines = printout.splitlines()
    for l in lines[2:]:
         parsed = [e.strip() for e in l.split('|')]
         parsed_list.append(parsed)
    return parsed_list

def err(error_message):
    sys.stderr.write(error_message)
    sys.exit(1)
