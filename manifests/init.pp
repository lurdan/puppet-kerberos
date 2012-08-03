# "krb5_newrealm" needs to be exected by hand.
class kerberos (
  $realm,
  $kdc = false,
  $admin = false,
  ) {

  case $::operatingsystem {
    /(?i-mx:debian|ubuntu)/: {
      package { 'krb5-config':
        responsefile => defined(Apt::Preseed['krb5-config']) ? {
          true => '/var/cache/debconf/krb5-config.preseed',
          default => false,
        },
        notify => Concat['/etc/krb5.conf'],
      }
    }
    /(?i-mx:redhat|centos)/: {
      package { 'krb5-libs':
        notify => Concat['/etc/krb5.conf'],
      }
    }
  }

  if $kdc {
    class { 'kerberos::kdc':
      admin => $admin,
      require => Package['krb5-config'];
    }
  }

  concat { '/etc/krb5.conf':
  }
}

class kerberos::kdc ( $admin = false ) {
  package { 'krb5-kdc': }
  service { 'krb5-kdc':
    ensure => $active ? {
      true => running,
      default => stopped,
    },
    enable => $active,
    require => Package['krb5-kdc'],
  }

  if $admin {
    package {'krb5-admin-server': }
    service {'krb5-admin-server':
      ensure => $active ? {
        true => running,
        default => stopped,
      },
      enable => $active,
      require => Package['krb5-admin-server'],
    }
    concat { '/etc/krb5kdc/kadm5.acl':
      require => Package['krb5-admin-server'],
      notify => Service['krb5-admin-server'];
    }
  }

}

class kerberos::kpropd (
  $active = false,
  ) {
  file { '/etc/init.d/kpropd':
    owner => root, group => 0, mode => 755,
    source => 'puppet:///modules/kerberos/kpropd.init',
    require => Class['kerberos::kdc'],
  }

  concat { '/etc/krb5kdc/kpropd.acl':
    require => Class['kerberos::kdc'],
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

