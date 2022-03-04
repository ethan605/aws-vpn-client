# vim:fileencoding=utf-8:filetype=Dockerfile
FROM alpine:3.15

RUN apk add --no-cache \
    bash=5.1.16-r0 \
    dropbear=2020.81-r0 \
    lzo=2.10-r2 \
    openssh=8.8_p1-r1 \
    squid=5.2-r0 \
    sudo=1.9.8_p2-r1 \
    && sed -iE 's/^#(http_access allow localnet)/\1/gi' /etc/squid/squid.conf \
    && mkdir -p /etc/dropbear \
    && dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key \
    && dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key \
    && dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key \
    && dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key

COPY connect/vpn-client.up connect/vpn-client.down /usr/bin/
RUN chmod +x /usr/bin/vpn-client.up /usr/bin/vpn-client.down

ARG USER=vpn

# hadolint ignore=DL4006
RUN echo "$USER ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$USER" \
    && chmod ug=r,o=- "/etc/sudoers.d/$USER" \
    && adduser --disabled-password --gecos '' "$USER"

WORKDIR "/home/$USER"
USER "$USER:$USER"

COPY --chown=$USER:$USER --chmod=u=rw,og=- connect/authorized_keys .ssh/authorized_keys
COPY --chown=$USER:$USER connect/entrypoint.sh entrypoint.sh

ENTRYPOINT ["/bin/bash", "entrypoint.sh"]
