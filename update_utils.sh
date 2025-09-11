#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="$PWD/bin"

BSD_DIR="$BIN_DIR/freeBSD"
LINUX_ARM_DIR="$BIN_DIR/linux_arm64"
LINUX_AMD_DIR="$BIN_DIR/linux_amd64"

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
  local arch

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    arch="$(lscpu | grep 'Architecture' | cut -d ':' -f 2)"
    arch="${arch#"${arch%%[![:space:]]*}"}"

    case "$arch" in
      unknown) arch="amd64" ;;
      aarch64) arch="arm64" ;;
      *) arch="amd64" ;;
    esac

    linux_tmp="/tmp/tmp.linux$(date +%m%d%H%M%S)"
    [[ ! -d $linux_tmp ]] && mkdir -p "$linux_tmp/bin"
  fi

  if [[ "$OSTYPE" == "freebsd"* ]]; then
    bsd_tmp="/tmp/tmp.bsd$(date +%m%d%H%M%S)"
    [[ ! -d $bsd_tmp ]] && mkdir -p "$bsd_tmp/bin"
  fi

  for repo in "${REPOS[@]}"; do
    url="$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep 'browser_download_url.*')"

    # fetch linux amd64/arm64 binaries
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      if [[ $url == *linux* ]]; then
        linux_url="$(echo "$url" | grep -o 'https://[^"]*' | grep "i686-unknown-linux-gnu.tar.gz\|linux.*${arch}.tar.gz")"
        lx_filename="${linux_url##*/}"
        if [[ ! -e "$linux_tmp/$lx_filename" ]]; then wget -q -O "$linux_tmp/$lx_filename" "$linux_url"; fi
        tar xf "$linux_tmp/$lx_filename" --directory "$linux_tmp/bin"
      fi
    fi

    # fetch amd64 bsd binaries
    if [[ "$OSTYPE" == "freebsd"* ]]; then
      if [[ $url == *freebsd* ]]; then
        bsd_url="$(echo "$url" | grep -o 'https://[^"]*' | grep "freebsd.*${arch}.tar.gz")"
        bsd_filename="${bsd_url##*/}"
        if [[ ! -e "$bsd_tmp/$bsd_filename" ]]; then wget -q -O "$bsd_tmp/$bsd_filename" "$bsd_url"; fi
        tar xf "$bsd_tmp/$bsd_filename" --directory "$bsd_tmp/bin"
      fi
    fi
  done

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [[ $arch == amd64 ]]; then
      if [[ "$(find "$linux_tmp" -type f -executable | wc -l)" -eq 3 ]]; then
        mkdir -p "${LINUX_AMD_DIR}_tmp"
        find "$linux_tmp" -type f -executable -exec cp {} "${LINUX_AMD_DIR}_tmp" \;
        [[ -e "$LINUX_AMD_DIR" ]] && rm -r "$LINUX_AMD_DIR"
        mv "${LINUX_AMD_DIR}_tmp" "$LINUX_AMD_DIR"
      fi
    elif [[ $arch == arm64 ]]; then
      if [[ "$(find "$linux_tmp" -type f -executable | wc -l)" -eq 3 ]]; then
        mkdir -p "${LINUX_ARM_DIR}_tmp"
        find "$linux_tmp" -type f -executable -exec cp {} "${LINUX_ARM_DIR}_tmp" \;
        [[ -e "$LINUX_ARM_DIR" ]] && rm -r "$LINUX_ARM_DIR"
        mv "${LINUX_ARM_DIR}_tmp" "$LINUX_ARM_DIR"
      fi
    fi

    [[ -d "$linux_tmp" ]] && rm -r "$linux_tmp"
  fi

  if [[ "$OSTYPE" == "freebsd"* ]]; then
    if [[ "$(find "$bsd_tmp" -type f -executable | wc -l)" -eq 2 ]]; then
      mkdir -p "${BSD_DIR}_tmp"
      find "$bsd_tmp" -type f -executable -exec cp {} "${BSD_DIR}_tmp" \;
      [[ -e "$BSD_DIR" ]] && rm -r "$BSD_DIR"
      mv "${BSD_DIR}_tmp" "$BSD_DIR"
    fi

    [[ -d "$bsd_tmp" ]] && rm -r "$bsd_tmp"
  fi
}

if [[ "${#BASH_SOURCE[@]}" -eq 1 ]]; then
  _download_utils
fi
