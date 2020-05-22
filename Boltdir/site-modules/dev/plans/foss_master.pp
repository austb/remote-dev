plan dev::foss_master(
  Variant[Target,String] $master,
  Optional[String] $collection = "puppet6",
  Optional[String] $puppetdb_version = "latest",
  Optional[Array[String, 1]] $autosign_whitelist,
  Optional[String] $default_modules = '',
) {
  $target = get_targets($master)[0]

  # Install the Puppet Platform repo and puppet-agent
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
  run_command('/opt/puppetlabs/bin/puppet module install puppetlabs-puppetdb', $target)

  unless $default_modules == '' {
    $default_modules.split(',').each | String $module | {
      run_command("/opt/puppetlabs/bin/puppet module install $module", $target)
    }
  }

  # Run puppet agent to ensure proper setup and signed certs
  run_command('/opt/puppetlabs/bin/puppet agent -t', $target)

  # Configure the modulepath to look in site-modules as well
  run_command("echo 'modulepath = site-modules:modules:\$basemodulepath' > /etc/puppetlabs/code/environments/production/environment.conf", $target)

  # Upload the master profile
  run_command('mkdir -p /etc/puppetlabs/code/environments/production/site-modules/profile/manifests', $target)
  upload_file('dev/master.pp', '/etc/puppetlabs/code/environments/production/site-modules/profile/manifests/master.pp', $target)

  $autosign_whitelist_content = $autosign_whitelist ? {
    undef    => '',
    default  => join($autosign_whitelist, "\n"),
  }

  $include_statement = $default_modules == '' ? {
    true    => '',
    default => $default_modules.split(',').map |String $module| {
      "include ${module.split('-')[1]}"
    }.join("\n  ")
  }

  # Set the hiera data for the master's profile
  run_command('mkdir -p /etc/puppetlabs/code/environments/production/data/nodes', $target)
  run_command("cat >> '/etc/puppetlabs/code/environments/production/data/nodes/$master.yaml' <<EOF
---
profile::master::puppetdb_version: '$puppetdb_version'
profile::master::autosign_whitelist_content: \"$autosign_whitelist_content\"
EOF", $target)

  # Include the master profile via site.pp
  run_command("cat >> /etc/puppetlabs/code/environments/production/manifests/site.pp <<EOF
node '$master' {
  include 'profile::master'
  $include_statement
}

node default {
  $include_statement
}
EOF", $target)

  run_command("/opt/puppetlabs/bin/puppet agent --onetime --verbose --no-daemonize --no-usecacheonfailure --no-splay --show_diff", $target)

  # Install and configure the puppetdb cli
  run_command("/opt/puppetlabs/puppet/bin/gem install --bindir /opt/puppetlabs/bin puppetdb_cli", $target)

  run_command('mkdir -p $HOME/.puppetlabs/client-tools/; fqdn="$(facter fqdn)"; cat > "$HOME/.puppetlabs/client-tools/puppetdb.conf" <<EOF
{
  "puppetdb": {
    "server_urls": "https://$fqdn:8081",
    "cacert": "/etc/puppetlabs/puppet/ssl/certs/ca.pem",
    "cert": "/etc/puppetlabs/puppet/ssl/certs/$fqdn.pem",
    "key": "/etc/puppetlabs/puppet/ssl/private_keys/$fqdn.pem"
  }
}
EOF', $target)
}
