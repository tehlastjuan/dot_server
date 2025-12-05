#!/usr/bin/env bash
# shellcheck disable=2046,2034

AMD64_NETINST_URL=https://cdimage.debian.org/debian-cd/current/amd64/bt-cd/
AMD64_DVD_URL=https://cdimage.debian.org/debian-cd/current/amd64/bt-dvd/

_chsum() {
  [ $# -lt 2 ] && return 1
  local dl_checksum
  local dl_file
  dl_checksum="$1"
  dl_file="$2"
  [ "$(sha256sum "$dl_file")" = "$dl_checksum  $dl_file" ] && {
    echo "Checksum OK" >&2 && return
  }
  echo "Checksum failed" >&2 && false

}

_get_netinst() {
  local url
  url="$(curl -s "$AMD64_NETINST_URL")"

  local version
  version="$(echo "$url" | sed -nr 's/.*debian-([0-9]+.[0-9]+.[0-9]+).*/\1/p' )"

  local -a filenames
  filenames=(
    #"debian-${version}-amd64-netinst.iso.torrent"
    SHA256SUMS
    #SHA256SUMS.sign
  )

  for file in "${filenames[@]}"; do
    echo "${AMD64_NETINST_URL}${file}"
    wget -qO "${file}-NETINST" "${AMD64_NETINST_URL}${file}"
  done

  _chsum $(cat "${file}-NETINST" | head -1)
}

_get_dvd() {
  local url
  url="$(curl -s "$AMD64_DVD_URL")"

  local version
  version="$(echo "$url" | sed -nr 's/.*debian-([0-9]+.[0-9]+.[0-9]+).*/\1/p' )"

  local -a filenames
  filenames=(
    #"debian-${version}-amd64-DVD-1.iso.torrent"
    SHA256SUMS
    #SHA256SUMS.sign
  )

  for file in "${filenames[@]}"; do
    echo "${AMD64_DVD_URL}${file}"
    wget -qO "${file}-DVD" "${AMD64_DVD_URL}${file}"
  done

  _chsum $(cat "${file}-DVD" | head -1)
}

_debiso() {
  _get_netinst
  _get_dvd
}

if [[ "${#BASH_SOURCE[@]}" -eq 1 ]]; then
  _debiso
fi
