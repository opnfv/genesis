class opnfv::libxt {
  if $::osfamily == 'Debian' {
    case $::fuel_settings['role'] {
      /controller/: {
        package { 'libxtst6':
          ensure => installed,
        }
      }
    }
  }
}
