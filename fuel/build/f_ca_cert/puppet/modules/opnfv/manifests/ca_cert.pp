class opnfv::ca_cert {
  if $::osfamily == 'Debian' {
    case $::fuel_settings['role'] {
      /controller/: {
        package { 'ca-certificates':
          ensure => installed,
        }
      }
    }
  }
}
