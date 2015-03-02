class opnfv::jre_head {
  if $::osfamily == 'Debian' {

    case $::fuel_settings['role'] {
      /controller/: {

       package { 'openjdk-8-jre-headless' :
         ensure => installed,
        }

      }
    }
  }
}

