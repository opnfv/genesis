class opnfv::libnss {
  if $::osfamily == 'Debian' {
    case $::fuel_settings['role'] {
      /controller/: {
        package { 'libnss3':
          ensure => installed,
        }
      }
    }
  }
}
