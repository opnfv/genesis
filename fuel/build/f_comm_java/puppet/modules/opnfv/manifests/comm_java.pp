class opnfv::comm_java {
  if $::osfamily == 'Debian' {
    case $::fuel_settings['role'] {
      /controller/: {
        package { 'java-common':
          ensure => installed,
        }
      }
    }
  }
}
