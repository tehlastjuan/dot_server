#!/usr/bin/env bash

set -euo pipefail  # Exit on error, undefined vars, pipe failures

_install_dot_server() {
  local CONFIG_OLD
  CONFIG_OLD="$HOME/.config.old"

  echo "Installing dot_server files..."

  [[ -e "$HOME/.config/.git" ]] && {
    echo "Dot_server file already installed." && return 0
  }

  [[ -e "$HOME/.config" ]] && mv "$HOME/.config" "$CONFIG_OLD"

  [[ -e "$HOME/.bashrc" ]] && {
    [[ ! -e "$CONFIG_OLD" ]] && mkdir -p "$CONFIG_OLD"
    mv "$HOME/.bashrc" "$CONFIG_OLD/bashrc"
  }

  [[ -e "$HOME/.bash_logout" ]] && {
    [[ ! -e "$CONFIG_OLD" ]] && mkdir -p "$CONFIG_OLD"
    mv "$HOME/.bash_logout" "$CONFIG_OLD/bash_logout"
  }

  [[ -e "$HOME/.profile" ]] && {
    [[ ! -e "$CONFIG_OLD" ]] && mkdir -p "$CONFIG_OLD"
    mv "$HOME/.profile" "$CONFIG_OLD/profile"
  }

  [[ -e "$HOME/.viminfo" ]] && {
    [[ ! -e "$CONFIG_OLD" ]] && mkdir -p "$CONFIG_OLD"
    mv "$HOME/.viminfo" "$CONFIG_OLD/viminfo"
  }

  [[ ! -e "$HOME/.local" ]] && mkdir "$HOME/.local"

  mv "$HOME/dot_server" "$HOME/.config"

  ln -s "$HOME/.config/bash/bashrc"      "$HOME/.bashrc"
  ln -s "$HOME/.config/bash/bash_logout" "$HOME/.bash_logout"
  ln -s "$HOME/.config/bash/profile"     "$HOME/.profile"
  ln -s "$HOME/.config/vim/vimrc"        "$HOME/.vimrc"

  chown -R "$USER": "/home/$USER"

  echo "Dot server files installation completed."
}

_main() {

  _install_dot_server

}

_main "$@"
