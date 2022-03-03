set -Eeuo pipefail

# Start squid early to receive requests from proxy audiences
# before VPN connection up
echo "Starting squid..."
sudo /usr/sbin/squid

./build/aws-vpn-client
