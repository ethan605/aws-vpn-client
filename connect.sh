#!/usr/bin/env bash

BASE_DIR=$(realpath "$(dirname "$0")")
CMD_NAME="aws-vpn-client"

CMD_BIN="$BASE_DIR/build/$CMD_NAME"
OPENVPN_BIN="$BASE_DIR/build/openvpn-glibc"
OPENVPN_CONF="$BASE_DIR/build/ovpn.conf"
VPN_CLIENT_UP="$BASE_DIR/connect/vpn-client.up"
VPN_CLIENT_DOWN="$BASE_DIR/connect/vpn-client.down"

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
      --cmd)
        CMD_BIN=$(parse_option_arg "$@")
        shift 2
        ;;
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
  debug
  connect
}

function debug() {
  echo "Connecting to AWS VPN using:"
  echo "CMD_BIN=$CMD_BIN"
  echo "OPENVPN_BIN=$OPENVPN_BIN"
  echo "OPENVPN_CONF=$OPENVPN_CONF"
  echo "VPN_CLIENT_UP=$VPN_CLIENT_UP"
  echo "VPN_CLIENT_DOWN=$VPN_CLIENT_DOWN"
}

function connect() {
  "$CMD_BIN" \
    -ovpn "$OPENVPN_BIN" \
    -config "$OPENVPN_CONF" \
    -verbose \
    2>| "/tmp/$CMD_NAME.log" \
    >| "/tmp/$CMD_NAME.saml"

  REMOTE_IP=$(grep 'Remote IP:' "/tmp/$CMD_NAME.log" | cut -d' ' -f5)

  sudo "$OPENVPN_BIN" \
    --config "$OPENVPN_CONF" \
    --remote "$REMOTE_IP" 443 \
    --up "$VPN_CLIENT_UP" \
    --down "$VPN_CLIENT_DOWN" \
    --route-up "/usr/bin/env rm /tmp/$CMD_NAME.saml" \
    --auth-user-pass /tmp/$CMD_NAME.saml
}

main "$@"
