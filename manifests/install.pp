# == Class: graphite::install
#
# This class installs graphite packages via pip
#
# === Parameters
#
# None.
#
class graphite::install inherits graphite::params {
  # # Validate
  if $caller_module_name != $module_name {
    fail("Use of private class ${name} by ${caller_module_name}")
  }

  if $::graphite::gr_pip_install and $::osfamily == 'RedHat' {
    validate_re($::operatingsystemrelease, '^[6-7]\.\d+', "Unsupported RedHat release: '${::operatingsystemrelease}'")
  }

  # # Set class variables
  $gr_pkg_provider = $::graphite::gr_pip_install ? {
    default => undef,
    true    => 'pip',
  }

  if $::graphite::gr_manage_python_packages {
    $gr_pkg_require = $::graphite::gr_pip_install ? {
      default => undef,
      true    => [
        Package[$::graphite::params::graphitepkgs],
        Package[$::graphite::params::python_pip_pkg],
        Package[$::graphite::params::python_dev_pkg],
        ],
    } } else {
    $gr_pkg_require = $::graphite::gr_pip_install ? {
      default => undef,
      true    => [Package[$::graphite::params::graphitepkgs],],
    } }

  $carbon = "carbon-${::graphite::gr_carbon_ver}-py${::graphite::params::pyver}.egg-info"
  $gweb   = "graphite_web-${::graphite::gr_graphite_ver}-py${::graphite::params::pyver}.egg-info"

  # # Manage resources

  # for full functionality we need these packages:
  # madatory: python-cairo, python-django, python-twisted,
  #           python-django-tagging, python-simplejson
  # optional: python-ldap, python-memcache, memcached, python-sqlite

  ensure_packages($::graphite::params::graphitepkgs, {
      before => Package['carbon']
  })

  create_resources('package', {
    'carbon'         => {
      ensure => $::graphite::gr_carbon_ver,
      name   => $::graphite::gr_carbon_pkg,
    }
    ,
    'django-tagging' => {
      ensure => $::graphite::gr_django_tagging_ver,
      name   => $::graphite::gr_django_tagging_pkg,
    }
    ,
    'graphite-web'   => {
      ensure => $::graphite::gr_graphite_ver,
      name   => $::graphite::gr_graphite_pkg,
    }
    ,
    'pyparsing'   => {
      ensure => '2.1.5',
      name   => 'pyparsing',
    }
    ,
    'twisted'        => {
      ensure => $::graphite::gr_twisted_ver,
      name   => $::graphite::gr_twisted_pkg,
      before => [
        Package['txamqp'],
        Package['carbon'],
        ],
    }
    ,
    'txamqp'         => {
      ensure => $::graphite::gr_txamqp_ver,
      name   => $::graphite::gr_txamqp_pkg,
    }
    ,
    'whisper'        => {
      ensure => $::graphite::gr_whisper_ver,
      name   => $::graphite::gr_whisper_pkg,
    }
    ,
  }
  , {
    provider => $gr_pkg_provider,
    require  => $gr_pkg_require,
  }
  )

  file { '/opt/graphite/src':
    ensure  => directory,
    require => Package['graphite-web', 'pyparsing'],
  }

  # Temporary hack to overwrite the pip installed graphite-web with prerelease version .10 from github
  # We should pull this out and revert back to using the upstream puppet-graphite once .10 is released
  vcsrepo { 'graphite-web':
    ensure   => present,
    provider => 'git',
    path     => '/opt/graphite/src/graphite-web',
    source   => 'https://github.com/graphite-project/graphite-web.git',
    revision => '92bd68a9384eaac43b775744e54ceb6b972ae589',
    require  => File['/opt/graphite/src'],
  }
  exec { 'replace-webapp-dir':
    command => '/bin/cp -a /opt/graphite/src/graphite-web/webapp/* /opt/graphite/webapp/ && /usr/bin/touch /opt/graphite/webapp/.replace-webapp-dir-do-not-delete',
    creates => '/opt/graphite/webapp/.replace-webapp-dir-do-not-delete',
    require => Vcsrepo['graphite-web'],
  }

  if $::graphite::gr_django_pkg {
    package { $::graphite::gr_django_pkg:
      ensure   => $::graphite::gr_django_ver,
      provider => $::graphite::gr_django_provider,
    }
  }

  if $::graphite::gr_pip_install {
    # using the pip package provider requires python-pip
    # also install python headers and libs for pip
    if $::graphite::gr_manage_python_packages {
      ensure_packages(flatten([
        $::graphite::params::python_pip_pkg,
        $::graphite::params::python_dev_pkg,
        ]))
    }

    # hack unusual graphite install target
    create_resources('file', {
      'carbon_hack' => {
        path   => "${::graphite::params::libpath}/${carbon}",
        target => "${::graphite::base_dir_REAL}/lib/${carbon}"
      }
      ,
      'gweb_hack'   => {
        path   => "${::graphite::params::libpath}/${gweb}",
        target => "${::graphite::base_dir_REAL}/webapp/${gweb}"
      }
      ,
    }
    , {
      ensure  => 'link',
      require => Package[
        'carbon', 'graphite-web', 'whisper'],
    }
    )
  }
}
