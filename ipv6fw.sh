#!/bin/bash
#ipv6fw.sh , g0 2013 , alog.ipduh.com
#stupid-simple bif.sh style ipv6 firewall 
#using stuff mostly stolen from: 
#http://www.sixxs.net/wiki/IPv6_Firewalling

##change these:
TUNIF='he-ipv6-0' 
BR='br0'
SSHD_HOST='2001:470:1f0a:35d::3'
NAMED_HOST='2001:470:1f0a:35d::3'
HTTPD_HOST='2001:470:1f0a:35d::da'
MAILD_HOST='2001:470:1f0a:35d::da'
MY48='2001:470:7134::/48'
##

IP6TABLES='/sbin/ip6tables'
IP6TABLES_SAVE='/sbin/ip6tables-save'
IP6TABLES_RULES='/etc/rules.ip6tables'

# First, delete all:
${IP6TABLES} -F
${IP6TABLES} -X

# Allow anything on the local link
${IP6TABLES} -A INPUT  -i lo -j ACCEPT
${IP6TABLES} -A OUTPUT -o lo -j ACCEPT

# Allow anything out on the internet
${IP6TABLES} -A OUTPUT -o ${TUNIF} -j ACCEPT
# Allow established, related packets back in
${IP6TABLES} -A INPUT  -i ${TUNIF} -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow the localnet access us:
${IP6TABLES} -A INPUT    -i ${BR} -j ACCEPT
${IP6TABLES} -A OUTPUT   -o ${BR} -j ACCEPT

# Filter all packets that have RH0 headers:
${IP6TABLES} -A INPUT -m rt --rt-type 0 -j DROP
${IP6TABLES} -A FORWARD -m rt --rt-type 0 -j DROP
${IP6TABLES} -A OUTPUT -m rt --rt-type 0 -j DROP

# Allow Link-Local addresses
${IP6TABLES} -A INPUT -s fe80::/10 -j ACCEPT
${IP6TABLES} -A OUTPUT -s fe80::/10 -j ACCEPT

# Allow multicast
${IP6TABLES} -A INPUT -d ff00::/8 -j ACCEPT
${IP6TABLES} -A OUTPUT -d ff00::/8 -j ACCEPT

# Allow ICMPv6 everywhere
${IP6TABLES} -I INPUT  -p icmpv6 -j ACCEPT
${IP6TABLES} -I OUTPUT -p icmpv6 -j ACCEPT
${IP6TABLES} -I FORWARD -p icmpv6 -j ACCEPT

# Allow forwarding
${IP6TABLES} -A FORWARD -m state --state NEW -i ${BR} -o ${TUNIF} -s ${MY48} -j ACCEPT
${IP6TABLES} -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# SSH in
${IP6TABLES} -A FORWARD -i ${TUNIF} -p tcp -d ${SSHD_HOST} --dport 22 -j ACCEPT

# HTTP in https , http
${IP6TABLES} -A FORWARD -i ${TUNIF} -p tcp -d ${HTTPD_HOST} --dport 80 -j ACCEPT
${IP6TABLES} -A FORWARD -i ${TUNIF} -p tcp -d ${HTTPD_HOST} --dport 443 -j ACCEPT

# NAMED in
${IP6TABLES} -A FORWARD -i ${TUNIF} -p tcp -d ${NAMED_HOST} --dport 53 -j ACCEPT
${IP6TABLES} -A FORWARD -i ${TUNIF} -p udp -d ${NAMED_HOST} --dport 53 -j ACCEPT

# MAIL smtp , imap over ssl
${IP6TABLES} -A FORWARD -i ${TUNIF} -p tcp -d ${MAILD_HOST} --dport 25 -j ACCEPT
${IP6TABLES} -A FORWARD -i ${TUNIF} -p tcp -d ${MAILD_HOST} --dport 993 -j ACCEPT

# Set the default policy
${IP6TABLES} -P INPUT   DROP
${IP6TABLES} -P FORWARD DROP
${IP6TABLES} -P OUTPUT  DROP

# save
${IP6TABLES_SAVE} > ${IP6TABLES_RULES}
