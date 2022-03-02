# AWS VPN Client

A CLI and Docker solution to enable Linux distros to connect to AWS VPN infrastructure with SAML SSO,
based on [an online solution](https://smallhacks.wordpress.com/2020/07/08/aws-client-vpn-internals/).

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

otherwise, it failed if you get:

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
  -config string
    	path to OpenVPN config (default "./ovpn.conf")
  -ovpn string
    	path to OpenVPN binary (default "./openvpn")
  -on-challenge string
    	auto (follow and parse challenge URL) or listen (spawn a SAML server and wait) (default "listen")
  -debug
      debug mode
```

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
