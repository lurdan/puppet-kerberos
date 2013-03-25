# "krb5_newrealm" needs to be exected by hand.
class kerberos (
  $realm
  ) {

  case $::operatingsystem {
    /(?i-mx:debian|ubuntu)/: {
      package { 'krb5-config':
        responsefile => defined(Apt::Preseed['krb5-config']) ? {
          true => '/var/cache/debconf/krb5-config.preseed',
          default => false,
        },
        before => Concat['/etc/krb5.conf'],
      }
    }
    /(?i-mx:redhat|centos)/: {
      package { 'krb5-libs':
        before => Concat['/etc/krb5.conf'],
      }
    }
  }
  anchor {
    'kerberos::config::package::end':
  }

  concat { '/etc/krb5.conf':
    mode => 744, owner => root, group => 0,
    before => Anchor['kerberos::config::package::end'],
  }
}

class kerberos::kdc ( $admin = false ) {
  package { 'krb5-kdc':
    before => Service['krb5-kdc'],
  }

  service { 'krb5-kdc':
    ensure => $active ? {
      true => running,
      default => stopped,
    },
    enable => $active,
    require => Concat['/etc/krb5.conf'],
  }

  if $admin {
    package {'krb5-admin-server':
      before => Service['krb5-admin-server'],
    }
    service {'krb5-admin-server':
      ensure => $active ? {
        true => running,
        default => stopped,
      },
      enable => $active,
      require => Concat['/etc/krb5.conf'],
    }

    concat { '/etc/krb5kdc/kadm5.acl':
      mode => 600, owner => root, group => 0,
      require => Package['krb5-admin-server'],
      notify => Service['krb5-admin-server'];
    }
  }

}

class kerberos::kpropd (
  $active = false
  ) {
  file { '/etc/init.d/kpropd':
    owner => root, group => 0, mode => 755,
    source => 'puppet:///modules/kerberos/kpropd.init',
  }

  concat { '/etc/krb5kdc/kpropd.acl':
    mode => 600, owner => root, group => 0,
    require => Package['krb5-kdc'],
    notify => Service['kpropd'],
  }

  service { 'kpropd':
    ensure => $active ? {
      true => running,
      default => stopped,
    },
    enable => $active,
    require => File['/etc/init.d/kpropd'],
  }
}

define kerberos::config ( $content, $order = '50' ) {
  concat::fragment { "kerberos-config-${name}":
    target => '/etc/krb5.conf',
    content => $content,
    order => $order,
  }
}

define kerberos::acl ( $target = 'kadm5', $content ) {
  concat::fragment {
    "kerberos-acl-${name}":
      target => "/etc/krb5kdc/${target}.acl",
      content => $content,
  }
}

define kerberos::acl::kpropd ( $content ) {
  kerberos::acl { "kpropd-${name}":
    target => 'kpropd',
    content => $content,
  }
}

