#!/bin/bash
#install bif

cp ./bif.init /etc/network/if-pre-up.d/bif
chmod 755 /etc/network/if-pre-up.d/bif
cp ./bif.sh  /etc/bif
chmod 755 /etc/bif

