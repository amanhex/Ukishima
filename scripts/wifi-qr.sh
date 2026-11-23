#!/bin/bash
# Generate a Wi-Fi QR matrix for the shell.
#
# Usage: wifi-qr.sh [--meta] [interface]
#
# --meta emits one tab-separated header before the matrix:
#   meta<TAB>interface<TAB>security<TAB>ssid
# The SSID is last so it may contain tabs. The matrix is one 0/1 row per line,
# using the same ASCII-to-bit conversion as Omarchy's omarchy-network-qr.

set -euo pipefail

command -v qrencode >/dev/null 2>&1 || {
  echo "qrencode is not installed" >&2
  exit 1
}
command -v nmcli >/dev/null 2>&1 || {
  echo "nmcli is not installed" >&2
  exit 1
}

interface=""
emit_meta=false
for arg in "$@"; do
  case "$arg" in
    --meta) emit_meta=true ;;
    *) interface=$arg ;;
  esac
done

if [[ -z $interface ]]; then
  # Prefer the default-route device: it is the connection the panel describes.
  # Fall back to the first connected Wi-Fi device. nmcli localizes state names,
  # so pin the locale; the prefix match accepts "connected (externally)" too.
  if ! route_device=$(ip route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }'); then
    route_device=""
  fi
  if [[ -n $route_device && -d /sys/class/net/$route_device/wireless ]]; then
    interface=$route_device
  else
    interface=$(LC_ALL=C nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null |
      awk -F: '$2 == "wifi" && $3 ~ /^connected/ { print $1; exit }')
  fi
fi
[[ -n $interface ]] || { echo "No active Wi-Fi connection" >&2; exit 1; }

uuid=$(nmcli --get-values GENERAL.CON-UUID device show "$interface" | head -n 1)
[[ -n $uuid && $uuid != "--" ]] || { echo "No active Wi-Fi connection" >&2; exit 1; }

mapfile -t fields < <(nmcli --show-secrets --escape no --get-values \
  802-11-wireless.ssid,802-11-wireless-security.key-mgmt,802-11-wireless-security.psk,802-11-wireless.hidden,802-11-wireless-security.wep-key0 \
  connection show uuid "$uuid")

ssid=${fields[0]:-}
key_management=${fields[1]:-}
password=${fields[2]:-}
hidden=${fields[3]:-no}
wep_key=${fields[4]:-}

[[ -n $ssid ]] || { echo "Could not read the Wi-Fi name" >&2; exit 1; }
[[ $key_management != *eap* && $key_management != *ieee8021x* ]] || {
  echo "Enterprise Wi-Fi cannot be shared with a password QR code" >&2
  exit 1
}

escape_wifi_qr() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//;/\\;}
  value=${value//,/\\,}
  value=${value//:/\\:}
  printf '%s' "$value"
}

if [[ -n $key_management && $key_management != "none" ]]; then
  [[ -n $password ]] || { echo "Could not read the Wi-Fi password" >&2; exit 1; }
  security=WPA
elif [[ -n $wep_key ]]; then
  # NetworkManager models WEP as key-mgmt "none" plus a wep-key; encoding it as
  # an open network would produce a QR that silently fails to join.
  password=$wep_key
  security=WEP
else
  security=nopass
fi

payload="WIFI:T:$security;S:$(escape_wifi_qr "$ssid");P:$(escape_wifi_qr "$password");"
[[ $hidden == "yes" ]] && payload+="H:true;"
payload+=";"

[[ $emit_meta == "true" ]] && printf 'meta\t%s\t%s\t%s\n' "$interface" "$security" "$ssid"

# ASCII uses two characters per module. Collapse each pair to one 0/1 value so
# the shell can render a square matrix directly with native QML rectangles.
# Margin 4 is the spec quiet zone; the share card surround is dark, so this
# white border is all the scanner gets.
ascii=$(printf '%s' "$payload" | qrencode --type ASCII --margin 4 --output -)
while IFS= read -r line; do
  row=
  for ((column = 0; column < ${#line}; column += 2)); do
    [[ ${line:column:2} == *#* ]] && row+=1 || row+=0
  done
  printf '%s\n' "$row"
done <<<"$ascii"
