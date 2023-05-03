# AWS VPN Client

A CLI solution to enable Linux distros to connect to AWS VPN infrastructure with SAML SSO,
heavily based on [an existing solution](https://smallhacks.wordpress.com/2020/07/08/aws-client-vpn-internals/)
([repo](https://github.com/samm-git/aws-vpn-client)).

## Prerequisites

- Linux (of course!).
- `docker` and `docker-compose`.
- A suitable DNS solution for your system. For instance,
  [Arch Linux mentioned a custom script maintained by OpenVPN](https://wiki.archlinux.org/title/OpenVPN#DNS).
  This should be updated to `ovpn.conf` file.

## Configuration

This solution requires a modified version of OpenVPN client.

### Make the binaries

To obtain both the CLI and the patched OpenVPN client, run:

```shell
$ OPENVPN_VERSION=<latest_supported_version> docker compose up make
```

List of `<latest_supported_version>`'s is available at `/patches` folder.

Then in `./build` folder there should be 3 binaries:

- `openvpn-musl` for musl libc platforms.
- `openvpn-glibc` for glibc platforms.
- `aws-vpn-client`.

### Patch a new OpenVPN version

To generate a patch for a newer OpenVPN version, use the current latest as base:

```shell
$ FROM_VERSION=<current_latest> TO_VERSION=<upstream_latest> docker compose up gen-patch
```

The `<upstream_latest>` version can be found at [OpenVPN GitHub tags](https://github.com/OpenVPN/openvpn/tags).

### OpenVPN config file

Make sure you have:

* `remote` option removed.
* `auth-retry interact` option removed.
* (Optionally) `inactive 3600` option added.

## Authenticate and connect to the VPN

Run:

```shell
$ ./connect.sh
  --cmd ./build/aws-vpn-client \          # optional, default to './build/aws-vpn-client'
  --ovpn ./build/openvpn-<variant> \      # optional, default to './build/openvpn-glibc'
  --config /path/to/openvpn.conf \        # optional, default to './build/ovpn.conf'
  --up /path/to/client-up-script \        # optional, default to './connect/vpn-client.up'
  --down /path/to/client-down-script      # optional, default to './connect/vpn-client.down'
```

where `<variant>` could be either `musl` or `glibc`

For all the supported flags, consult [Options for aws-vpn-client](#options-for-aws-vpn-client).

By default (with `-on-challenge=listen`), a URL will be automatically opened in your default browser.
Do all the necessary authentication steps and you should finally get
`Authentication details received, processing details. You may close this window at any time.`

You'll be successfully connected once you get something like this:

```
...
[timestamp] Successfully connected
```

with `-verbose` flag provided, you might get something like this:

```
...
[timestamp] net_route_v4_add: <ip> via <ip> dev [NULL] table 0 metric -1
[timestamp] Initialization Sequence Completed
[timestamp] Successfully connected
```

otherwise, it's failed if you get:

```
[timestamp] Connection rejected, please re-run to try again
```

## Under the hood

The `aws-vpn-client` CLI runs in 3 phases:

1. Running without root access, expecting failure to get a response like this

    ```
    SENT CONTROL [your.server.domain]: 'PUSH_REQUEST' (status=1)
    AUTH: Received control message: AUTH_FAILED,CRV1:R:instance-1/<some_numeric_id>/<some_uuid>:b'<some_string>':https://your.authentication.server/some-uuid?SAMLRequest=<request_string>
    SIGTERM[soft,auth-failure] received, process exiting
    ```

    Notes that in the `AUTH: received control message: ...` line, we have `CRV1:R:<VPN_SID>:<CHALLENGE_URL>`.

2. Open your default browser to visit the `CHALLENGE_URL`.

3. Running with root access, concatenates the above `VPN_SID` value with
  the retrieved `SAML_RESPONSE` string, feeds it to `--auth-user-pass` param of `openvpn`.

## Options for aws-vpn-client

`aws-vpn-client` accepts these flags:

```
  -ovpn string
    	path to OpenVPN binary (default "./openvpn")
  -config string
    	path to OpenVPN config (default "./ovpn.conf")
  -on-challenge string
    	"auto" (follow and parse challenge URL) or "listen" (spawn a SAML server and wait) (default "listen")
  -verbose
    	print more logs
```

When any flags are absent, the client will lookup for environment variables
before fallback to the default value:

- `AWS_VPN_OVPN_BIN` for `-ovpn`.
- `AWS_VPN_OVPN_CONF` for `-config`.
- `AWS_VPN_ON_CHALLENGE` for `-on-challenge`.
- `AWS_VPN_VERBOSE` for `-verbose`. This accepts `1, t, T, TRUE, true, True` as `true`, otherwise `false`.

# On Arch Linux with `systemd`

Under `arch-linux` folder, there's 2 files that enable Arch Linux users to integrate `aws-vpn-client` with `systemd`:

- `PKGBUILD`: to install `aws-vpn-client` as a `pacman` package.
- `aws-vpn-client.service` to run as a `--user` service.

## Install

Just run `make`, it'll prepare, install & clean-up the build files

## Configuration

- Before running, copy (or symlink) your OpenVPN config file `ovpn.conf` to `/home/$USER/.config/aws-vpn-client/` directory.
  The `connect.sh` script will look for the config file at this location.
- Because OpenVPN needs `sudo` privilege, and it (`sudo`) doesn't work with `--user` systemd service,
  you need to whitelist it in `/etc/sudoers` with something like:
  ```
  <username> ALL=NOPASSWD: /usr/lib/aws-vpn-client/openvpn
  ```

## Running

Now you can connect to AWS VPN using:

```shell
$ systemctl --user start aws-vpn-client
```

The service will be auto-reconnecting (with a delay of 1s) whenever the `connect.sh` fails,
e.g. when `openvpn` receives `SIGUSR1` from suspend.

# Gen
