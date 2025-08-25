#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="$PWD/bin"
BSD_DIR="$BIN_DIR/freeBSD"
LINUX_DIR="$BIN_DIR/linux"

REPOS=(
  "sharkdp/bat"
  "junegunn/fzf"
  "gokcehan/lf"
)

_download_utils() {
  local linux_tmp
  local linux_url
  local bsd_tmp
  local bsd_url
  local lx_filename
  local bsd_filename
  local url

  linux_tmp="/tmp/tmp.linux$(date +%m%d%H%M%S)"
  [[ ! -d $linux_tmp ]] && mkdir -p "$linux_tmp/bin"

  bsd_tmp="/tmp/tmp.bsd$(date +%m%d%H%M%S)"
  [[ ! -d $bsd_tmp ]] && mkdir -p "$bsd_tmp/bin"

  for repo in "${REPOS[@]}"; do
    url="$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep 'browser_download_url.*')"

    # fetch linux binaries
    if [[ $url == *linux* ]]; then
      linux_url="$(echo "$url" | grep -o 'https://[^"]*' | grep 'i686-unknown-linux-gnu.tar.gz\|linux.*amd64.tar.gz')"
      lx_filename="${linux_url##*/}"
      if [[ ! -e "$linux_tmp/$lx_filename" ]]; then wget -q -O "$linux_tmp/$lx_filename" "$linux_url"; fi
      tar xf "$linux_tmp/$lx_filename" --directory "$linux_tmp/bin"
    fi

    # fetch bsd binaries
    if [[ $url == *freebsd* ]]; then
      bsd_url="$(echo "$url" | grep -o 'https://[^"]*' | grep 'freebsd.*amd64.tar.gz')"
      bsd_filename="${bsd_url##*/}"
      if [[ ! -e "$bsd_tmp/$bsd_filename" ]]; then wget -q -O "$bsd_tmp/$bsd_filename" "$bsd_url"; fi
      tar xf "$bsd_tmp/$bsd_filename" --directory "$bsd_tmp/bin"
    fi
  done

  if [[ "$(find "$linux_tmp" -type f -executable | wc -l)" -eq 3 ]]; then
    mkdir -p "${LINUX_DIR}_tmp"
    find "$linux_tmp" -type f -executable -exec cp {} "${LINUX_DIR}_tmp" \;
    [[ -e "$LINUX_DIR" ]] && rm -r "$LINUX_DIR"
    mv "${LINUX_DIR}_tmp" "$LINUX_DIR"
  fi

  if [[ "$(find "$bsd_tmp" -type f -executable | wc -l)" -eq 2 ]]; then
    mkdir -p "${BSD_DIR}_tmp"
    find "$bsd_tmp" -type f -executable -exec cp {} "${BSD_DIR}_tmp" \;
    [[ -e "$BSD_DIR" ]] && rm -r "$BSD_DIR"
    mv "${BSD_DIR}_tmp" "$BSD_DIR"
  fi

  rm -r "$linux_tmp"
  rm -r "$bsd_tmp"
}

_download_utils
