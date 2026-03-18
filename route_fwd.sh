#!/usr/bin/env bash

sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE --random
sudo iptables -A FORWARD -i eth0 -o wlan0 -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -j DROP

# sudo iptables -t nat -A POSTROUTING -o my_modem_interface -j MASQUERADE --random
# sudo iptables -A FORWARD -i my_lan_interface -o my_modem_interface -j ACCEPT
# sudo iptables -A FORWARD -i my_modem_interface -o my_lan_interface -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# sudo iptables -A FORWARD -j DROP
