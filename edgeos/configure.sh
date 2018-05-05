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
set service dns forwarding options domain-needed
set service dns forwarding options bogus-priv
set service dns forwarding options all-servers
set service dns forwarding options no-hosts

set service dhcp-server shared-network-name LAN subnet 10.1.0.0/16 domain-name int.stratus.inur.sh
set service dhcp-server hostfile-update enable

commit
save
exit
