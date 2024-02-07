# Build openvpn with musl libc
FROM alpine:3.19.1 as ovpn-musl

RUN apk add --no-cache \
    autoconf=2.71-r2 \
    automake=1.16.5-r2 \
    curl=8.5.0-r0 \
    go=1.21.6-r0 \
    libcap-ng-dev=0.8.3-r4 \
    libnl3-dev=3.9.0-r0 \
    libtool=2.4.7-r3 \
    linux-headers=6.5-r0 \
    linux-pam-dev=1.5.3-r7 \
    lz4-dev=1.9.4-r5 \
    lzo-dev=2.10-r5 \
    make=4.4.1-r2 \
    openssl-dev=3.1.4-r5 \
    patch=2.7.6-r10 \
    unzip=6.0-r14

# Patch & build OpenVPN
ARG OPENVPN_VERSION=2.6.3

RUN curl -L "https://github.com/OpenVPN/openvpn/archive/v${OPENVPN_VERSION}.zip" -o openvpn.zip \
    && unzip openvpn.zip \
    && mv "openvpn-${OPENVPN_VERSION}" openvpn

WORKDIR /
COPY "patches/openvpn-v${OPENVPN_VERSION}-aws.patch" openvpn/aws.patch

WORKDIR /openvpn
RUN patch -p1 < aws.patch \
    && autoreconf -ivf \
    && ./configure \
    && make

# Build openvpn with glibc
FROM debian:12-slim as ovpn-glibc

RUN apt-get update \
    && apt-get --no-install-recommends -y install \
      autoconf=2.71-3 \
      automake=1:1.16.5-1.3 \
      ca-certificates=20230311 \
      curl=7.88.1-10+deb12u5 \
      libcap-ng-dev=0.8.3-1+b3 \
      liblz4-dev=1.9.4-1 \
      liblzo2-dev=2.10-2 \
      libnl-genl-3-dev=3.7.0-0.2+b1 \
      libpam0g-dev=1.5.2-6+deb12u1 \
      libssl-dev=3.0.11-1~deb12u2 \
      #libssl-dev=1.1.1w-0+deb11u1 \
      libtool=2.4.7-5 \
      make=4.3-4.1 \
      patch=2.7.6-7 \
      pkg-config=1.8.1-1 \
      unzip=6.0-28 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Patch & build OpenVPN
ARG OPENVPN_VERSION=2.6.3

RUN curl -L "https://github.com/OpenVPN/openvpn/archive/v${OPENVPN_VERSION}.zip" -o openvpn.zip \
    && unzip openvpn.zip \
    && mv "openvpn-${OPENVPN_VERSION}" openvpn

WORKDIR /
COPY "patches/openvpn-v${OPENVPN_VERSION}-aws.patch" openvpn/aws.patch

WORKDIR /openvpn
RUN patch -p1 < aws.patch \
    && autoreconf -ivf \
    && ./configure \
    && make

# Build aws-vpn-client
FROM alpine:3.19.1

RUN apk add --no-cache \
    bash=5.2.21-r0 \
    go=1.21.6-r0

# CGO_ENABLED=0 for static linking
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

ARG USER=vpn
RUN adduser --disabled-password --gecos '' ${USER} \
    && mkdir -p app

WORKDIR "/home/${USER}"
USER ${USER}:${USER}

# Copy entrypoint script into the container
COPY --chown=$USER:$USER entrypoints/make.sh entrypoint.sh

# Copy openvpn binaries into the container
COPY --from=ovpn-musl --chown=$USER:$USER openvpn/src/openvpn/openvpn openvpn-musl
COPY --from=ovpn-glibc --chown=$USER:$USER openvpn/src/openvpn/openvpn openvpn-glibc

ENTRYPOINT ["/bin/bash", "entrypoint.sh"]
