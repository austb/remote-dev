plan dev::foss_master(
  Variant[Target,String] $master,
  Optional[String] $collection = "puppet6",
  Optional[String] $puppetdb_version = "latest",
) {
  $target = get_targets($master)[0]

  # Install the Puppet Platform repo and puppet-agent
  # This could be done with the apply_prep function,
  # but we want to ensure we get the right Puppet Platform
  # repo set up so we install the right versions of puppetserver
  # and puppetdb
  run_task('puppet_agent::install', $target,
                           collection => $collection)

  # Install and start puppetserver
  run_task('package', $target, name   => 'puppetserver',
                               action => 'install')
  run_task('service', $target, name   => 'puppetserver',
                               action => 'start')

  # Configure the fqdn for the master
  run_command('/opt/puppetlabs/bin/puppet config set server "$(/opt/puppetlabs/bin/facter fqdn)"', $target)

  # Install PuppetDB module for availability during puppet apply
  # This would also be done by the apply_prep function, but
  # we leave it in to support `puppet apply` for the manifest as well
  run_command('/opt/puppetlabs/bin/puppet module install puppetlabs-puppetdb', $target)

  # Run puppet agent to ensure proper setup and signed certs
  run_command('/opt/puppetlabs/bin/puppet agent -t', $target)

  # Lookup the puppet confdir, use printf to let Bash expansion drop the newline
  $result = run_command('printf $(/opt/puppetlabs/bin/puppet config print confdir)', $target)

  $target.apply_prep
  apply($target) {
    class { 'dev::master':
      puppetdb_version => $puppetdb_version,
      puppet_confdir   => $result.first.value['stdout'],
    }
  }
}
