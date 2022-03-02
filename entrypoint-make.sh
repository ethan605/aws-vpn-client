set -Eeuo pipefail

OUT_DIR=build
OUT_BIN=aws-vpn-client

rm -rf "$OUT_DIR/{openvpn,$OUT_BIN}"
cp openvpn/src/openvpn/openvpn "$OUT_DIR/"

cd "$OUT_BIN"
go build \
  -ldflags '-s -w' \
  -gcflags '-N -l' \
  -o "$OUT_BIN" .

cp "$OUT_BIN" "../$OUT_DIR/"
