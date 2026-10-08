#!/bin/bash
# mc01: Memcached, reachable from other VMs
set -e

dnf install -y epel-release
dnf install -y memcached

# Listen on all interfaces instead of only localhost
sed -i 's/127.0.0.1/0.0.0.0/g' /etc/sysconfig/memcached
systemctl enable memcached
systemctl restart memcached

# Firewall: allow memcached port
systemctl enable --now firewalld
firewall-cmd --permanent --add-port=11211/tcp
firewall-cmd --reload
