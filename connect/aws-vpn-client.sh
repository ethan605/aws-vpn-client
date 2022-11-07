#!/usr/bin/env bash
go run main.go \
  -ovpn ./build/openvpn-glibc \
  -config ./build/ovpn.conf \
  -verbose \
  2>| /tmp/aws-vpn-client.log \
  >| /tmp/aws-vpn-client.saml

REMOTE_IP=$(grep 'Remote IP:' /tmp/aws-vpn-client.log | cut -d' ' -f5)

sudo ./build/openvpn-glibc \
  --config ./build/ovpn.conf \
  --remote "$REMOTE_IP" 443 \
  --up ./build/vpn-client.up \
  --down ./build/vpn-client.down \
  --route-up '/usr/bin/env rm /tmp/aws-vpn-client.saml' \
  --auth-user-pass /tmp/aws-vpn-client.saml
