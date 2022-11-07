#!/usr/bin/env bash

COMMAND_NAME="aws-vpn-client"
OPENVPN_BIN="./build/openvpn-glibc"
OPENVPN_CONF="./build/ovpn.conf"
VPN_CLIENT_UP="./connect/vpn-client.up"
VPN_CLIENT_DOWN="./connect/vpn-client.down"

function parse_option_arg() {
  if [[ -n "${2-}" ]] && [[ ${2:0:1} != "-" ]]; then
    echo "$2"
  else
    echo "Argument for $1 is missing"
    exit 1
  fi
}

function parse_args() {
  while (( "$#" )); do
    case "$1" in
      --ovpn)
        OPENVPN_BIN=$(parse_option_arg "$@")
        shift 2
        ;;
      --conf)
        OPENVPN_CONF=$(parse_option_arg "$@")
        shift 2
        ;;
      --up)
        VPN_CLIENT_UP=$(parse_option_arg "$@")
        shift 2
        ;;
      --down)
        VPN_CLIENT_DOWN=$(parse_option_arg "$@")
        shift 2
        ;;
    esac
  done
}

function main() {
  parse_args "$@"

  "./build/$COMMAND_NAME" \
    -ovpn "$OPENVPN_BIN" \
    -config "$OPENVPN_CONF" \
    -verbose \
    2>| "/tmp/$COMMAND_NAME.log" \
    >| "/tmp/$COMMAND_NAME.saml"

  REMOTE_IP=$(grep 'Remote IP:' "/tmp/$COMMAND_NAME.log" | cut -d' ' -f5)

  sudo "$OPENVPN_BIN" \
    --config "$OPENVPN_CONF" \
    --remote "$REMOTE_IP" 443 \
    --up "$VPN_CLIENT_UP" \
    --down "$VPN_CLIENT_DOWN" \
    --route-up "/usr/bin/env rm /tmp/$COMMAND_NAME.saml" \
    --auth-user-pass /tmp/$COMMAND_NAME.saml
}

main "$@"
