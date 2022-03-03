set -Eeuo pipefail

cd /home/vpn/app/

OUT_DIR=build
OUT_BIN=aws-vpn-client

rm -rf "$OUT_DIR/{$OUT_BIN,openvpn}"
cp ../openvpn "$OUT_DIR/"

go build \
  -ldflags '-s -w' \
  -gcflags '-N -l' \
  -o "$OUT_DIR/$OUT_BIN" .
