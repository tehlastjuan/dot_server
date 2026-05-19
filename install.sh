#!/usr/bin/env bash

set -u

_INSTALL_DST="$HOME"
_CONFIG_HOME="${_INSTALL_DST}/.config"
_CONFIG_HOME_BACKUP="${_CONFIG_HOME}.old"

_FILES=(
  'bash/bashrc'
  'bash/bash_logout'
  'bash/profile'
  'vim/vimrc'
)

if [ ! -d "$_INSTALL_DST" ]; then
  printf "Destionation directory doesn't exist. Aborting.\n"
  exit 1
fi

if [ -d "$_CONFIG_HOME" ]; then
  if git -C "$_CONFIG_HOME" rev-parse --is-inside-work-tree &> /dev/null; then
    if [[ "$(git -C "$_CONFIG_HOME" remote get-url --no-all origin)" != *dot_server* ]]; then
      printf 'echo "Unknown install files. Aborting.\n'
      exit 1
    fi
  fi
  if [ ! "$_CONFIG_HOME" -ef "$PWD" ]; then
    if mv "$_CONFIG_HOME" "$_CONFIG_HOME_BACKUP"; then
      mv "$PWD" "$_CONFIG_HOME"
    fi
  fi
fi

for _file in "${_FILES[@]}"; do
  filename="${_file##*/}"
  home_filepath="${_INSTALL_DST}/.${filename}"
  src_filepath="${_CONFIG_HOME}/${_file}"

  if [ -L "$home_filepath" ]; then
    rm "$home_filepath"
  elif [ -f "$home_filepath" ]; then
    [ ! -d "$_CONFIG_HOME_BACKUP" ] && mkdir -p "$_CONFIG_HOME_BACKUP"
    if [ -d "$_CONFIG_HOME_BACKUP" ]; then
      mv "$home_filepath" "${_CONFIG_HOME_BACKUP}/${home_filepath##/*}"
    fi
  fi

  ln -s "$src_filepath" "$home_filepath"
done

[ -f "${_INSTALL_DST}/.viminfo" ] &&
  mv "${_INSTALL_DST}/.viminfo" "${_CONFIG_HOME_BACKUP}/.viminfo"
