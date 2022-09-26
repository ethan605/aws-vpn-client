# Build openvpn with musl libc
FROM alpine:3.15 as ovpn-musl

RUN apk add --no-cache \
    autoconf=2.71-r0 \
    automake=1.16.4-r1 \
    curl=7.80.0-r3 \
    go=1.17.10-r0 \
    libtool=2.4.6-r7 \
    linux-headers=5.10.41-r0 \
    linux-pam-dev=1.5.2-r0 \
    lzo-dev=2.10-r2 \
    make=4.3-r0 \
    openssl-dev=1.1.1q-r0 \
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

# Build openvpn with glibc
FROM debian:11-slim as ovpn-glibc

RUN apt-get update \
    && apt-get --no-install-recommends -y install \
      autoconf=2.69-14 \
      automake=1:1.16.3-2 \
      ca-certificates=20210119 \
      curl=7.74.0-1.3+deb11u3 \
      liblz4-dev=1.9.3-2 \
      liblzo2-dev=2.10-2 \
      libpam0g-dev=1.4.0-9+deb11u1 \
      libssl-dev=1.1.1n-0+deb11u3 \
      libtool=2.4.6-15 \
      make=4.3-4.1 \
      patch=2.7.6-7 \
      unzip=6.0-26+deb11u1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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
    go=1.17.10-r0

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
COPY --from=ovpn-musl --chown=$USER:$USER openvpn/src/openvpn/openvpn openvpn-musl
COPY --from=ovpn-glibc --chown=$USER:$USER openvpn/src/openvpn/openvpn openvpn-glibc

ENTRYPOINT ["/bin/bash", "./app/entrypoint.sh"]
