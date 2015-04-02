class opnfv::odl_docker
{
    case $::fuel_settings['role'] {
      /controller/: {

        file { "/opt":
                ensure => "directory",
             }

        file { "/opt/opnfv":
                ensure => "directory",
                owner => "root",
                group => "root",
                mode => 777,
             }

        file { "/opt/opnfv/odl":
                ensure => "directory",
             }

        file { "/opt/opnfv/odl/odl_docker_image.tar":
                ensure => present,
                source => "/etc/puppet/modules/opnfv/odl_docker/odl_docker_image.tar",
                mode => 750,
             }

        file { "/opt/opnfv/odl/docker-latest":
                ensure => present,
                source => "/etc/puppet/modules/opnfv/odl_docker/docker-latest",
                mode => 750,
             }

        file { "/opt/opnfv/odl/start_odl_conatiner.sh":
                ensure => present,
                source => "/etc/puppet/modules/opnfv/scripts/start_odl_container.sh",
                mode => 750,
             }

        # fix failed to find the cgroup root issue
        # https://github.com/docker/docker/issues/8791
        if $::operatingsystem == 'Ubuntu' {
          package {'cgroup-lite':
            ensure => present,
          }

          service {'cgroup-lite':
            ensure  => running,
            enable  => true,
            require => Package['cgroup-lite'],
          }
        }
  }
 }
}