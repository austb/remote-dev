# Install and configure a monolithic Puppet master with PostgreSQL configured
# for an SSL connection with PuppetDB. Configures fact, catalog, and report
# storage from puppet agent run.
class dev::master (
  String $puppetdb_version,
) {
  class { 'puppetdb::globals':
    version => $puppetdb_version,
  }

  class { 'puppetdb':
    database_host           => $trusted['certname'],
    database_listen_address => '*',
    jdbc_ssl_properties     => '?ssl=true&sslrootcert=/etc/puppetlabs/puppetdb/ssl/ca.pem',
  }

  class { 'puppetdb::master::config':
    manage_report_processor => true,
    enable_reports          => true,
  }

  file {'postgres private key':
    ensure  => present,
    path    => "${postgresql::params::datadir}/server.key",
    source  => "file:///etc/puppetlabs/puppet/ssl/private_keys/${trusted['certname']}.pem",
    owner   => 'postgres',
    mode    => '0600',
    require => Package['postgresql-server'],
  }

  concat {'postgres cert bundle':
    ensure  => present,
    path    => "${postgresql::params::datadir}/server.crt",
    owner   => 'postgres',
    require => Package['postgresql-server'],
  }

  concat::fragment {'agent cert':
    target => 'postgres cert bundle',
    source => "file:///etc/puppetlabs/puppet/ssl/certs/${trusted['certname']}.pem",
    order  => '1',
  }

  concat::fragment {'CA bundle':
    target => 'postgres cert bundle',
    source => 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem',
    order  => '2',
  }

  postgresql::server::config_entry {'ssl_key_file':
    ensure  => present,
    value   => "${postgresql::params::datadir}/server.key",
    require => [File['postgres private key'], Concat['postgres cert bundle']],
  }

  postgresql::server::config_entry {'ssl_cert_file':
    ensure  => present,
    value   => "${postgresql::params::datadir}/server.crt",
    require => [File['postgres private key'], Concat['postgres cert bundle']],
  }

  postgresql::server::config_entry {'ssl':
    ensure  => present,
    value   => 'on',
    require => [File['postgres private key'], Concat['postgres cert bundle']],
  }
}
