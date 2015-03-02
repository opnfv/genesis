class opnfv::gif {
  if $::osfamily == 'Debian' {
    case $::fuel_settings['role'] {
      /controller/: {
        package { 'libgif4':
          ensure => installed,
        }
      }
    }
  }
}
