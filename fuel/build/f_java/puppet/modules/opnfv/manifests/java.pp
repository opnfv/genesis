class opnfv::java {
  if $::osfamily == 'Debian' {
    case $::fuel_settings['role'] {
      /controller/: {
        package { 'openjdk-8-jdk':
          ensure => installed,
        }
      }
    }
  }
}
