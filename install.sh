#!/bin/bash
#install bif
mkdir /etc/bif
touch /etc/bif/rules.iptables
cp ./bif.init /etc/network/if-pre-up.d/bif
chmod 755 /etc/network/if-pre-up.d/bif
cp ./bif.sh  /usr/sbin/bif
chmod 755 /usr/sbin/bif
cp ./bif.conf /etc/bif/bif.conf
