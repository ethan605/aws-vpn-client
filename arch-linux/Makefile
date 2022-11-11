all: prepare install cleanup

prepare:
	@cp ../connect.sh .; \
		cp ../build/aws-vpn-client .; \
		cp ../build/openvpn-glibc openvpn; \
		cp ../connect/vpn-client.* .

sha512sums: prepare
	@sha512sum aws-vpn-client{,.service} connect.sh openvpn vpn-client.{up,down}

install:
	@makepkg --cleanbuild --noconfirm --syncdeps --install --needed --clean --asdeps

cleanup:
	@rm -rf connect.sh aws-vpn-client openvpn vpn-client.* *.pkg.tar.zst
