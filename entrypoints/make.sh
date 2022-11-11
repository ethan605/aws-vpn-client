#!/usr/bin/env bash
set -Eeuo pipefail

cd /home/vpn/app

OUT_DIR=./build
OUT_BIN=aws-vpn-client

rm -rf "$OUT_DIR/{$OUT_BIN,openvpn-*}"
cp ../openvpn-musl "$OUT_DIR/"
cp ../openvpn-glibc "$OUT_DIR/"

go mod download

go build \
  -ldflags '-s -w' \
  -gcflags '-N -l' \
  -o "$OUT_DIR/$OUT_BIN" .
