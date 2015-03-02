class opnfv::defjre {
  if $::osfamily == 'Debian' {
    case $::fuel_settings['role'] {
      /controller/: {
        package { 'default-jre':
          ensure => installed,
        }
      }
    }
  }
}
