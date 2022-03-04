# vim:fileencoding=utf-8:filetype=Dockerfile
# Build openvpn
FROM alpine:3.15 as ovpn-builder

RUN apk add --no-cache \
    autoconf=2.71-r0 \
    automake=1.16.4-r1 \
    curl=7.80.0-r0 \
    go=1.17.4-r0 \
    libtool=2.4.6-r7 \
    linux-headers=5.10.41-r0 \
    linux-pam-dev=1.5.2-r0 \
    lzo-dev=2.10-r2 \
    make=4.3-r0 \
    openssl-dev=1.1.1l-r8 \
    patch=2.7.6-r7 \
    unzip=6.0-r9

# Patch & build OpenVPN
ARG OPENVPN_VERSION=2.5.5

RUN curl -L "https://github.com/OpenVPN/openvpn/archive/v$OPENVPN_VERSION.zip" -o openvpn.zip \
    && unzip openvpn.zip \
    && mv "openvpn-$OPENVPN_VERSION" openvpn

WORKDIR /
COPY "openvpn-v$OPENVPN_VERSION-aws.patch" openvpn/aws.patch

WORKDIR /openvpn
RUN patch -p1 < aws.patch \
    && autoreconf -ivf \
    && ./configure \
    && make

# Build aws-vpn-client
FROM alpine:3.15

RUN apk add --no-cache \
    bash=5.1.16-r0 \
    go=1.17.4-r0

# CGO_ENABLED=0 for static linking
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

ARG USER=vpn
RUN adduser --disabled-password --gecos '' $USER \
    && mkdir -p app

WORKDIR "/home/$USER/app"
USER "$USER:$USER"

# Copy and download dependency using go mod
COPY --chown=$USER:$USER go.mod go.sum ./
RUN go mod download

# Copy the code into the container
COPY --chown=$USER:$USER main.go main.go
COPY --chown=$USER:$USER pkg pkg
COPY --chown=$USER:$USER entrypoint.sh entrypoint.sh

WORKDIR "/home/$USER"
COPY --from=ovpn-builder --chown=$USER:$USER openvpn/src/openvpn/openvpn openvpn

ENTRYPOINT ["/bin/bash", "./app/entrypoint.sh"]
