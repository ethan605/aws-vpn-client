set -Eeuo pipefail

# Start squid early to receive requests from proxy audiences
# before VPN connection up
echo "Starting squid..."
sudo /usr/sbin/squid

# Connect to VPN
./aws-vpn-client -ovpn ./openvpn -config ./ovpn.conf -on-challenge=auto -debug
