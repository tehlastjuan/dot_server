#!/usr/bin/env bash

# Exit on error, undefined vars, pipe failures
set -euo pipefail

#----- user env

declare ENV_LOCALE="en_US.UTF-8"
declare ENV_TZ="Europe/Stockholm"

#----- work env

declare -i CLEANUP_FLAG=1
declare -i SSH_PORT=22
declare -a SSH_USERS=()

#----- print utils

declare RED=$'\e[0;31m'
declare GRE=$'\e[0;32m'
declare YEL=$'\e[0;33m'
declare BLU=$'\e[0;34m'
#declare PUR=$'\e[0;35m'
#declare CYA=$'\e[0;36m'
#declare BLD=$'\e[1m'
declare NOC=$'\e[0m'

function _prt_msg() {
  local msg="${1:-"This is a message."}"
  printf '%s\n' "$msg"
}

function _prt_init_msg() {
  CLEANUP_FLAG=1
  local msg="${BLU}${1:-"This is a message."}${NOC}"
  printf '%s' "$msg"
}

function _prt_init_msg_nl() {
  CLEANUP_FLAG=1
  local msg="${BLU}${1:-"This is a message."}${NOC}"
  printf '%s\n' "$msg"
}

function _prt_cleared_msg() {
  CLEANUP_FLAG=0
  local msg="${GRE}${1:-"Completed."}${NOC}"
  printf '%s\n' "$msg"
}

function _prt_status_msg() {
  local msg="${RED}${1:-"This is a message."}${NOC}"
  printf '%s\n' "$msg"
}

function _prt_info_msg() {
  local msg="${BLU}${1:-"This is a message."}${NOC}"
  printf '%s' "$msg"
}

function _prt_info_msg_nl() {
  local msg="${BLU}${1:-"This is a message."}${NOC}"
  printf '%s\n' "$msg"
}

function _prt_info_nl_msg_nl() {
  local msg="${BLU}${1:-"This is a message."}${NOC}"
  printf '\n%s\n' "$msg"
}

function _prt_warning() {
  local msg="${YEL}${1:-"Unknown warning."}${NOC}"
  printf '%s' "$msg"
}

function _prt_warning_nl() {
  local msg="${YEL}${1:-"Unknown warning."}${NOC}"
  printf '%s\n' "$msg"
}

function _prt_error() {
  local msg="${RED}${1:-"Unknown error."}${NOC}"
  printf '%s\n' "$msg" && exit 1
}

function _confirm() {
  local _response
  local _prompt="${1-} ${YEL}[y/n]:${NOC} "
  while true; do
    printf "%s" "$_prompt"
    read -r _response
    case ${_response,,} in
      y|"yes") return 0 ;;
      n|"no")  return 1 ;;
      *) : ;;
    esac
  done
}

#----- ssh utils

function _fetch_ssh_port() {
  SSH_PORT=$(( $(lsof -nP -iTCP -sTCP:LISTEN |
    grep -m 1 sshd | cut -d ':' -f 2 | cut -d ' ' -f 1) ))
}

function _validate_ssh_port() {
  [[ "${1-}" =~ ^[0-9]+$ && "${1-}" -ge 1024 && "${1-}" -le 65535 ]]
}

function _validate_ssh_allow_users() {
  [[ "${1-}" =~ ^[a-zA-Z0-9_\ ]+$ ]]
}

function _install_file() {
  # set root read/write only permision
  local _src_file _dst_file
  case $# in
    2)
      local _src_file=${1-}
      local _dst_file=${2-}
      [ -f "${_src_file-}" ] || [ -z "${_dst_file-}" ] || return 1
      install -m 0644 "$_src_file" "$_dst_file"
      ;;
    1)
      local _dst_file=${1-}
      [ -f "${_dst_file-}" ] || return 1
      install -m 0644 "$_dst_file"
      ;;
    *) return 1 ;;
  esac
}

function _install_directory() {
  # set root read/write only permision
  local _src_dir _dst_dir
  case $# in
    2)
      local _src_dir=${1-}
      local _dst_dir=${2-}
      [ -d "${_src_dir-}" ] || [ -z "${_dst_dir-}" ] || return 1
      install -d -m 0755 "$_src_dir" "$_dst_dir"
      ;;
    1)
      local _dst_dir=${1-}
      [ -d "${_dst_dir-}" ] || return 1
      install -d -m 0755 "$_dst_dir"
      ;;
    *) return 1 ;;
  esac
}

declare -a CORE_PKG=(
  ca-certificates
  curl
  wget
  gnupg
  lsb-release
  sudo
  git
  vim
  jq
  lsof
  zip
  unzip
  ssh
  openssh-client
  openssh-server
  xdg-user-dirs
  btop
  tree
)

declare -a UTILS_PKG=(
  apt-listchanges
  coreutils
  xz-utils
  file
  gawk
  perl
  netcat-traditional
  nethogs
  nmap
  ncdu
  rsync
  logrotate
  rsyslog
  skopeo
  sqlite3
)

declare -a DOCKER_PKG_REMOVE=(
  docker
  docker-engine
  docker.io
  docker-ce
  docker-ce-cli
  containerd
  containerd.io
  docker-buildx-plugin
  docker-compose-plugin
  docker-compose
  docker-doc
  podman-docker
  runc
)

declare -a DOCKER_PKG=(
  docker-ce
  docker-ce-cli
  containerd.io
  docker-buildx-plugin
  docker-compose-plugin
)

#----- install utils

function _check_installed_pkg() {
  dpkg-query --show --showformat='${Status}\n' "${1-}" &> /dev/null
  return $?
}

function _install_single_pkg() {
  [ $# -eq 0 ] || [ -z "${1-}" ] &&
    { _prt_error "No package defined."; return 1; }

  _prt_init_msg "Installing '${1}' package... "
  ! _check_installed_pkg "${1}" ||
    { _prt_cleared_msg "'${1}' already installed."; return 0; }

  apt install -y -qq --no-install-recommends "$1" ||
    _prt_error "Failed to install '${1}' package."
  _prt_cleared_msg
}

function _install_systemd_unit() {
  if ! systemctl daemon-reload; then
    _prt_error "Unable to reload systemd daemons."; return 1
  fi

  if ! systemctl is-enabled --quiet "${1-}"; then
    _prt_init_msg "Enabling '${1-}' systemd unit... "
    systemctl enable --now "${1-}"
  else
    _prt_init_msg "Restarting '${1-}' systemd unit... "
    systemctl restart "${1-}"
  fi
  _prt_cleared_msg
  systemctl status "${1-}" --no-pager
}

#----- 

function _check_debian_version() {
  . /etc/os-release
  if [ "${ID:-}" != "debian" ]; then
    _prt_error "Not Debian."
  fi
  if [ "${VERSION_CODENAME:-}" != "trixie" ]; then
    _prt_error "Not Debian trixie."
  fi
}

function _configure_debian_sources() {
  _prt_init_msg "Configuring Debian package sources... "

  local _deb_sources="/etc/apt/sources.list.d/debian.sources"
  local _deb_sources_list="/etc/apt/sources.list"
  local _deb_example_sources="/usr/share/doc/apt/examples/debian.sources"

  # from: https://wiki.debian.org/SourcesList
  if [ ! -f "$_deb_sources" ]; then
    if [ -f "$_deb_example_sources" ]; then
      _install_file "$_deb_example_sources" "$_deb_sources"
    else
      cat << EOF > "$_deb_sources"
Types: deb deb-src
URIs: https://deb.debian.org/debian
Suites: trixie trixie-updates
## If you want access to contrib and non-free components,
## add " contrib non-free" after "non-free-firmware":
Components: main non-free-firmware
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: https://security.debian.org/debian-security
Suites: trixie-security
Components: main non-free-firmware
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
    fi
    if [ -f "$_deb_sources_list" ]; then
      sed -i -e 's/^\(deb.*\)/# \1/' /etc/apt/sources.list
    fi
  fi
  _prt_cleared_msg
}

function _update_system() {
  _prt_init_msg_nl "Updating system packages... "
  apt update || _prt_error "Failed to update system packages."
  apt upgrade -y -qq --no-install-recommends ||
    _prt_error "Failed to update system packages."
  _prt_cleared_msg
}

function _clean_system {
  _prt_init_msg_nl "Cleaning system packages... "
  apt autoclean -y -qq ||
    _prt_error "'apt autoclean -y -qq' command failed."
  apt autoremove -y -qq --purge ||
    _prt_error "'apt autoremove -y -qq --purge' command failed."
  apt distclean -y -qq ||
    _prt_error "'apt distclean -y -qq' command failed."
  _prt_cleared_msg
}

function _install_core_pkg() {
  _prt_init_msg_nl "Installing core packages... "
  apt install -y -qq --no-install-recommends "${CORE_PKG[@]}" ||
    _prt_error "Failed to install one or more packages."
  _prt_cleared_msg
}

function _install_utils_pkg() {
  _prt_init_msg_nl "Installing utility packages... "
  apt install -y -qq --no-install-recommends "${UTILS_PKG[@]}" ||
    _prt_error "Failed to install one or more packages."
  _prt_cleared_msg
}

function _install_docker_pkg() {
  _prt_init_msg_nl "Installing docker packages... "
  apt-get install -y -qq --no-install-recommends "${DOCKER_PKG[@]}" ||
    _prt_error "Failed to install one or more packages."
  _prt_cleared_msg
}

#----- locale

function _update_locale() {
  _prt_init_msg_nl "Updating locale... "
  if ! _check_installed_pkg locales; then
    _install_single_pkg locales
  fi

  local _locales_gen="/etc/locale.gen"
  local _locale="en_US.UTF-8"

  if [[ "${LANG:-}" != "$ENV_LOCALE" ]]; then
    if [ ! -f "$_locales_gen" ]; then
      _prt_error "file '${_locales_gen}' not found."
    fi
    sudo sed -E -i '/en_US.UTF-8 UTF-8/s/^# //g' "$_locales_gen" &&
      DEBIAN_FRONTEND=noninteractive \
      dpkg-reconfigure --frontend=noninteractive locales

    _prt_cleared_msg
  else
    _prt_cleared_msg "Locale already set to en_US.UTF-8."
  fi
}

#----- systemd-resolved conf

function _setup_systemd_resolved() {
  _prt_init_msg "Configuring systemd-resolved... "
  if ! _check_installed_pkg systemd-resolved; then
    _install_single_pkg systemd-resolved
  fi

  local _resolved_conf="/etc/systemd/resolved.conf"
  local _tmp_resolved_conf _ori_resolved_conf _ori_header_resolved_conf
  _tmp_resolved_conf=$(mktemp /tmp/resolved.conf_XXXXXX)
  _ori_resolved_conf=$(mktemp /tmp/ori_resolved.conf_XXXXXX)
  _ori_header_resolved_conf=$(mktemp /tmp/ori_header_resolved.conf_XXXXXX)

  trap 'rm -f "$_tmp_resolved_conf"' EXIT
  trap 'rm -f "$_ori_resolved_conf"' EXIT
  trap 'rm -f "$_ori_header_resolved_conf"' EXIT

  if [ -f "$_resolved_conf" ]; then
    cat "$_resolved_conf" |
      sed '/\[Resolve\]/,$d' > "$_ori_header_resolved_conf"
    cat "$_resolved_conf" |
      sed '/\[Resolve\]/,$!d' > "$_ori_resolved_conf"
  else
    cat << EOT > "$_ori_header_resolved_conf"
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it under the
#  terms of the GNU Lesser General Public License as published by the Free
#  Software Foundation; either version 2.1 of the License, or (at your option)
#  any later version.
#
# Entries in this file show the compile time defaults. Local configuration
# should be created by either modifying this file (or a copy of it placed in
# /etc/ if the original file is shipped in /usr/), or by creating "drop-ins" in
# the /etc/systemd/resolved.conf.d/ directory. The latter is generally
# recommended. Defaults can be restored by simply deleting the main
# configuration file and all drop-ins located in /etc/.
#
# Use 'systemd-analyze cat-config systemd/resolved.conf' to display the full config.
#
# See resolved.conf(5) for details.

EOT
  fi

  cat << EOT > "$_tmp_resolved_conf"
[Resolve]

#Domains=~.
DNSSEC=no
DNSOverTLS=no
#DNSSEC=allow-downgrade
#DNSOverTLS=opportunistic
#DNSCacheSize=4096
#DNSStubListener=yes
#DNSStubListenerExtra=

# Cloudflare
FallbackDNS=1.1.1.1#cloudflare-dns.com
FallbackDNS=2606:4700:4700::1111#cloudflare-dns.com
FallbackDNS=1.0.0.1#cloudflare-dns.com
FallbackDNS=2606:4700:4700::1001#cloudflare-dns.com

# Quad9
FallbackDNS=9.9.9.9#dns.quad9.net
FallbackDNS=2620:fe::fe#dns.quad9.net
FallbackDNS=149.112.112.112#dns.quad9.net
FallbackDNS=2620:fe::9#dns.quad9.net

LLMNR=no
#LLMNRCacheSize=4096

MulticastDNS=yes
#MulticastDNSCacheSize=4096

#Cache=yes
#CacheFromLocalhost=no

#ReadEtcHosts=yes
#ReadStaticRecords=yes

#RefuseRecordTypes=
#ResolveUnicastSingleLabel=no
#StaleRetentionSec=0

EOT

  if [ ! -f "$_resolved_conf" ] || {
    [ -f "$_resolved_conf" ] && ! cmp -s "$_tmp_resolved_conf" "$_ori_resolved_conf"; }; then
    _prt_status_msg "CHANGED "
    cat "$_tmp_resolved_conf" >> "$_ori_header_resolved_conf"
    _install_file "$_ori_header_resolved_conf" "$_resolved_conf"
    systemctl daemon-reload
    systemctl restart systemd-resolved.service
    sleep 2
  fi

  rm -f "$_tmp_resolved_conf"
  rm -f "$_ori_resolved_conf"
  rm -f "$_ori_header_resolved_conf"
  _prt_cleared_msg
}

function _setup_systemd_timesync() {
  _prt_init_msg "Configuring systemd-timesyncd... "
  if ! _check_installed_pkg systemd-timesyncd; then
    _install_single_pkg systemd-timesyncd
  fi

  local _timesyncd_conf="/etc/systemd/timesyncd.conf"
  local _tmp_timesyncd_conf _ori_timesyncd_conf _ori_header_timesyncd_conf

  _tmp_timesyncd_conf=$(mktemp /tmp/tmp_timesyncd.conf_XXXXXX)
  _ori_timesyncd_conf=$(mktemp /tmp/ori_timesyncd.conf_XXXXXX)
  _ori_header_timesyncd_conf=$(mktemp /tmp/ori_header_timesyncd.conf_XXXXXX)

  trap '$(rm -f "${_tmp_timesyncd_conf-}")' EXIT
  trap '$(rm -f "${_ori_timesyncd_conf-}")' EXIT
  trap '$(rm -f "${_ori_header_timesyncd_conf-}")' EXIT

  if [ -f "$_timesyncd_conf" ]; then
    cat "$_timesyncd_conf" |
      sed '/\[Time\]/,$d' > "$_ori_header_timesyncd_conf"
    cat "$_timesyncd_conf" |
      sed '/\[Time\]/,$!d' > "$_ori_timesyncd_conf"
  else
    cat << EOT > "$_ori_header_timesyncd_conf"
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it under the
#  terms of the GNU Lesser General Public License as published by the Free
#  Software Foundation; either version 2.1 of the License, or (at your option)
#  any later version.
#
# Entries in this file show the compile time defaults. Local configuration
# should be created by either modifying this file (or a copy of it placed in
# /etc/ if the original file is shipped in /usr/), or by creating "drop-ins" in
# the /etc/systemd/timesyncd.conf.d/ directory. The latter is generally
# recommended. Defaults can be restored by simply deleting the main
# configuration file and all drop-ins located in /etc/.
#
# Use 'systemd-analyze cat-config systemd/timesyncd.conf' to display the full config.
#
# See timesyncd.conf(5) for details.

EOT
  fi

  cat << EOT > "$_tmp_timesyncd_conf"
[Time]

NTP=10.0.1.1
FallbackNTP=0.debian.pool.ntp.org
FallbackNTP=1.debian.pool.ntp.org
FallbackNTP=2.debian.pool.ntp.org
FallbackNTP=3.debian.pool.ntp.org

#RootDistanceMaxSec=5
#PollIntervalMinSec=32
#PollIntervalMaxSec=2048
#ConnectionRetrySec=30
#SaveIntervalSec=60
EOT

  if [ ! -f "$_timesyncd_conf" ] || ([ -f "$_timesyncd_conf" ] &&
    ! cmp -s "$_tmp_timesyncd_conf" "$_ori_timesyncd_conf" ) then

    _prt_status_msg "CHANGED "
    cat "$_tmp_timesyncd_conf" >> "$_ori_header_timesyncd_conf"
    _install_file "$_ori_header_timesyncd_conf" "$_timesyncd_conf"
    _install_systemd_unit systemd-timesyncd.service
    sleep 2
  fi

  rm -f "$_tmp_timesyncd_conf"
  rm -f "$_ori_timesyncd_conf"
  rm -f "$_ori_header_timesyncd_conf"
  _prt_cleared_msg
}

function _update_timezone() {
  _prt_init_msg "Updating to local timezone... "
  if [[ "$(timedatectl | grep -qo "${ENV_TZ}")" == *${ENV_TZ}* ]]; then
    _prt_cleared_msg "Local timezone already updated."
  else
    timedatectl set-timezone "${ENV_TZ}"
    _prt_cleared_msg
  fi
}

#----- unattended upgrades conf

function _setup_unattended_upgrades() {
  _prt_init_msg "Configuring unattended upgrades... "
  if ! _check_installed_pkg unattended-upgrades; then
    _install_single_pkg unattended-upgrades
  fi

  local _uup_conf="/etc/apt/apt.conf.d/50unattended-upgrades"
  local _uup_conf_local="/etc/apt/apt.conf.d/52unattended-upgrades-local"

  if [ ! -f "$_uup_conf_local" ]; then
    _install_file "$_uup_conf" "$_uup_conf_local"
    if confirm "Edit '${_uup_conf_local}' file?"; then
      $EDITOR "$_uup_conf_local"
    fi
  fi

  local _daily_timer_override="/etc/systemd/system/apt-daily.timer.d/override.conf"
  local _tmp_daily_timer_override
  _tmp_daily_timer_override=$(mktemp /tmp/override.conf_XXXXXX)
  trap 'rm -f "$_tmp_daily_timer_override"' EXIT
  cat << EOT > "$_tmp_daily_timer_override"
[Timer]
OnCalendar=
OnCalendar=00:00
RandomizedDelaySec=5h
Persistent=true
EOT

  local _upgrade_timer_override="/etc/systemd/system/apt-daily-upgrade.timer.d/override.conf"
  local _tmp_upgrade_timer_override
  _tmp_upgrade_timer_override=$(mktemp /tmp/override.conf_XXXXXX)
  trap 'rm -f "$_tmp_upgrade_timer_override"' EXIT
  cat << EOT > "$_tmp_upgrade_timer_override"
[Timer]
OnCalendar=
OnCalendar=05:00
RandomizedDelaySec=30m
Persistent=true
EOT

  if [ ! -f "$_daily_timer_override" ] || { [ -f "$_daily_timer_override" ] &&
      ! cmp -s "$_tmp_daily_timer_override" "$_daily_timer_override"; }; then
    _prt_status_msg "CHANGED "
    install -m 0755 "$_tmp_daily_timer_override" "$_daily_timer_override"
  fi

  if [ ! -f "$_upgrade_timer_override" ] || { [ -f "$_upgrade_timer_override" ] &&
      ! cmp -s "$_tmp_upgrade_timer_override" "$_upgrade_timer_override"; }; then
    _prt_status_msg "CHANGED "
    install -m 0755 "$_tmp_daily_timer_override" "$_upgrade_timer_override"
  fi

  rm -f "$_tmp_daily_timer_override"
  rm -f "$_tmp_upgrade_timer_override"
  systemctl daemon-reload
  sleep 2

  printf "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" |
    debconf-set-selections
  if DEBIAN_FRONTEND=noninteractive \
    dpkg-reconfigure -f noninteractive unattended-upgrades; then _prt_cleared_msg
  else _prt_warning_nl "Files created but couldn't set up unattended upgrades."; fi

  return 0
}

#----- sshd config

function _setup_ssh_config() {
  _prt_init_msg "Configuring SSH server... "
  if ! _check_installed_pkg openssh-server; then
    _install_single_pkg openssh-server
  fi

  local _sshd_config_dir="/etc/ssh/sshd_config.d"
  _install_directory "$_sshd_config_dir"

  # user-defined ssh port
  while [ $SSH_PORT -eq 22 ]; do
    printf "Enter custom SSH port (1024-65535): "
    read -r SSH_PORT
    case "${SSH_PORT-}" in
      "") SSH_PORT=22 ;&
      22)
        if _confirm "Use default port '${SSH_PORT}' for ssh?"; then
          break
        fi
        ;;
      *)
        if _validate_ssh_port "$SSH_PORT"; then break
        else _prt_warning_nl "Invalid port number."; fi
        ;;
    esac
  done

  # ssh user allowlist
	local _users
	while true; do
		printf '%s' "Enter allowed users (empty for current user): "
		read -r _users
		if [ -z "${_users-}" ]; then
			SSH_USERS=( "${SUDO_USER:-$USER}" )
			break
		else
      local -a _allow_users=()
			readarray -td ' ' _allow_users < <(printf '%s' "$_users")
			for _user in "${_allow_users[@]}"; do
				if _validate_ssh_allow_users "$_user"; then
					SSH_USERS+=("$_user")
				else
					printf "Invalid user name '%s'\n" "$_user"
				fi
			done
			break
		fi
	done

  # issue
  local _issue="/etc/issue.net"
  local _tmp_issue
  _tmp_issue=$(mktemp /tmp/issue_XXXXXX)
  trap 'rm -f "$_tmp_issue"' EXIT

  cat << EOT > "$_tmp_issue"
 * All attempts are logged and reviewed
EOT

  # only update if the file doesn't exist or has changed
  if [ ! -f "$_issue" ] || { [ -f "$_issue" ] &&
    ! cmp -s "$_tmp_issue" "$_issue"; }; then
    _prt_status_msg "CHANGED "
    _install_file "$_tmp_issue" "$_issue"
  fi
  rm -f "$_tmp_issue"

  # actual sshd config
  local _ssh_config="${_sshd_config_dir}/99-hardening.conf"
  local _tmp_ssh_config
  _tmp_ssh_config=$(mktemp /tmp/ssh_hardening_XXXXXX)
  trap 'rm -f "$_tmp_ssh_config"' EXIT

  cat << EOT > "$_tmp_ssh_config"
Port $SSH_PORT
AllowUsers ${SSH_USERS[*]}
UsePAM yes

PermitRootLogin no
PubkeyAuthentication yes
AuthenticationMethods publickey
KbdInteractiveAuthentication no
PasswordAuthentication no
PermitEmptyPasswords no

MaxAuthTries 3
MaxSessions 5
MaxStartups 10:30:60
LoginGraceTime 20
ClientAliveInterval 300

AllowAgentForwarding no
AllowTcpForwarding local
GatewayPorts no
PermitTunnel no
X11Forwarding no

PrintMotd no
Banner /etc/issue.net
EOT

  # only update if the file doesn't exist or has changed
  if [ ! -f "$_ssh_config" ] || { [ -f "$_ssh_config" ] &&
    ! cmp -s "$_tmp_ssh_config" "$_ssh_config"; }; then
    _prt_status_msg "CHANGED "
    _install_file "$_tmp_ssh_config" "$_ssh_config"
    sshd -t
    _install_systemd_unit sshd.service
    sleep 5
  fi

  rm -f "$_tmp_ssh_config"
  _prt_cleared_msg
}

#----- nftables

function _test_nftables_config_file() {
  local _nftables_config_file="/etc/nftables.conf"
  if [ ! -f "$_nftables_config_file" ]; then
    _prt_error "'${_nftables_config_file}' file not found"
  fi

  # check syntax
  _prt_init_msg "Checking 'nftables' config file syntax... "
  nft -c -f "$_nftables_config_file"
  _prt_cleared_msg

  # load rules
  _prt_init_msg "Loading 'nftables' rules... "
  nft -f "$_nftables_config_file"
  _prt_cleared_msg

  # list rules
  _prt_info_nl_msg_nl "+ NFTABLES CONFIG FILE RULES:"
  nft list ruleset
}

function _setup_nftables() {
  _prt_init_msg "Configuring nftables firewall... "
  if ! _check_installed_pkg nftables; then
    _install_single_pkg nftables
  fi

  local _nftables_config_file="/etc/nftables.conf"
  local _tmp_nftables_config_file
  _tmp_nftables_config_file=$(mktemp /tmp/nftables.conf_XXXXXX)
  trap 'rm -f "$_tmp_nftables_config_file"' EXIT

  _fetch_ssh_port
  cat << EOT > "$_tmp_nftables_config_file"
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;

    # allow already established connections
    ct state established,related accept

    # allow loopback traffic
    iif "lo" accept

    # allow ssh admin
    tcp dport $SSH_PORT accept

    # HTTP01 - allow web traffic ports on development
    tcp dport { 80, 443 } accept

    # DNS01 - allow https web traffic on production
    # tcp dport 443 accept
  }

  chain forward {
    type filter hook forward priority 0; policy drop;
  }

  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOT

  if [ ! -f "$_nftables_config_file" ] ||
    { [ -f "$_nftables_config_file" ] &&
      ! cmp -s "$_tmp_nftables_config_file" "$_nftables_config_file"; }; then
    _prt_status_msg "CHANGED "
    _install_file "$_tmp_nftables_config_file" "$_nftables_config_file"
    _install_systemd_unit nftables
    sleep 2
  fi

  rm -f "$_tmp_nftables_config_file"
  _prt_cleared_msg
}

#----- fail2ban conf

function _setup_fail2ban() {
  _prt_init_msg "Configuring Fail2Ban... "
  if ! _check_installed_pkg nftables; then
    _setup_nftables
  fi

  local _jail_local_config="/etc/fail2ban/jail.local"
  local _tmp_jail_local_config
  _tmp_jail_local_config=$(mktemp /tmp/jail.local_XXXXXX)
  trap 'rm -f "$_tmp_jail_local_config"' EXIT

  cat << EOF > "$_tmp_jail_local_config"
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1/128
banaction = nftables-multiport
chain = input
bantime = 24h
findtime = 600
maxretry = 3

bantime.increment = true
bantime.rndtime = 30m
bantime.maxtime = 60d
bantime.factor = 2

dbpurgeage = 30d

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 6
mode = aggresive

[postfix]
enabled = true
port = smtp,ssmtp
filter = postfix
logpath = /var/log/mail.log
ignoreip = 127.0.0.1/8 ::1/128

EOF

  if [ ! -f "$_jail_local_config" ] ||
    { [ -f "$_jail_local_config" ] &&
      ! cmp -s "$_tmp_jail_local_config" "$_jail_local_config"; }; then
    _prt_status_msg "CHANGED "
    _install_file "$_tmp_jail_local_config" "$_jail_local_config"
    _install_systemd_unit fail2ban
    sleep 2
  fi

  rm -f "$_tmp_jail_local_config"
  _prt_cleared_msg
}

#----- kernel flags conf


# Recommended kernel security settings:
# https://www.kernel.org/doc/Documentation/sysctl/
function _setup_kernel_hardening() {
  _prt_init_msg "Installing kernel hardening... "

  local _kernel_config="/etc/sysctl.d/99-kernel-hardening.conf"
  local _tmp_kernel_config
  _tmp_kernel_config=$(mktemp /tmp/99-kernel-hardening.conf_XXXXXX)
  trap 'rm -f "$_tmp_kernel_config"' EXIT

  cat << EOT > "$_tmp_kernel_config"
#----- ipv4 networking

# protect against IP spoofing
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.rp_filter=1

# block SYN-FLOOD attacks
net.ipv4.tcp_syncookies=1

# ignore ICMP redirects
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.icmp_echo_ignore_broadcasts=1

# ignore source-routed packets
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0

# log martian packets
# (packets with impossible source addresses)
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.default.log_martians=1

#----- ipv6 Networking
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_source_route=0

#----- kernel security
# https://www.kernel.org/doc/Documentation/sysctl/kernel.txt

# enable ASLR (Address Space Layout Randomization)
kernel.randomize_va_space=2

# restrict access to /proc kernel pointers
# (replaces values by a 0 when printing with %pK)
kernel.kptr_restrict=2

# restrict access to dmesg (message bus) for unprivileged users
kernel.dmesg_restrict=1

# restrict ptrace scope to prevent process injection attacks
kernel.yama.ptrace_scope=1

# disables reloading a new kernel on reboot
# bypassing the usual bootloader and hardware initialization stages
# https://man.archlinux.org/man/kexec_file_load.2.en
kernel.kexec_load_disabled=1

#----- Filesystem Security

# protect against TOCTOU (Time-of-Check to Time-of-Use) race conditions
fs.protected_hardlinks=1
fs.protected_symlinks=1

# ensure disable privileged process coredumps
# see: https://serverfault.com/questions/56800/on-redhat-what-does-kernel-suid-dumpable-1-mean
# see: https://en.wikipedia.org/wiki/Setuid
fs.suid_dumpable=0
EOT

  # only update if the file doesn't exist or has changed

  if [ ! -f "$_kernel_config" ] || { [ -f "$_kernel_config" ] &&
    ! cmp -s "$_tmp_kernel_config" "$_kernel_config"; }; then
    _prt_status_msg "CHANGED "
    _install_file "$_tmp_kernel_config" "$_kernel_config"
    sysctl --load /etc/sysctl.d/99-kernel-hardening.conf
  fi

  rm -f "$_tmp_kernel_config"
  _prt_cleared_msg
}

#----- docker engine conf

function _setup_docker_engine() {
  _prt_init_msg "Setting up docker engine... "
  if systemctl is-active --quiet docker; then
    _prt_cleared_msg "Docker already installed and running."

    getent group docker > /dev/null || groupadd docker
    if ! groups "$SUDO_USER" | grep -qw docker; then
      usermod -aG docker "$SUDO_USER"
      _prt_info_msg_nl "Adding '$SUDO_USER' to docker group..."
    fi
    return 0
  fi

  # https://docs.docker.com/engine/install/debian/
  local _keyrings_dir="/etc/apt/keyrings"
  local _docker_keys="${_keyrings_dir}/docker.asc"
  local _docker_gpg_url="https://download.docker.com/linux/debian/gpg"

  _prt_info_msg_nl "Removing old docker packages..."
  if ! apt-get remove -y -qq "${DOCKER_PKG_REMOVE[@]}" 2> /dev/null; then
    _prt_error "Couldn't remove 'DOCKER_PKG_REMOVE' list"
  fi

  _update_system
  if ! _check_installed_pkg ca-certificates; then
    _install_single_pkg ca-certificates
  fi
  if ! _check_installed_pkg curl; then
    _install_single_pkg curl
  fi

  _install_directory "$_keyrings_dir"
  _prt_info_msg_nl "Adding Docker's official GPG key and repository..."
  curl -fsSL "${_docker_gpg_url}" -o "${_docker_keys}"
  chmod a+r "${_docker_keys}"

  # Add the repository to Apt sources:
  local _docker_dir="/etc/docker"
  local _docker_daemon_conf="${_docker_dir}/daemon.json"
  local _docker_sources="/etc/apt/sources.list.d/docker.sources"
  local _tmp_docker_sources _tmp_docker_daemon_conf

  if [ ! -f "$_docker_sources" ]; then
    _check_debian_version
    cat << EOT > "$_docker_sources"
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: ${_docker_keys}
EOT
    _update_system
  fi

  _install_docker_pkg
  _tmp_docker_daemon_conf=$(mktemp /tmp/docker_config_XXXXXX)
  trap 'rm -f "$_tmp_docker_daemon_conf"' EXIT
  cat << EOT > "$_tmp_docker_daemon_conf"
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "live-restore": true
}
EOT

  _install_directory "$_docker_dir"
  if [ ! -f "$_docker_daemon_conf" ] || { [ -f "$_docker_daemon_conf" ] &&
    ! cmp -s "$_tmp_docker_daemon_conf" "$_docker_daemon_conf"; }; then
    _prt_status_msg "CHANGED "
    _install_file "$_tmp_docker_daemon_conf" "$_docker_daemon_conf"
  fi

  rm -f "$_tmp_docker_daemon_conf"
  _install_systemd_unit docker

  getent group docker > /dev/null || groupadd docker
  if ! groups "$SUDO_USER" | grep -qw docker; then
    usermod -aG docker "$SUDO_USER" && echo "Done."
    _prt_info_msg_nl "Adding '$SUDO_USER' to docker group..."
  fi

  _prt_cleared_msg
}

function _run_cleanup() {
  _update_system
  _clean_system
  systemctl daemon-reload ||
    _prt_error "Reload of systemd daemons failed."

  _prt_cleared_msg "Final system update and cleanup complete."
}

function _run() {
  # run-as-root check
  if [ "$(id -u)" -ne 0 ]; then
    _prt_warning_nl "This script must be run with root privileges."
    _prt_error "Re-run the script using 'sudo -E'"
  fi

  local _msg
  _check_debian_version
  _prt_info_nl_msg_nl "Debian '${VERSION_CODENAME-}' update script"

  _msg="Run the complete installation sequentially?"
  if _confirm "$_msg"; then
    _configure_debian_sources
    _update_system
    _install_core_pkg
    _update_locale
    _setup_systemd_resolved
    _setup_systemd_timesync
    _update_timezone
    _setup_unattended_upgrades
    _setup_ssh_config
    _setup_nftables
    _setup_fail2ban
    _setup_kernel_hardening
    _setup_docker_engine

  else
    if _confirm "Update Debian sources?"
    then _configure_debian_sources; fi
    if _confirm "Update system packages?"
    then _update_system; fi
    if _confirm "Install core packages?"
    then _install_core_pkg; fi
    if _confirm "Update locales?"
    then _update_locale; fi
    if _confirm "Install systemd-resolved?"
    then _setup_systemd_resolved; fi
    if _confirm "Install systemd-timesyncd?"
    then _setup_systemd_timesync; fi
    if _confirm "Update timezone?"
    then _update_timezone; fi
    if _confirm "Install unattended upgrades?"
    then _setup_unattended_upgrades; fi
    if _confirm "Set up SSH config?"
    then _setup_ssh_config; fi
    if _confirm "Set up nftables?"
    then _setup_nftables; fi
    if _confirm "Set up fail2ban?"
    then _setup_fail2ban; fi
    if _confirm "Set up kernel hardening?"
    then _setup_kernel_hardening; fi
    if _confirm "Set up docker engine?"
    then _setup_docker_engine; fi

    if [ "$CLEANUP_FLAG" -eq 0 ]; then _run_cleanup; fi
  fi
}

if [ "${#BASH_SOURCE[@]}" -eq 1 ]; then
  _run "$@"
  return $?
fi
