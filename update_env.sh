#!/usr/bin/env bash

set -euo pipefail  # Exit on error, undefined vars, pipe failures

_install_dot_server() {
  local ORIGIN=0
  local CONFIG_OLD
  CONFIG_OLD="$HOME/.config.old"

  echo "Installing dot_server files..."

  if [[ -e "$HOME/.config/.git" ]]; then
    [[ $(git remote --verbose | grep origin | grep fetch | cut -f2 | cut -d' ' -f1) == *dot_server* ]] && ORIGIN=1
  else
    [[ -e "$HOME/.config/.git" ]] && echo "Unknown dot files installation. Aborting." && return 1
  fi

  [[ ! -e "$HOME/.local" ]] && mkdir "$HOME/.local"
  [[ -e "$HOME/dot_server" ]] && mv "$HOME/dot_server" "$HOME/.config"

  if [[ -e "$HOME/.bashrc" ]]; then
    if [[ $ORIGIN -eq 1 ]]; then
      [[ -L "$HOME/.bashrc" ]] && rm "$HOME/.bashrc"
    else
      [[ ! -e "$CONFIG_OLD" ]] && mkdir -p "$CONFIG_OLD"
      mv "$HOME/.bashrc" "$CONFIG_OLD/bashrc"
    fi
  fi
  ln -s "$HOME/.config/bash/bashrc" "$HOME/.bashrc"

  if [[ -e "$HOME/.bash_logout" ]]; then
    if [[ $ORIGIN -eq 1 ]]; then
      [[ -L "$HOME/.bash_logout" ]] && rm "$HOME/.bash_logout"
    else
      [[ ! -e "$CONFIG_OLD" ]] && mkdir -p "$CONFIG_OLD"
      mv "$HOME/.bash_logout" "$CONFIG_OLD/bash_logout"
    fi
  fi
  ln -s "$HOME/.config/bash/bash_logout" "$HOME/.bash_logout"

  if [[ -e "$HOME/.profile" ]]; then
    if [[ $ORIGIN -eq 1 ]]; then
      [[ -L "$HOME/.profile" ]] && rm "$HOME/.profile"
    else
      [[ ! -e "$CONFIG_OLD" ]] && mkdir -p "$CONFIG_OLD"
      mv "$HOME/.profile" "$CONFIG_OLD/profile"
    fi
  fi
  ln -s "$HOME/.config/bash/profile" "$HOME/.profile"

  if [[ -e "$HOME/.vimrc" ]]; then
    if [[ $ORIGIN -eq 1 ]]; then
      [[ -L "$HOME/.vimrc" ]] && rm "$HOME/.vimrc"
    else
      [[ ! -e "$CONFIG_OLD" ]] && mkdir -p "$CONFIG_OLD"
      mv "$HOME/.vimrc" "$CONFIG_OLD/vimrc"
    fi
  fi
  ln -s "$HOME/.config/vim/vimrc" "$HOME/.vimrc"

  if [[ -e "$HOME/.viminfo" ]]; then
      mv "$HOME/.viminfo" "$CONFIG_OLD/viminfo"
  fi

  echo "Dot server files installation completed."
}

_install_dot_server
