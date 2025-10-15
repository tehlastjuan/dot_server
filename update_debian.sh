#!/usr/bin/env bash

set -euo pipefail  # Exit on error, undefined vars, pipe failures

SSH_PORT=22
CLEANUP_FLAG=0

_confirm() {
    local prompt="$1 [y/n]: "
    local response

    while true; do
      echo "$prompt"
      read -r response
      response=${response,,}

      case $response in
        y|yes) return 0 ;;
        n|no) return 1 ;;
        *) ;;
      esac
    done
}

_validate_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ && "$port" -ge 1024 && "$port" -le 65535 ]]
}

_update_system() {
  echo "Updating system packages..."
  if ! apt-get update && apt-get upgrade -qq; then
    echo "Failed to update system packages. Aborting."
    exit 1
  fi
}

_install_essential_packages() {
  echo "Installing essential packages..."
  if ! apt-get install -y -qq ca-certificates curl; then
    echo "Failed to install one or more essential packages. Aborting."
    exit 1
  fi
  CLEANUP_FLAG=1
}

_update_timezone() {
  echo "Updating to local timezone..."
  if [[ ! $(timedatectl | grep -o "Europe/Stockholm") == *Europe/Stockholm* ]]; then
    if [[ $LANG == "C" ]]; then dpkg-reconfigure tzdata
    else
      sed -i -e 's/Europe/Stockholm/' /etc/timezone \
        && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure --frontend=noninteractive tzdata
    fi
  else echo "Local timezone already updated."; fi
  CLEANUP_FLAG=1
}

_update_locale() {
  if ! apt-get install -y -qq locales; then
    echo "Failed to install the locales package. Aborting."
    exit 1
  fi

  echo "Updating locales..."
  if [[ ! $LANG == "en_US.UTF-8" ]]; then
    echo "Updating to local timezone..."
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
      && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure --frontend=noninteractive locales \
      && update-locale LANG=en_US.UTF-8
  else echo "Locale already updated."; fi
  CLEANUP_FLAG=1
}

_install_hardening_packages() {
  echo "Installing hardening packages..."
  if ! apt-get install -y -qq \
    ufw fail2ban unattended-upgrades chrony \
    rsync wget vim htop iotop nethogs netcat-traditional ncdu \
    tree rsyslog cron jq gawk coreutils perl skopeo \
    ssh openssh-client openssh-server; then
    echo "Failed to install one or more essential packages."
    exit 1
  fi
  CLEANUP_FLAG=1
}

_configure_ssh() {
  echo "Updating SSH Configuration..." # Apply additional hardening
  while true; do
    echo "Enter custom SSH port (1024-65535) [2222]: ${NC}"
    read -rp SSH_PORT
    SSH_PORT=${SSH_PORT:-2222}
    if _validate_port "$SSH_PORT"; then break; else print_error "Invalid port number."; fi
  done

  mkdir -p /etc/ssh/sshd_config.d
  tee /etc/ssh/sshd_config.d/99-hardening.conf > /dev/null <<EOF
  Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
X11Forwarding no
PrintMotd no
Banner /etc/issue.net
EOF

  tee /etc/issue.net > /dev/null <<'EOF'

 * All attempts are logged and reviewed

EOF

  echo "Reloading systemd and restarting SSH service..."
  systemctl daemon-reload
  systemctl restart sshd.service
  sleep 5

  echo "Verifying root SSH login is disabled..." # Verify root SSH is disabled
  if ssh -p ${SSH_PORT} -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@localhost true 2>/dev/null; then
    echo "Root SSH login is still possible! Check configuration."
    return 1
  else echo "Confirmed: Root SSH login is disabled."; fi

  echo "SSH configuration completed."
  CLEANUP_FLAG=1
}

_configure_firewall() {
  echo "Configuring firewall (UFW)..."

  if ufw status | grep -q "Status: active"; then
    echo "UFW already enabled."
  else
    echo "Configuring UFW default policies..."
    ufw default deny incoming
    ufw default allow outgoing
  fi

  if ! ufw status | grep -qw "$SSH_PORT/tcp"; then
    echo "Adding SSH rule for port $SSH_PORT..."
    ufw allow "$SSH_PORT"/tcp comment 'SSH'
  else
    echo "SSH rule for port $SSH_PORT already exists."
  fi

  if ! ufw status | grep -qw "80/tcp"; then
    ufw allow http comment 'HTTP'
    echo "HTTP traffic allowed."
  else
    echo "HTTP rule already exists."
  fi

  if ! ufw status | grep -qw "443/tcp"; then
    ufw allow https comment 'HTTPS'
    echo "HTTPS traffic allowed."
  else
    echo "HTTPS rule already exists."
  fi

  echo "Enabling firewall..."
  if ! ufw --force enable; then
    echo "Failed to enable UFW. Check 'journalctl -u ufw' for details."
    exit 1
  fi

  if ufw status | grep -q "Status: active"; then
    echo "Firewall is active."
  else
    echo "UFW failed to activate. Check 'journalctl -u ufw' for details."
    exit 1
  fi

  echo "Firewall configuration completed."
  CLEANUP_FLAG=1
}

_configure_fail2ban() {
  echo "Configuring Fail2Ban..."

  local UFW_PROBES_CONFIG
  UFW_PROBES_CONFIG=$(cat <<'EOF'
[Definition]
# This regex looks for the standard "[UFW BLOCK]" message in /var/log/ufw.log
failregex = \[UFW BLOCK\] IN=.* OUT=.* SRC=<HOST>
ignoreregex =
EOF
)
  local JAIL_LOCAL_CONFIG 
  JAIL_LOCAL_CONFIG=$(cat <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
bantime = 1d
findtime = 10m
maxretry = 5
banaction = ufw

[sshd]
enabled = true
port = $SSH_PORT

# This jail monitors UFW logs for rejected packets (port scans, etc.).
[ufw-probes]
enabled = true
port = all
filter = ufw-probes
logpath = /var/log/ufw.log
maxretry = 3
EOF
)

  UFW_FILTER_PATH="/etc/fail2ban/filter.d/ufw-probes.conf"
  JAIL_LOCAL_PATH="/etc/fail2ban/jail.local"

  # This checks if the on-disk files are already identical to our desired configuration.
  if [[ -f "$UFW_FILTER_PATH" && -f "$JAIL_LOCAL_PATH" ]] && \
    cmp -s "$UFW_FILTER_PATH" <<<"$UFW_PROBES_CONFIG" && \
    cmp -s "$JAIL_LOCAL_PATH" <<<"$JAIL_LOCAL_CONFIG"; then
    echo "Fail2Ban is already configured correctly. Skipping."
    return 0
  fi

  # If the check above fails, we write the correct configuration files.
  echo "Applying new Fail2Ban configuration..."
  mkdir -p /etc/fail2ban/filter.d
  echo "$UFW_PROBES_CONFIG" > "$UFW_FILTER_PATH"
  echo "$JAIL_LOCAL_CONFIG" > "$JAIL_LOCAL_PATH"

  # --- Ensure the log file exists BEFORE restarting the service ---
  if [[ ! -f /var/log/ufw.log ]]; then
    touch /var/log/ufw.log
    echo "Created empty /var/log/ufw.log to ensure Fail2Ban starts correctly."
  fi

  # --- Restart and Verify Fail2ban ---
  echo "Enabling and restarting Fail2Ban to apply new rules..."
  systemctl enable fail2ban
  systemctl restart fail2ban
  sleep 2

  if systemctl is-active --quiet fail2ban; then
    echo "Fail2Ban is active with the new configuration."
    fail2ban-client status | tee -a /var/log/ufw.log
  else echo "Fail2Ban service failed to start. Check 'journalctl -u fail2ban' for errors."; fi

  echo "Fail2Ban configuration completed."
  CLEANUP_FLAG=1
}

_configure_auto_updates() {
  echo "Configuring Automatic Security Updates..."
  if ! dpkg -l unattended-upgrades | grep -q ^ii; then
    echo "unattended-upgrades package is not installed."
    return 1
  fi

  # Check for existing unattended-upgrades configuration
  if [[ -f /etc/apt/apt.conf.d/50unattended-upgrades ]] && 
    grep -q "Unattended-Upgrade::Allowed-Origins" /etc/apt/apt.conf.d/50unattended-upgrades; then
      echo "Existing unattended-upgrades configuration found."
      echo "Verify with 'cat /etc/apt/apt.conf.d/50unattended-upgrades'."
  fi

  echo "Configuring unattended upgrades..."
  echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | debconf-set-selections
  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive unattended-upgrades

  echo "Automatic security updates enabled."
  CLEANUP_FLAG=1
}

_configure_kernel_hardening() {
  echo "Kernel Parameter Hardening (sysctl)..."

  local KERNEL_HARDENING_CONFIG
  KERNEL_HARDENING_CONFIG=$(mktemp)
  tee "$KERNEL_HARDENING_CONFIG" > /dev/null <<'EOF'
# Recommended Security Settings
# For details, see: https://www.kernel.org/doc/Documentation/sysctl/

# --- IPV4 Networking ---
# Protect against IP spoofing
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.rp_filter=1
# Block SYN-FLOOD attacks
net.ipv4.tcp_syncookies=1
# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=1
net.ipv4.conf.default.secure_redirects=1
# Ignore source-routed packets
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
# Log martian packets (packets with impossible source addresses)
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.default.log_martians=1

# --- IPV6 Networking (if enabled) ---
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_source_route=0

# --- Kernel Security ---
# Enable ASLR (Address Space Layout Randomization) for better security
kernel.randomize_va_space=2
# Restrict access to kernel pointers in /proc to prevent leaks
kernel.kptr_restrict=2
# Restrict access to dmesg for unprivileged users
kernel.dmesg_restrict=1
# Restrict ptrace scope to prevent process injection attacks
kernel.yama.ptrace_scope=1

# --- Filesystem Security ---
# Protect against TOCTOU (Time-of-Check to Time-of-Use) race conditions
fs.protected_hardlinks=1
fs.protected_symlinks=1
EOF

  local SYSCTL_CONF_FILE="/etc/sysctl.d/99-du-hardening.conf"

  # only update if the file doesn't exist or has changed
  if [[ -f "$SYSCTL_CONF_FILE" ]] && cmp -s "$KERNEL_HARDENING_CONFIG" "$SYSCTL_CONF_FILE"; then
    echo "Kernel security settings are already configured correctly."
    rm -f "$KERNEL_HARDENING_CONFIG"
    return 0
  fi

  echo "Applying settings to $SYSCTL_CONF_FILE..."
  mv "$KERNEL_HARDENING_CONFIG" "$SYSCTL_CONF_FILE"
  chmod 644 "$SYSCTL_CONF_FILE"

  echo "Loading new settings..."
  if sysctl -p "$SYSCTL_CONF_FILE" >/dev/null 2>&1; then
    echo "Kernel security settings applied successfully."
  else echo "Failed to apply kernel settings. Check for kernel compatibility."; fi

  echo "Kernel hardening completed."
  CLEANUP_FLAG=1
}

_configure_time_sync() {
  echo "Time Synchronization"
  echo "Ensuring chrony is active..."
  systemctl enable --now chrony
  sleep 2
  if systemctl is-active --quiet chrony; then
    echo "Chrony is active for time synchronization."
  else
    echo "Chrony service failed to start."
    exit 1
  fi

  echo "Time synchronization completed."
  CLEANUP_FLAG=1
}

# https://docs.docker.com/engine/install/debian/
_install_docker() {
  echo "Installing docker engine..."

  if hash docker >/dev/null 2>&1; then
    echo "Docker already installed. Skipping."
    return 0
  fi

  echo "Removing old container runtimes..."
  apt-get remove -y -qq docker docker-engine docker.io containerd runc 2>/dev/null || true

  _update_system

  echo "Adding Docker's official GPG key and repository..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  _update_system

  echo "Installing Docker packages..."
  if ! apt-get install -y -qq \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin; then
    echo "Failed to install one or more docker packages."
    exit 1
  fi

  echo "Configuring Docker daemon..."
  local NEW_DOCKER_CONFIG
  NEW_DOCKER_CONFIG=$(mktemp)
  tee "$NEW_DOCKER_CONFIG" > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "live-restore": true
}
EOF

  mkdir -p /etc/docker
  if [[ -f /etc/docker/daemon.json ]] && cmp -s "$NEW_DOCKER_CONFIG" /etc/docker/daemon.json; then
    echo "Docker daemon configuration already correct. Skipping."
    rm -f "$NEW_DOCKER_CONFIG"
  else
    mv "$NEW_DOCKER_CONFIG" /etc/docker/daemon.json
    chmod 644 /etc/docker/daemon.json
  fi
  systemctl daemon-reload
  systemctl enable --now docker

  echo "Adding '$SUDO_USER' to docker group..."
  getent group docker >/dev/null || groupadd docker
  if ! groups "$SUDO_USER" | grep -qw docker; then
    usermod -aG docker "$SUDO_USER"
    echo "User '$SUDO_USER' added to docker group."
  else echo "User '$SUDO_USER' is already in docker group."; fi
  CLEANUP_FLAG=1
}

_final_cleanup() {
  echo "Final System Cleanup"
  echo "Running final system update and cleanup..."
  if ! apt-get update -qq; then
    echo "Failed to update package lists during final cleanup."
  fi
  if ! apt-get upgrade -y -qq || ! apt-get --purge autoremove -y -qq || ! apt-get autoclean -y -qq; then
    echo "Final system cleanup failed on one or more commands."
  fi
  systemctl daemon-reload
  echo "Final system update and cleanup complete."
}

_main() {
  if [[ $(id -u) -ne 0 ]]; then # root check
    echo -e "Error: This script must be run with root privileges."
    echo -e "Please re-run the script using 'sudo -E':"
    exit 1
  fi

  echo "Starting Debian hardening script..."

  if _confirm "Would you like to update the system packages now?"; then _update_system; fi
  if _confirm "Would you like to install curl and ca-certificates packages?"; then _install_essential_packages; fi
  if _confirm "Would you like to update timezone to Europe/Stockholm?"; then _update_timezone; fi
  if _confirm "Would you like to update locale to US-UTF-8?"; then _update_locale; fi
  if _confirm "Would you like to install hardening packages?"; then _install_hardening_packages; fi
  if _confirm "Would you like to harden the SSH config?"; then _configure_ssh ; fi
  if _confirm "Would you like to configure the firewall?"; then _configure_firewall ; fi
  if _confirm "Would you like to install and configure fail2ban?"; then _configure_fail2ban ; fi
  if _confirm "Would you like to install kernel hardening?"; then _configure_kernel_hardening ; fi
  if _confirm "Would you like to configure automatic updates?"; then _configure_time_sync ; fi
  if _confirm "Would you like to install docker?"; then _install_docker ; fi

  if [[ "$CLEANUP_FLAG" -eq 1 ]]; then _final_cleanup; fi
}

_main "$@"
