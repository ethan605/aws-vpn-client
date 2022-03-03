set -Eeuo pipefail

ls -lah .

# Start squid early to receive requests from proxy audiences
# before VPN connection up
#echo "Starting squid..."
#sudo /usr/sbin/squid

#./aws-vpn-client -ovpn ./openvpn -config ./ovpn.conf -on-challenge=listen -debug
