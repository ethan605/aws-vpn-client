set -Eeuo pipefail

# Start squid early to receive requests from proxy audiences
# before VPN connection up
echo "Starting squid..."
sudo /usr/sbin/squid

# Connect to VPN
./build/aws-vpn-client -ovpn ./build/openvpn -config ./ovpn.conf -on-challenge=listen -debug
