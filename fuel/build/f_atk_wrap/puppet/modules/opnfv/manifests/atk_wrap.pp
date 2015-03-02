class opnfv::atk_wrap {
  if $::osfamily == 'Debian' {
    case $::fuel_settings['role'] {
      /controller/: {
        package { 'libatk-wrapper-java':
          ensure => installed,
        }
      }
    }
  }
}

