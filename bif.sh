#!/bin/bash
# bif - yet another silly Basic Iptables Firewall setter that you should not use
# g0, 2011 - http://ipduh.com/contact

BIFCONF="/etc/bif/bif.conf"
BIFSH="/usr/sbin/bif"
SAVEDRULES="/etc/bif/rules.iptables"

. ${BIFCONF}

# Paths to the programs used
IPTABLES="/sbin/iptables"
IPTABLES_SAVE="/sbin/iptables-save"
EGREP="/bin/egrep"
AWK="/usr/bin/awk"
WGET="/usr/bin/wget"
SORT="/usr/bin/sort"
UNIQ="/usr/bin/uniq"
SED="/bin/sed"
TR="/usr/bin/tr"
ECHO="/bin/echo"

########

function allow_udp_for_all {
#Allow inbound connections to the UDP daemons listening on the ports defined at the OPEN_INBOUND_UDP list
if [ -n "$OPEN_INBOUND_UDP" ] ; then
for UDP_PORT in $OPEN_INBOUND_UDP; do
        ${IPTABLES} -A INPUT -p udp --dport ${UDP_PORT} -j ACCEPT
        ${IPTABLES} -A INPUT -m state --state NEW -p udp --dport ${UDP_PORT} -j ACCEPT
done
fi
}

########

function allow_tcp_for_all {
#Allow inbound connections to the TCP daemons listening on the ports defined at the OPEN_INBOUND_TCP list
if [ -n "$OPEN_INBOUND_TCP" ] ; then
for TCP_PORT in $OPEN_INBOUND_TCP; do
        ${IPTABLES} -A INPUT -p tcp --dport ${TCP_PORT} -j ACCEPT
done
fi
}

########

function drop_bad {
# Block Bad IP addresses and sets of IP addresses in CIDR notation
if [ -e "$BIF_BAD_IP_FILE" ] ; then

        if [ -n "$BIF_BLOCKED_HTML" ]; then
                echo "<html><head><title>IP blocked by bif</title></head><body><br /><br />" > ${BIF_BLOCKED_HTML}
        fi

        for BAD_IP in `${EGREP} -v '^#|^$' ${BIF_BAD_IP_FILE} | ${AWK} -F "," '{print $1}' | ${SORT} | ${UNIQ} | ${EGREP} -v ${WHITE_LIST} | ${TR} -d ' '`; do
           ${IPTABLES} -A OUTPUT -d ${BAD_IP} -j DROP
           ${IPTABLES} -A INPUT -s ${BAD_IP} -j DROP
           ${IPTABLES} -A INPUT -p udp -s ${BAD_IP} -j DROP
           ${IPTABLES} -A INPUT -p udp -d ${BAD_IP} -j DROP

        	if [ -n "$BIF_BLOCKED_HTML" ]; then
                   echo "<a href=http://ipduh.com/apropos/?${BAD_IP}>${BAD_IP}</a><br/>" >> ${BIF_BLOCKED_HTML}
        	fi

        done

        if [ -n "$BIF_BLOCKED_HTML" ]; then
                echo "</body></html>" >> ${BIF_BLOCKED_HTML}
        fi
fi
}

########

function allow_41 {
# Allow ipv6 ICMP and inbound proto 41 ipv6 tunnel traffic from the ipv6 tunnel PoP
${IPTABLES} -A INPUT -p icmpv6 -j ACCEPT
if [ -n "${ALLOW_P41}" ]; then
	for ALLOW_P41_IP in ${ALLOW_P41}; do
		${IPTABLES} -A INPUT -p ipv6 -s ${ALLOW_P41_IP} -j ACCEPT
	done
fi
}

########

function just_me {
# Puch Holes for JUST_ME
if [ -n "$JUST_ME" ] ; then

	for JUST_ME_IP in $JUST_ME; do

	   if [ -n "$TCP_JUST_ME" ] ; then
	   for TCP_PORT_X in $TCP_JUST_ME; do
     	      ${IPTABLES} -A INPUT -p tcp --dport ${TCP_PORT_X} -s ${JUST_ME_IP} -j ACCEPT
	    done
	    fi

	    if [ -n "$UDP_JUST_ME" ] ; then
	    for UDPPORT_X in $UDP_JUST_ME; do
               ${IPTABLES} -A INPUT -p udp --dport ${UDPPORT_X} -s ${JUST_ME_IP} -j ACCEPT
               ${IPTABLES} -A INPUT -m state --state NEW -p udp --dport ${UDPPORT_X} -s ${JUST_ME_IP} -j ACCEPT
	     done
	     fi
	done
fi

}

########

function accounting {
#
if [ -n "${ACCOUNT_FOR}" ] ; then

	for ACCOUNT_FOR_IP in ${ACCOUNT_FOR}; do
	   ${IPTABLES} -I INPUT -d ${ACCOUNT_FOR_IP}
	   ${IPTABLES} -I OUTPUT -s ${ACCOUNT_FOR_IP}
	done
fi

}

########

function allow_icmp_for {

if [ -n "${ALLOW_ICMP_FOR}" ]; then

	for ALLOW_ICMP_FOR_IP in ${ALLOW_ICMP_FOR}; do
	   ${IPTABLES} -A INPUT -p icmp -d ${ALLOW_ICMP_FOR} -j ACCEPT
	done

fi

}

########

function allow_ping_from {
# Play ping pong with IP in ALLOW_PING_FROM
if [ -n "${ALLOW_PING_FROM}" ]; then
   for PING_FROM_IP in ${ALLOW_PING_FROM};do
	${IPTABLES} -A INPUT -p icmp -m icmp --icmp-type echo-request -s ${PING_FROM_IP} -j ACCEPT
	${IPTABLES} -A OUTPUT -p icmp -m icmp --icmp-type echo-reply -s ${PING_FROM_IP} -j ACCEPT
   done
fi
}

########
function nat {

if [ -n "${ALLOW_NAT}" ]; then
  ${ECHO} 1 > /proc/sys/net/ipv4/ip_forward
  ${IPTABLES} -A FORWARD -i ${LAN} -s ${ALLOW_NAT} -j ACCEPT
  ${IPTABLES} -A FORWARD -o ${LAN} -s ${ALLOW_NAT} -j ACCEPT
  ${IPTABLES} -t nat -A POSTROUTING -o ${WAN} -j MASQUERADE -s ${ALLOW_NAT}

  if [ -n "${LAN_SRV_IP}" ]; then
     for TCPORT in ${LAN_SRV_TCP_PORT}; do
        ${IPTABLES} -t nat -A PREROUTING -i ${WAN} -p tcp --dport ${TCPORT} -j DNAT --to ${LAN_SRV_IP}:${TCPORT}
     done

     for UDPORT in ${LAN_SRV_UDP_PORT}; do
        ${IPTABLES} -t nat -A PREROUTING -i ${WAN} -p udp --dport ${UDPORT} -j DNAT --to ${LAN_SRV_IP}:${UDPORT}
     done
  fi

fi

}

###Go###

if ! [ -x ${IPTABLES} ]; then
     echo "bif: I cannot use /sbin/iptables"
     exit 0
fi

if [ -n "$BAD_IP_URL" ]; then
     ${WGET} ${BAD_IP_URL} -O ${BIF_BAD_IP_FROM_URL}
fi



#Flush
$IPTABLES -F
$IPTABLES -t nat -F
$IPTABLES -t mangle -F
$IPTABLES -t raw -F

#Accept Multicast
$IPTABLES -A INPUT  -d 224.0.0.0/4  -m state --state NEW  -j ACCEPT

#Set a liberal-permissive OUTPUT Policy -- Remember that firewalls were not invented to be liberal
#$IPTABLES -P OUTPUT -j ACCEPT
$IPTABLES -A OUTPUT -j ACCEPT -o lo

#Allow outbound connections -- You should disable or further specify this if you are a reasonably paranoid admin
$IPTABLES -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

#Drop NEW tcp that does not start with SYN packets
$IPTABLES -A INPUT -p tcp ! --syn -m state --state NEW -j DROP

#Drop second and further fragments of fragmented packets
$IPTABLES -A INPUT -f -j DROP

#Drop XMAS traffic
$IPTABLES -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

#Drop Null packets
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

#Allow all loopback traffic and drop politely all traffic to 127/8 that does not go through lo
$IPTABLES -A INPUT -i lo -j ACCEPT
$IPTABLES -A INPUT ! -i lo -d 127.0.0.0/8 -j REJECT

#accounting

#drop_bad

just_me

allow_icmp_for

nat

allow_ping_from

allow_41

allow_tcp_for_all

allow_udp_for_all

#Log outbound connections.
#${IPTABLES} -A OUTPUT -j LOG

#Log Inbound connections useful when debuging
#${IPTABLES} -A INPUT -j LOG

#Drop the rest, bif is not polite
${IPTABLES} -A INPUT -j DROP

${IPTABLES_SAVE} > ${SAVEDRULES}

# vi:syntax=sh
