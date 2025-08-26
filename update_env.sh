#!/usr/bin/env bash

set -euo pipefail  # Exit on error, undefined vars, pipe failures

_install_dot_server() {
  local CONFIG_OLD
  CONFIG_OLD="$HOME/.config.old"

  echo "Installing dot_server files..."

  if [[ -e "$HOME/.config/.git" ]]; then
    ORIGIN="$(git remote --verbose | grep origin | grep fetch | cut -f2 | cut -d' ' -f1)"
    if [[ $ORIGIN == *dot_server.git ]]; then
      [[ -L "$HOME/.bashrc" ]] && rm "$HOME/.bashrc"
      [[ -L "$HOME/.bash_logout" ]] && rm "$HOME/.bash_logout"
      [[ -L "$HOME/.profile" ]] && rm "$HOME/.profile"
      [[ -L "$HOME/.vimrc" ]] && rm "$HOME/.vimrc"
    fi
  else
    [[ -e "$HOME/.config/.git" ]] &&
      echo "Unknown dot files installation. Aborting." && return 0
  fi

  [[ ! -e "$HOME/.local" ]] && mkdir "$HOME/.local"
  [[ -e "$HOME/dot_server" ]] && mv "$HOME/dot_server" "$HOME/.config"

  [[ -e "$HOME/.bashrc" ]] && {
    [[ ! -e "$CONFIG_OLD" ]] && mkdir -p "$CONFIG_OLD"
    mv "$HOME/.bashrc" "$CONFIG_OLD/bashrc"
    ln -s "$HOME/.config/bash/bashrc" "$HOME/.bashrc"
  }

  [[ -e "$HOME/.bash_logout" ]] && {
    [[ ! -e "$CONFIG_OLD" ]] && mkdir -p "$CONFIG_OLD"
    mv "$HOME/.bash_logout" "$CONFIG_OLD/bash_logout"
    ln -s "$HOME/.config/bash/bash_logout" "$HOME/.bash_logout"
  }

  [[ -e "$HOME/.profile" ]] && {
    [[ ! -e "$CONFIG_OLD" ]] && mkdir -p "$CONFIG_OLD"
    mv "$HOME/.profile" "$CONFIG_OLD/profile"
    ln -s "$HOME/.config/bash/profile" "$HOME/.profile"
  }

  [[ -e "$HOME/.viminfo" ]] && {
    [[ ! -e "$CONFIG_OLD" ]] && mkdir -p "$CONFIG_OLD"
    mv "$HOME/.viminfo" "$CONFIG_OLD/viminfo"
    ln -s "$HOME/.config/vim/vimrc" "$HOME/.vimrc"
  }

  echo "Dot server files installation completed."
}

_install_dot_server
