class opnfv::libpcs {
  if $::osfamily == 'Debian' {
    case $::fuel_settings['role'] {
      /controller/: {
        package { 'libpcsclite1':
          ensure => installed,
        }
      }
    }
  }
}
