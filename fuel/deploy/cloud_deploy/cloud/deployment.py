import common
import os
import shutil
import glob
import yaml
import io
import time

N = common.N
E = common.E
R = common.R
RO = common.RO
exec_cmd = common.exec_cmd
run_proc = common.run_proc
parse = common.parse
err = common.err
LOG = common.LOG


class Deployment(object):

    def __init__(self, dea, yaml_config_dir, env_id, node_id_roles_dict):
        self.dea = dea
        self.env_name = dea.get_environment_name()
        self.yaml_config_dir = yaml_config_dir
        self.env_id = env_id
        self.node_id_roles_dict = node_id_roles_dict
        self.node_id_list = []
        for node_id in self.node_id_roles_dict.iterkeys():
            self.node_id_list.append(node_id)
        self.node_id_list.sort()

    def download_deployment_info(self):
        LOG.debug('Download deployment info for environment %s\n' % self.env_id)
        deployment_dir = self.yaml_config_dir + '/deployment_%s' % self.env_id
        if os.path.exists(deployment_dir):
            shutil.rmtree(deployment_dir)
        r, c = exec_cmd('fuel --env %s deployment --default --dir %s'
                        % (self.env_id, self.yaml_config_dir))
        if c > 0:
            err('Error: Could not download deployment info for env %s,'
                ' reason: %s\n' % (self.env_id, r))

    def upload_deployment_info(self):
        LOG.debug('Upload deployment info for environment %s\n' % self.env_id)
        r, c = exec_cmd('fuel --env %s deployment --upload --dir %s'
                        % (self.env_id, self.yaml_config_dir))
        if c > 0:
            err('Error: Could not upload deployment info for env %s,'
                ' reason: %s\n' % (self.env_id, r))

    def pre_deploy(self):
        LOG.debug('Running pre-deploy on environment %s\n' % self.env_name)
        self.download_deployment_info()
        opnfv = {'opnfv': {}}

        for node_file in glob.glob('%s/deployment_%s/*.yaml'
                                   % (self.yaml_config_dir, self.env_id)):
             with io.open(node_file) as stream:
                 node = yaml.load(stream)

             if 'opnfv' not in node:
                 node.update(opnfv)

             with io.open(node_file, 'w') as stream:
                 yaml.dump(node, stream, default_flow_style=False)
        self.upload_deployment_info()


    def deploy(self):
        WAIT_LOOP = 180
        SLEEP_TIME = 60

        self.pre_deploy()

        log_file = 'cloud.log'

        LOG.debug('Starting deployment of environment %s\n' % self.env_name)
        run_proc('fuel --env %s deploy-changes | strings | tee %s'
                 % (self.env_id, log_file))

        ready = False
        for i in range(WAIT_LOOP):
            env = parse(exec_cmd('fuel env --env %s' % self.env_id))
            LOG.debug('Environment status: %s\n' % env[0][E['status']])
            r, _ = exec_cmd('tail -2 %s | head -1' % log_file)
            if r:
                LOG.debug('%s\n' % r)
            if env[0][E['status']] == 'operational':
                ready = True
                break
            else:
                time.sleep(SLEEP_TIME)
        exec_cmd('rm %s' % log_file)

        if ready:
            LOG.debug('Environment %s successfully deployed\n' % self.env_name)
        else:
            err('Deployment failed, environment %s is not operational\n'
                % self.env_name)
