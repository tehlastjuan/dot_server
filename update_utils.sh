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
  local linux_arm_tmp
  local linux_arm_url
  local linux_amd_tmp
  local linux_amd_url
  local bsd_tmp
  local bsd_url
  local lx_arm_filename
  local lx_amd_filename
  local bsd_filename
  local url
  local arch

  arch="$(lscpu | grep 'Architecture' | cut -d ':' -f 2)"
  arch="${arch#"${arch%%[![:space:]]*}"}"

  case "$arch" in
    unknown) arch="amd64" ;;
    aarch64) arch="arm64" ;;
    *) arch="amd64" ;;
  esac

  linux_arm_tmp="/tmp/tmp.arm.linux$(date +%m%d%H%M%S)"
  [[ ! -d $linux_arm_tmp ]] && mkdir -p "$linux_arm_tmp/bin"

  linux_amd_tmp="/tmp/tmp.amd.linux$(date +%m%d%H%M%S)"
  [[ ! -d $linux_amd_tmp ]] && mkdir -p "$linux_amd_tmp/bin"

  bsd_tmp="/tmp/tmp.bsd$(date +%m%d%H%M%S)"
  [[ ! -d $bsd_tmp ]] && mkdir -p "$bsd_tmp/bin"

  for repo in "${REPOS[@]}"; do
    url="$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep 'browser_download_url.*')"

    # fetch linux arm64 binaries
    if [[ $url == *linux* ]]; then
      linux_arm_url="$(echo "$url" | grep -o 'https://[^"]*' | grep 'i686-unknown-linux-gnu.tar.gz\|linux.*arm64.tar.gz')"
      lx_arm_filename="${linux_arm_url##*/}"
      if [[ ! -e "$linux_arm_tmp/$lx_arm_filename" ]]; then wget -q -O "$linux_arm_tmp/$lx_arm_filename" "$linux_arm_url"; fi
      tar xf "$linux_arm_tmp/$lx_arm_filename" --directory "$linux_arm_tmp/bin"
    fi

    # fetch amd64 linux binaries
    if [[ $url == *linux* ]]; then
      linux_amd_url="$(echo "$url" | grep -o 'https://[^"]*' | grep 'i686-unknown-linux-gnu.tar.gz\|linux.*amd64.tar.gz')"
      lx_amd_filename="${linux_amd_url##*/}"
      if [[ ! -e "$linux_amd_tmp/$lx_amd_filename" ]]; then wget -q -O "$linux_amd_tmp/$lx_amd_filename" "$linux_amd_url"; fi
      tar xf "$linux_amd_tmp/$lx_amd_filename" --directory "$linux_amd_tmp/bin"
    fi

    # fetch bsd binaries
    if [[ $url == *freebsd* ]]; then
      bsd_url="$(echo "$url" | grep -o 'https://[^"]*' | grep 'freebsd.*amd64.tar.gz')"
      bsd_filename="${bsd_url##*/}"
      if [[ ! -e "$bsd_tmp/$bsd_filename" ]]; then wget -q -O "$bsd_tmp/$bsd_filename" "$bsd_url"; fi
      tar xf "$bsd_tmp/$bsd_filename" --directory "$bsd_tmp/bin"
    fi
  done

  if [[ "$(find "$linux_arm_tmp" -type f -executable | wc -l)" -eq 3 ]]; then
    mkdir -p "${LINUX_ARM_DIR}_tmp"
    find "$linux_arm_tmp" -type f -executable -exec cp {} "${LINUX_ARM_DIR}_tmp" \;
    [[ -e "$LINUX_ARM_DIR" ]] && rm -r "$LINUX_ARM_DIR"
    mv "${LINUX_ARM_DIR}_tmp" "$LINUX_ARM_DIR"
  fi

  if [[ "$(find "$linux_amd_tmp" -type f -executable | wc -l)" -eq 3 ]]; then
    mkdir -p "${LINUX_AMD_DIR}_tmp"
    find "$linux_amd_tmp" -type f -executable -exec cp {} "${LINUX_AMD_DIR}_tmp" \;
    [[ -e "$LINUX_AMD_DIR" ]] && rm -r "$LINUX_AMD_DIR"
    mv "${LINUX_AMD_DIR}_tmp" "$LINUX_AMD_DIR"
  fi

  if [[ "$(find "$bsd_tmp" -type f -executable | wc -l)" -eq 2 ]]; then
    mkdir -p "${BSD_DIR}_tmp"
    find "$bsd_tmp" -type f -executable -exec cp {} "${BSD_DIR}_tmp" \;
    [[ -e "$BSD_DIR" ]] && rm -r "$BSD_DIR"
    mv "${BSD_DIR}_tmp" "$BSD_DIR"
  fi

  rm -r "$linux_arm_tmp"
  rm -r "$linux_amd_tmp"
  rm -r "$bsd_tmp"
}

_download_utils
