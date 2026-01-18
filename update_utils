#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="$HOME/.config/bin"

BSD_DIR="$BIN_DIR/freeBSD"
LINUX_ARM_DIR="$BIN_DIR/linux_arm64"
LINUX_AMD_DIR="$BIN_DIR/linux_amd64"

REPOS=(
  "sharkdp/bat"
  "junegunn/fzf"
  "gokcehan/lf"
  "ajeetdsouza/zoxide"
)

_download_utils() {
  if ! hash curl 2> /dev/null; then echo "curl is not installed" return 1; fi

  local linux_tmp
  local linux_url
  local bsd_tmp
  local bsd_url
  local lx_filename
  local bsd_filename
  local url
  local _arch
  local arch

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if hash lscpu 2> /dev/null; then
      _arch="$(lscpu | grep 'Architecture' | cut -d ':' -f 2)"
      _arch="${_arch#"${_arch%%[![:space:]]*}"}"
    else
      _arch='x86_64'
    fi
    case "$_arch" in
      unknown) arch="amd64" ;;
      aarch64) arch="arm64" ;;
      *) arch="amd64" ;;
    esac

    echo "Fetching linux binaries for $arch architecture..."
    linux_tmp="/tmp/tmp.linux$(date +%m%d%H%M%S)"
    [[ ! -d $linux_tmp ]] && mkdir -p "$linux_tmp/bin"
  fi

  if [[ "$OSTYPE" == "freebsd"* ]]; then
    arch="$(sysctl -a | grep 'machine' | head -1 | cut -f 2)"
    if [[ -z $arch ]]; then return 1; fi

    echo "Fetching freeBSD binaries ..."
    bsd_tmp="/tmp/tmp.bsd$(date +%m%d%H%M%S)"
    [[ ! -d $bsd_tmp ]] && mkdir -p "$bsd_tmp/bin"
  fi

  for repo in "${REPOS[@]}"; do
    url="$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep 'browser_download_url.*')"

    # fetch linux amd64/arm64 binaries
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      if [[ $url == *linux* ]]; then
        # second grep stops at first match
        linux_url="$(echo "$url" | grep -o 'https://[^"]*' |
          grep -m 1 "${_arch}-unknown-linux-gnu.tar.gz\|linux.*${arch}.tar.gz\|${repo##*/}.*-${_arch}-unknown-linux-musl.tar")"
        lx_filename="${linux_url##*/}"
        echo "$linux_url"
        printf "Downloading %s... " "$lx_filename"
        if [[ ! -e "$linux_tmp/$lx_filename" ]]; then curl -s -L "$linux_url" -o "$linux_tmp/$lx_filename"; fi
        tar xf "$linux_tmp/$lx_filename" --directory "$linux_tmp/bin"
        echo "Done."
      fi
    fi

    # fetch amd64 bsd binaries
    if [[ "$OSTYPE" == "freebsd"* ]]; then
      if [[ $url == *freebsd* ]]; then
        bsd_url="$(echo "$url" | grep -o 'https://[^"]*' | grep "freebsd.*${arch}.tar.gz")"
        bsd_filename="${bsd_url##*/}"
        printf "Downloading %s... " "$bsd_filename"
        if [[ ! -e "$bsd_tmp/$bsd_filename" ]]; then curl -s -L "$bsd_url" -o "$bsd_tmp/$bsd_filename"; fi
        tar xf "$bsd_tmp/$bsd_filename" --directory "$bsd_tmp/bin"
        echo "Done."
      fi
    fi
  done

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [[ $arch == amd64 ]]; then
      if [[ "$(find "$linux_tmp" -type f -executable | wc -l)" -eq "${#REPOS[@]}" ]]; then
        mkdir -p "${LINUX_AMD_DIR}_tmp"
        find "$linux_tmp" -type f -executable -exec cp {} "${LINUX_AMD_DIR}_tmp" \;
        [[ -e "$LINUX_AMD_DIR" ]] && rm -r "$LINUX_AMD_DIR"
        mv "${LINUX_AMD_DIR}_tmp" "$LINUX_AMD_DIR"
        echo "Binary files located in $LINUX_AMD_DIR"
        touch "${LINUX_AMD_DIR}/.gitkeep"
      fi
    elif [[ $arch == arm64 ]]; then
      if [[ "$(find "$linux_tmp" -type f -executable | wc -l)" -eq "${#REPOS[@]}" ]]; then
        mkdir -p "${LINUX_ARM_DIR}_tmp"
        find "$linux_tmp" -type f -executable -exec cp {} "${LINUX_ARM_DIR}_tmp" \;
        [[ -e "$LINUX_ARM_DIR" ]] && rm -r "$LINUX_ARM_DIR"
        mv "${LINUX_ARM_DIR}_tmp" "$LINUX_ARM_DIR"
        echo "Binary files located in $LINUX_ARM_DIR"
        touch "${LINUX_ARM_DIR}/.gitkeep"
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
      echo "Binary files located in $BSD_DIR"
      touch "${BSD_DIR}/.gitkkeep"
    fi

    [[ -d "$bsd_tmp" ]] && rm -r "$bsd_tmp"
  fi
}

if [[ "${#BASH_SOURCE[@]}" -eq 1 ]]; then
  _download_utils
fi
