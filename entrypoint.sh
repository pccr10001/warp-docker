#!/bin/bash


# make sure internet is routed
GATEWAY=$(ip route | grep eth0 | grep "^default" | awk '{print $3}')
ip route del default
ip route add default via $GATEWAY

# start dbus
sudo mkdir -p /run/dbus
if [ -f /run/dbus/pid ]; then
    sudo rm /run/dbus/pid
fi
sudo dbus-daemon --config-file=/usr/share/dbus-1/system.conf

# start the daemon
sudo warp-svc --accept-tos &

# sleep to wait for the daemon to start, default 2 seconds
sleep "$WARP_SLEEP"

# if /var/lib/cloudflare-warp/reg.json not exists, setup new warp client
if [ ! -f /var/lib/cloudflare-warp/reg.json ]; then
    # if /var/lib/cloudflare-warp/mdm.xml not exists or REGISTER_WHEN_MDM_EXISTS not empty, register the warp client
    if [ ! -f /var/lib/cloudflare-warp/mdm.xml ] || [ -n "$REGISTER_WHEN_MDM_EXISTS" ]; then
        warp-cli --accept-tos registration new && echo "Warp client registered!"
        # if a license key is provided, register the license
        if [ -n "$WARP_LICENSE_KEY" ]; then
            echo "License key found, registering license..."
            warp-cli --accept-tos registration license "$WARP_LICENSE_KEY" && echo "Warp license registered!"
        fi
    fi
    # connect to the warp server
    warp-cli --accept-tos connect
else
    echo "Warp client already registered, skip registration"
fi

# disable qlog if DEBUG_ENABLE_QLOG is empty
if [ -z "$DEBUG_ENABLE_QLOG" ]; then
    warp-cli --accept-tos debug qlog disable
else
    warp-cli --accept-tos debug qlog enable
fi

# enable MASQUE protocol
warp-cli --accept-tos tunnel protocol set MASQUE

# set mode to proxy
warp-cli --accept-tos mode proxy

sudo ip tuntap add mode tun dev tun0
echo TUN created.
sudo ip link set dev tun0 up
echo TUN link up.

/opt/routes.sh

sysctl net.ipv6.conf.all.forwarding=1
sysctl net.ipv6.conf.default.forwarding=1
sysctl net.ipv4.ip_forward=1
sysctl net.ipv4.conf.all.forwarding=1

while true; do
  status=$(warp-cli status)
  if [[ "$status" == *"Connected"* ]]; then
    echo "WARP connected successfully"
    break
  else
    echo "WARP not connected yet, waiting..."
    sleep $WARP_SLEEP
  fi
done

sudo /opt/tun2socks /opt/hs5t.yml

