#!/bin/bash

GATEWAY=$(ip route | grep eth0 | grep "^default" | awk '{print $3}')

ip route add 162.159.0.0/16 via $GATEWAY

ip route add 192.168.0.0/16 via $GATEWAY
ip route add 172.16.0.0/12 via $GATEWAY
ip route add 10.0.0.0/8 via $GATEWAY

ip route del default
ip route add default dev tun0 metric 1
