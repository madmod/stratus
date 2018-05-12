#!/bin/vbash

# FIXME: Doesn't work.

source /opt/vyatta/etc/functions/script-template

set -x

configure

set service dhcp-server use-dnsmasq enable

commit
save
exit


configure

set system host-name router-1
set system domain-name int.stratus.inur.sh
set system name-server 127.0.0.1

set service dns forwarding name-server 8.8.8.8
set service dns forwarding name-server 8.8.4.4
set service dns forwarding name-server 1.1.1.1
set service dns forwarding cache-size 1000
set service dns forwarding listen-on eth1
set service dns forwarding listen-on eth1.20

# Don't use the default /etc/hosts file.
set service dns forwarding options no-hosts

# Never forward plain names (without a dot or domain part).
#set service dns forwarding options domain-needed

# Never forward addresses in the non-routed address spaces.
set service dns forwarding options bogus-priv
set service dns forwarding options all-servers

# Add the domain to hostname lookups without a domain.
set service dns forwarding options expand-hosts
set service dns forwarding options domain=int.stratus.inur.sh

# Don't forward the local domain.
set service dns forwarding options local=/int.stratus.inur.sh/

set service dns forwarding options server=/int.stratus.inur.sh/10.1.1.254#5300

set service dhcp-server shared-network-name LAN subnet 10.1.0.0/16 domain-name int.stratus.inur.sh
set service dhcp-server hostfile-update enable

#set service dhcp-server shared-network-name int.stratus.inur.sh subnet 10.1.0.0/16
#set bootfile-server 10.1.1.254:8080
#set bootfile-name /boot.ipxe
#exit

edit service dns forwarding

#set options enable-tftp
#set options tftp-root=/var/lib/tftpboot

# if request comes from older PXE ROM, chainload to iPXE (via TFTP)
set options dhcp-boot=tag:!ipxe,undionly.kpxe
# if request comes from iPXE user class, set tag "ipxe"
set options dhcp-userclass=set:ipxe,iPXE
# point ipxe tagged requests to the matchbox iPXE boot script (via HTTP)
set options dhcp-boot=tag:ipxe,http://matchbox.svc.int.stratus.inur.sh:8080/boot.ipxe
# Verbose logging.
set options log-dhcp
set options log-queries

exit

edit service dhcp-server shared-network-name LAN subnet 10.1.0.0/16

set subnet-parameters "include &quot;/config/scripts/ipxe.conf&quot;;"

set static-mapping node1 ip-address 10.1.10.1
set static-mapping node1 mac-address f4:4d:30:6d:e8:9e
set static-mapping node2 ip-address 10.1.10.2
set static-mapping node2 mac-address 0c:c4:7a:0a:d3:de
set static-mapping node3 ip-address 10.1.10.3
set static-mapping node3 mac-address 0c:c4:7a:0a:d3:c8

exit

edit service dns forwarding

set options host-record=node1.int.stratus.inur.sh,10.1.10.1
set options host-record=node2.int.stratus.inur.sh,10.1.10.2
set options host-record=node3.int.stratus.inur.sh,10.1.10.3

exit

commit
save
exit

 firewall {
     all-ping enable
     broadcast-ping disable
     ipv6-receive-redirects disable
     ipv6-src-route disable
     ip-src-route disable
     log-martians enable
     name WAN_IN {
         default-action drop
         description "WAN to internal"
         rule 10 {
             action accept
             description "Allow established/related"
             state {
                 established enable
                 related enable
             }
         }
         rule 20 {
             action drop
             description "Drop invalid state"
             state {
                 invalid enable
             }
         }
     }
     name WAN_LOCAL {
         default-action drop
         description "WAN to router"
         rule 10 {
             action accept
             description "Allow established/related"
             state {
                 established enable
                 related enable
             }
         }
         rule 20 {
             action drop
             description "Drop invalid state"
             state {
                 invalid enable
             }
         }
     }
     receive-redirects disable
     send-redirects enable
     source-validation disable
     syn-cookies enable
 }
 interfaces {
     ethernet eth0 {
         address dhcp
         description Internet
         duplex auto
         firewall {
             in {
                 name WAN_IN
             }
             local {
                 name WAN_LOCAL
             }
         }
         speed auto
     }
     ethernet eth1 {
         description Local
         duplex auto
         speed auto
     }
     ethernet eth2 {
         description Local
         duplex auto
         speed auto
     }
     ethernet eth3 {
         description Local
         duplex auto
         speed auto
     }
     ethernet eth4 {
         description Local
         duplex auto
         speed auto
     }
     ethernet eth5 {
         duplex auto
         speed auto
     }
     loopback lo {
     }
     switch switch0 {
         address 10.1.0.1/16
         description Local
         mtu 1500
         switch-port {
             interface eth1 {
             }
             interface eth2 {
             }
             interface eth3 {
             }
             interface eth4 {
             }
             vlan-aware disable
         }
     }
 }
 service {
     dhcp-server {
         disabled false
         hostfile-update enable
         shared-network-name LAN {
             authoritative enable
             subnet 10.1.0.0/16 {
                 default-router 10.1.0.1
                 dns-server 10.1.0.1
                 domain-name int.stratus.inur.sh
                 lease 86400
                 start 10.1.1.1 {
                     stop 10.1.255.0
                 }
                 static-mapping dakine {
                     ip-address 10.1.1.254
                     mac-address 0c:4d:e9:a3:7d:ac
                 }
                 static-mapping pi-1.int.stratus.inur.sh {
                     ip-address 10.1.2.1
                     mac-address b8:27:eb:72:59:ea
                 }
                 subnet-parameters "include &quot;/config/scripts/ipxe.conf&quot;;"
             }
         }
         static-arp disable
         use-dnsmasq disable
     }
     dns {
         forwarding {
             cache-size 400
             listen-on switch0
             listen-on eth1
             name-server 8.8.8.8
             name-server 8.8.4.4
             name-server 1.1.1.1
             options no-hosts
             options bogus-priv
             options all-servers
             options expand-hosts
             options address=/matchbox.svc.int.stratus.inur.sh/10.1.1.254
             options log-dhcp
             options enable-tftp
             options tftp-root=/var/lib/tftpboot
             options log-queries
         }
     }
     gui {
         http-port 80
         https-port 443
         older-ciphers enable
     }
     nat {
         rule 5010 {
             description "masquerade for WAN"
             outbound-interface eth0
             type masquerade
         }
     }
     ssh {
         port 22
         protocol-version v2
     }
     ubnt-discover {
         disable
     }
     unms {
         disable
     }
 }
 system {
     domain-name int.stratus.inur.sh
     host-name router-1
     login {
         user admin {
             authentication {
                 plaintext-password ""
             }
             level admin
         }
     }
     name-server 127.0.0.1
     ntp {
         server 0.ubnt.pool.ntp.org {
         }
         server 1.ubnt.pool.ntp.org {
         }
         server 2.ubnt.pool.ntp.org {
         }
         server 3.ubnt.pool.ntp.org {
         }
     }
     static-host-mapping {
         host-name router-1.int.stratus.inur.sh {
             inet 10.1.0.1
         }
     }
     syslog {
         global {
             facility all {
                 level notice
             }
             facility protocols {
                 level debug
             }
         }
     }
     time-zone UTC
 }


sudo -i
mkdir /config/scripts/tftpboot
cd /config/scripts/tftpboot
curl http://boot.ipxe.org/undionly.kpxe -o undionly.kpxe

configure

set service dns forwarding options enable-tftp
set service dns forwarding options tftp-root=/config/scripts/tftpboot

set service dhcp-server shared-network-name LAN subnet 10.1.0.0/16 subnet-parameters "include &quot;/config/scripts/ipxe.conf&quot;;"
#set service dhcp-server shared-network-name LAN subnet 10.1.0.0/16 static-mapping NAME mac-address MACADDR
#set service dhcp-server shared-network-name LAN subnet 10.1.0.0/16 static-mapping NAME ip-address 10.1.0.1

set service dns forwarding options host-record=matchbox.svc.int.stratus.inur.sh,10.1.1.254

commit-confirm
save
exit

sudo /etc/init.d/dnsmasq restart

root@router-1# show service dhcp-server
 disabled false
 global-parameters "option client-arch code 93 = unsigned integer 16;"
 hostfile-update enable
 shared-network-name LAN {
     authoritative enable
     subnet 10.1.0.0/16 {
         bootfile-server 10.1.0.1
         default-router 10.1.0.1
         dns-server 10.1.0.1
         lease 86400
         start 10.1.1.1 {
             stop 10.1.255.255
         }
         static-mapping dakine {
             ip-address 10.1.1.254
             mac-address 0c:4d:e9:a3:7d:ac
         }
         static-mapping node-1 {
             ip-address 10.1.10.1
             mac-address f4:4d:30:6d:e8:9e
         }
         static-mapping node-2 {
             ip-address 10.1.10.2
             mac-address 0c:c4:7a:0a:d3:de
         }
         static-mapping node-3 {
             ip-address 10.1.10.3
             mac-address 0c:c4:7a:0a:d3:c8
         }
         subnet-parameters "include &quot;/config/scripts/ipxe.conf&quot;;"
     }
 }
 static-arp disable
 use-dnsmasq enable
[edit]
root@router-1# show service dns
 forwarding {
     cache-size 1000
     listen-on switch0
     options enable-tftp
     options tftp-root=/config/scripts/tftpboot
     options log-dhcp
     options log-queries
     options dhcp-userclass=set:ipxe,iPXE
     options dhcp-boot=tag:ipxe,http://matchbox.svc.int.stratus.inur.sh:8080/boot.ipxe
     options host-record=matchbox.svc.int.stratus.inur.sh,10.1.1.254
     options cname=k8s.int.stratus.inur.sh,node1.int.stratus.inur.sh
 }
[edit]

root@router-1# show service dhcp-server
 disabled false
 global-parameters "option client-arch code 93 = unsigned integer 16;"
 hostfile-update enable
 shared-network-name LAN {
     authoritative enable
     subnet 10.1.0.0/16 {
         bootfile-server 10.1.0.1
         default-router 10.1.0.1
         dns-server 10.1.0.1
         lease 86400
         start 10.1.1.1 {
             stop 10.1.255.255
         }
         static-mapping dakine {
             ip-address 10.1.1.254
             mac-address 0c:4d:e9:a3:7d:ac
         }
         static-mapping node-1 {
             ip-address 10.1.10.1
             mac-address f4:4d:30:6d:e8:9e
         }
         static-mapping node-2 {
             ip-address 10.1.10.2
             mac-address 0c:c4:7a:0a:d3:de
         }
         static-mapping node-3 {
             ip-address 10.1.10.3
             mac-address 0c:c4:7a:0a:d3:c8
         }
         subnet-parameters "include &quot;/config/scripts/ipxe.conf&quot;;"
     }
 }
 static-arp disable
 use-dnsmasq enable
[edit]
root@router-1# show service dns
forwarding {
  cache-size 1000
  listen-on switch0
  options enable-tftp
  options tftp-root=/config/scripts/tftpboot
  options log-dhcp
  options log-queries
  options dhcp-userclass=set:ipxe,iPXE
  options dhcp-boot=tag:ipxe,http://matchbox.svc.int.stratus.inur.sh:8080/boot.ipxe
  options host-record=matchbox.svc.int.stratus.inur.sh,10.1.1.254
  options host-record=node1.int.stratus.inur.sh,10.1.10.1
  options host-record=node2.int.stratus.inur.sh,10.1.10.2
  options host-record=node3.int.stratus.inur.sh,10.1.10.3
  options cname=k8s.int.stratus.inur.sh,node1.int.stratus.inur.sh
}

root@router-1# show dns
 forwarding {
     cache-size 1000
     listen-on switch0
     options enable-tftp
     options tftp-root=/config/scripts/tftpboot
     options log-dhcp
     options log-queries
     options host-record=matchbox.svc.int.stratus.inur.sh,10.1.1.254
     options host-record=node1.int.stratus.inur.sh,10.1.10.1
     options host-record=node2.int.stratus.inur.sh,10.1.10.2
     options host-record=node3.int.stratus.inur.sh,10.1.10.3
     options cname=k8s.int.stratus.inur.sh,node1.int.stratus.inur.sh
     options dhcp-userclass=set:ipxe,iPXE
     options dhcp-boot=tag:ipxe,http://matchbox.svc.int.stratus.inur.sh:8080/boot.ipxe
 }
[edit service]
root@router-1# show dhcp-server
 disabled false
 global-parameters "option client-arch code 93 = unsigned integer 16;"
 global-parameters "deny bootp;"
 hostfile-update disable
 shared-network-name LAN {
     authoritative enable
     subnet 10.1.0.0/16 {
         default-router 10.1.0.1
         dns-server 10.1.0.1
         lease 86400
         start 10.1.1.1 {
             stop 10.1.255.255
         }
         static-mapping dakine {
             ip-address 10.1.1.254
             mac-address 0c:4d:e9:a3:7d:ac
         }
         static-mapping node-1 {
             ip-address 10.1.10.1
             mac-address f4:4d:30:6d:e8:9e
         }
         static-mapping node-2 {
             ip-address 10.1.10.2
             mac-address 0c:c4:7a:0a:d3:de
         }
         static-mapping node-3 {
             ip-address 10.1.10.3
             mac-address 0c:c4:7a:0a:d3:c8
         }
         subnet-parameters "include &quot;/config/scripts/ipxe.conf&quot;;"
     }
 }
 static-arp disable
 use-dnsmasq enable
[edit service]

set service dhcp-server global-parameters "deny bootp;"
set service dhcp-server global-parameters "include &quot;/config/scripts/ipxe-option-space.conf&quot;;"
set service dhcp-server shared-network-name LAN subnet 10.1.0.0/16 subnet-parameters "include &quot;/config/scripts/ipxe-green.conf&quot;;"
set service dhcp-server shared-network-name LAN authoritative enable

forwarding {
  cache-size 400
  listen-on switch0
  listen-on eth1
  name-server 8.8.8.8
  name-server 8.8.4.4
  name-server 1.1.1.1
  options no-hosts
  options bogus-priv
  options all-servers
  options expand-hosts
  options address=/matchbox.svc.int.stratus.inur.sh/10.1.1.254
  options log-dhcp
  options enable-tftp
  options tftp-root=/var/lib/tftpboot
  options log-queries
}

root@router-1# show service dhcp-server
disabled false
global-parameters "option client-arch code 93 = unsigned integer 16;"
global-parameters "deny bootp;"
global-parameters "include &quot;/config/scripts/ipxe-option-space.conf&quot;;"
shared-network-name LAN {
  authoritative enable
  subnet 10.1.0.0/16 {
    bootfile-name netboot.xyz.kpxe
    bootfile-server 10.1.0.1
    default-router 10.1.0.1
    dns-server 10.1.0.1
    domain-name int.stratus.inur.sh
    lease 86400
    start 10.1.1.1 {
      stop 10.1.255.0
    }
    static-mapping dakine {
      ip-address 10.1.1.254
      mac-address 0c:4d:e9:a3:7d:ac
    }
    static-mapping pi-1.int.stratus.inur.sh {
      ip-address 10.1.2.1
      mac-address b8:27:eb:72:59:ea
    }
    subnet-parameters "include &quot;/config/scripts/ipxe-green.conf&quot;;"
  }
}
static-arp disable

root@router-1# vi /opt/vyatta/etc/dhcpd.conf
# generated by /opt/vyatta/sbin/dhcpd-config.pl

option space ubnt;
option ubnt.unifi-address code 1 = ip-address;

class "ubnt" {
        match if substring (option vendor-class-identifier , 0, 4) = "ubnt";
        option vendor-class-identifier "ubnt";
        vendor-option-space ubnt;
}

ddns-update-style none;

# The following 3 lines were added as global-parameters in the CLI and
# have not been validated
option client-arch code 93 = unsigned integer 16;
deny bootp;
include "/config/scripts/ipxe-option-space.conf";

shared-network LAN {
        authoritative;
        subnet 10.1.0.0 netmask 255.255.0.0 {
                option domain-name-servers 10.1.0.1;
                include "/config/scripts/ipxe-green.conf";
                option routers 10.1.0.1;
                option domain-name "int.stratus.inur.sh";
                option domain-search "int.stratus.inur.sh";
                option bootfile-name "netboot.xyz.kpxe";
                filename "netboot.xyz.kpxe";
                next-server 10.1.0.1;
                default-lease-time 86400;
                max-lease-time 86400;
                host dakine.int.stratus.inur.sh {
                        fixed-address 10.1.1.254;
                        hardware ethernet 0c:4d:e9:a3:7d:ac;
                }
                host pi-1.int.stratus.inur.sh.int.stratus.inur.sh {
                        fixed-address 10.1.2.1;
                        hardware ethernet b8:27:eb:72:59:ea;
                }
                range 10.1.1.1 10.1.1.253;
                range 10.1.1.255 10.1.2.0;
                range 10.1.2.2 10.1.255.0;
        }
}

# Doesn't work for UEFI.
root@router-1# cat /config/scripts/ipxe-green.conf
allow bootp;
allow booting;
next-server 10.1.0.1;
#option ipxe.no-pxedhcp 1;

if exists user-class and option user-class = "iPXE" {
  filename "netboot.xyz.kpxe";
  #filename "http://10.8.8.11/ipxeroot/bootstrap.ipxe";
} elsif option arch = 00:07 {
  filename "netboot.xyz.efi";
  #filename "netboot.xyz.kpxe";
} elsif option arch = 00:00 {
  filename "netboot.xyz-undionly.kpxe";
} else {
  filename "netboot.xyz.efi";
}


set static-mapping node1 ip-address 10.1.10.1
set static-mapping node1 mac-address f4:4d:30:6d:e8:9e
set static-mapping node2 ip-address 10.1.10.2
set static-mapping node2 mac-address 0c:c4:7a:0a:d3:de
set static-mapping node3 ip-address 10.1.10.3
set static-mapping node3 mac-address 0c:c4:7a:0a:d3:c8
set service dns forwarding options host-record=node1.int.stratus.inur.sh,10.1.10.1
set service dns forwarding options host-record=node2.int.stratus.inur.sh,10.1.10.2
set service dns forwarding options host-record=node3.int.stratus.inur.sh,10.1.10.3
