#!/usr/bin/env bash

WL_INTERFACE="wlan0"
ET_INTERFACE="eth0"

ipv4_forwarding() {
  [ $# -eq 0 ] && return 1

  local -i is_forwarding=0
  case "${1-}" in
    --true) is_forwarding=1 ;;
    --false) : ;;
  esac

  local forwarding_conf_file tmp_forwarding_conf_file
  forwarding_conf_file="/etc/sysctl.d/99-forwarding.conf"
  tmp_forwarding_conf_file=$(mktemp)

  cat > "$tmp_forwarding_conf_file" << EOT
net.ipv4.ip_forward=${is_forwarding}
EOT

  # only update if the file doesn't exist or has changed
  if [ -f "$forwarding_conf_file" ] && cmp -s "$tmp_forwarding_conf_file" "$forwarding_conf_file"; then
    rm -f "$tmp_forwarding_conf_file"
    return 0
  fi

  mv "$tmp_forwarding_conf_file" "$forwarding_conf_file"
  chmod 644 "$forwarding_conf_file"
  return 0
}

function allow_forwarding() {
  ipv4_forwarding --true
  sudo iptables -t nat -A POSTROUTING -o "$WL_INTERFACE" -j MASQUERADE --random
  sudo iptables -A FORWARD -i "$ET_INTERFACE" -o "$WL_INTERFACE" -j ACCEPT
  sudo iptables -A FORWARD -i "$WL_INTERFACE" -o "$ET_INTERFACE" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  sudo iptables -A FORWARD -j DROP
}

function deny_forwarding() {
  ipv4_forwarding --false
  sudo iptables -t nat -D POSTROUTING -o "$WL_INTERFACE" -j MASQUERADE --random
  sudo iptables -D FORWARD -i "$ET_INTERFACE" -o "$WL_INTERFACE" -j ACCEPT
  sudo iptables -D FORWARD -i "$WL_INTERFACE" -o "$ET_INTERFACE" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  sudo iptables -D FORWARD -j DROP
}

function list_rules() {
  sudo iptables --list --verbose --numeric --line-numbers
  sudo iptables --table nat --list --verbose --numeric --line-numbers
  printf 'IS FORWARDING: %s\n' "$(sysctl net.ipv4.ip_forward | sed -E 's/.*= //g')"
}

case "${1-}" in
  --allow)
    allow_forwarding
    ;;
  --deny)
    deny_forwarding
    ;;
  --list)
    list_rules
    ;;
esac
