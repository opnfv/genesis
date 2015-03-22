#Copyright 2015 Open Platform for NFV Project, Inc. and its contributors
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.


class opnfv::repo {
  if $::osfamily == 'RedHat' {
    if $proxy_address != '' {
      $myline= "proxy=${proxy_address}"
      include stdlib
      file_line { 'yumProxy':
        ensure => present,
        path   => '/etc/yum.conf',
        line   => $myline,
        before => Yumrepo['openstack-juno'],
      }
    }

    yumrepo { "openstack-juno":
      baseurl => "http://repos.fedorapeople.org/repos/openstack/openstack-juno/epel-7/",
      descr => "RDO Community repository",
      enabled => 1,
      gpgcheck => 0,
    }
  }
}
