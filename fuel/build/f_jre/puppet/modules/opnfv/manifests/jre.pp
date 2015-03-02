class opnfv::jre {
  if $::osfamily == 'Debian' {


    case $::fuel_settings['role'] {
      /controller/: {
        package { 'openjdk-8-jre':
          ensure => installed,
        }
      }
    }
  }
}

