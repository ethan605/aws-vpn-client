# AWS VPN Client

A CLI and Docker solution to enable Linux distros to connect to AWS VPN infrastructure with SAML SSO,
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

To obtain both the CLI and the patched OpenVPN client, run:

```shell
$ docker compose up make
```

Then in `./build` folder there should be 2 binaries `openvpn` and `aws-vpn-client`.

## Authenticate and connect to the VPN

Run:

```shell
$ ./build/aws-vpn-client -ovpn path/to/openvpn -config /path/to/openvpn.conf
```

For all the supported flags, consult [Options for aws-vpn-client](#options-for-aws-vpn-client).

By default (with `-on-challenge=listen`), a URL will be automatically opened in your default browser.
Do all the necessary authentication steps and you should finally get
`Authentication details received, processing details. You may close this window at any time.`

You'll be successfully connected once you get something like this:

```
...
[timestamp] Successfully connected
```

with `-debug` flag provided, you might get something like this:

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
    	auto (follow and parse challenge URL) or listen (spawn a SAML server and wait) (default "follow")
  -verbose
    	print more logs
```

When any flags are absent, the client will lookup for environment variables
before fallback to the default value:

- `AWS_VPN_OVPN_BIN` for `-ovpn`.
- `AWS_VPN_OVPN_CONF` for `-config`.
- `AWS_VPN_ON_CHALLENGE` for `-on-challenge`.
- `AWS_VPN_VERBOSE` for `-verbose`. This accepts `1, t, T, TRUE, true, True` as `true`, otherwise `false`.

## Automatically resolve challenge URL (experimental feature)

By default, `aws-vpn-client` will run with `-on-challenge=listen`. This means that
a local server will be spawned on port `35001` to listen for the SAML response from AWS VPN
(don't worry, that server will be destroyed as soon as it receives the response,
so no long-lasting service in your background at all).

However, that's cumbersome because the tool itself is not fully automated.
To solve this, you can try `-on-challenge=auto` with some prerequisites:

- You understand how your authentication server works, ie. how it's doing the authentication part
  of the `CHALLENGE_URL`. Normally it'll be a piece of `cookie`.
- Either export or pass the necessary `cookie` value to the env var `CHALLENGE_URL_COOKIE`.
- Run with `./aws-vpn-client <... other flags> -on-challenge=auto`

## Connect to VPN from Docker

Using `connect` service in `docker-compose.yml`, you can spawn a Docker container to isolate the VPN connection.
This is convenient when you don't want to mess up with the host's networks.

Caveats: this is a very opinionated way to use the VPN from Docker. Customise if needed and use it at your own risks!

### Dependencies

The `connect` service installs several additional packages:

- [`dropbear`](https://matt.ucc.asn.au/dropbear/dropbear.html) to serve the container as a proxy SSH server.
  SSH connections can be routed via `localhost:2222` with `ProxyCommand` config in the host `~/.ssh/config`:

  ```config
  Host *
    # ...

  Host your.private.server
    ProxyCommand ssh vpn@localhost -p 2222 nc %h %p
  ```

- [`squid`](http://www.squid-cache.org/) to serve the container as a proxy HTTP/HTTPS server via `localhost:3128`.

### Preparation

- Use `docker compose up make` to prepare `openvpn` and `aws-vpn-client` in `build/` folder.
- Make a `connect/authorized_keys` file with the content of your `~/.ssh/id_*.pub`.
  This is for `dropbear` to authorise the SSH connections from the host.

### Configuration

The `entrypoint.sh` of `connect` comes with no flags for `aws-vpn-client` for the ease of
options control via environment variables.

```yaml
# ...
  connect:
    # ...
    environment:
      - AWS_VPN_OVPN_BIN=./build/openvpn
      - AWS_VPN_OVPN_CONF=./build/ovpn.conf
      - AWS_VPN_ON_CHALLENGE=auto
      - AWS_VPN_VERBOSE=true
      - CHALLENGE_URL_COOKIE
    # ...
```

You need to modify the template `connect/ovpn.conf` and place the complete `ovpn.conf` file to `build/ovpn.conf`
(the `build` folder is git-ignored.) Remember to:
- Update the correct `remote` server.
- Update the correct CA certificates in `<ca></ca>` block.
- Append to the end of the file:
  ```config
  up /usr/bin/vpn-client.up
  down /usr/bin/vpn-client.down
  ```
  (those scripts are properly copied and chmoded in the container during build).

Depending on your preferences, set `AWS_VPN_ON_CHALLENGE=auto` along with a valid `CHALLENGE_URL_COOKIE` env var,
or use `AWS_VPN_ON_CHALLENGE=listen` as an easier setup.

### Running

- Use `docker compose up -d connect` to connect in detached mode.
- Use `docker compose logs -f connect` to view output from `aws-vpn-client`.
- If connecting in `AWS_VPN_ON_CHALLENGE=listen` mode, run:

  ```shell
  $ docker compose logs --tail 2 connect | grep -Eo 'https://.+' | xargs -I {} xdg-open {}
  ```

  (or `xargs -n1 open` on macOS) to visit the challenge URL automatically.

### Caveats and troubleshootings

- Sometimes `squid` won't boot up after the container was stopped and started again.
  Run `docker compose exec connect sudo /usr/sbin/squid` to manually start it,
  or simply remove the dead container and spawn a new one.
- Each time image gets fresh built (without caches), it'll generate a new set of host keys
  (placed in `/etc/dropbear/` in the container). If you have run the container before
  and now trying to do a proxied SSH connection, you might get blocked with a message:
  ```
  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
  Someone could be eavesdropping on you right now (man-in-the-middle attack)!
  It is also possible that a host key has just been changed.
  The fingerprint for the ECDSA key sent by the remote host is
  SHA256:<some-key>.
  Please contact your system administrator.
  Add correct host key in /home/username/.ssh/known_hosts to get rid of this message.
  Offending ECDSA key in /home/username/.ssh/known_hosts:30
  Host key for [localhost]:2222 has changed and you have requested strict checking.
  Host key verification failed.
  kex_exchange_identification: Connection closed by remote host
  Connection closed by UNKNOWN port 65535
  ```
  then simply remove the old `[localhost]:2222` line in `~/.ssh/known_hosts` to generate a new one.
