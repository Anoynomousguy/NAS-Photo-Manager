# User guide — connecting the client to any WebDAV server

This client speaks plain WebDAV. It does not know or care whose server you point it at: anything
that answers WebDAV at an HTTPS URL will work. Nothing in this guide refers to a particular
deployment.

## What you need before you start

| Item | Example | Notes |
| --- | --- | --- |
| Server URL | `https://<webdav-host>/dav` | scheme + host + the WebDAV path your server uses |
| Username | `YOUR_USERNAME` | the account your server issued you |
| Password or app password | — | see below |

Many servers put WebDAV on a subpath (`/dav`, `/remote.php/dav`, `/webdav`). If you enter only the
host, the client will list the wrong root and appear empty. Check your server's documentation for
the exact path.

## First run

1. Open the app. The first screen asks for a server.
2. Enter the full URL, including `https://` and the WebDAV path.
3. Enter the username and password.
4. Save. The client immediately lists the root of your WebDAV tree.

The app normalises a missing scheme and trailing slashes, so `host/dav` becomes
`https://host/dav`. It cannot guess a missing path — that is the most common cause of an empty
listing.

## Use an app password, not your main password

If your server offers app passwords (also called application passwords or tokens), generate one
for this client and use that. It survives a password change, can be revoked on its own, and works
when the account has second-factor authentication that a WebDAV client cannot complete.

An app password is a credential. Treat it like one: it is stored on the device, so revoke it if
the device is lost.

## Offline behaviour

- Directory listings and thumbnails that have already been fetched are cached on the device.
- Browsing cached folders works with no connection.
- Uploads made offline are queued and retried when connectivity returns.
- Folders you have never opened are not cached; the app shows the offline banner rather than an
  error.
- Nothing is deleted locally because the server was unreachable.

## Troubleshooting

| Symptom | Likely cause | What to do |
| --- | --- | --- |
| `401 Unauthorized` | wrong username/password, or an app password is required | regenerate an app password; confirm the username is not an email alias your server does not accept |
| `403 Forbidden` | credentials valid, path not permitted | check that the account has access to that path |
| `404 Not Found` | wrong WebDAV path | confirm the path from the server's documentation; try listing the host root in a browser |
| Empty listing, no error | authenticated against the wrong root | add the correct path suffix |
| Certificate error | self-signed or hostname mismatch | use a certificate the device trusts; the client will not silently ignore a bad certificate |
| Timeouts on a VPN or tailnet | device not connected, or DNS not resolving | confirm the client device is on the network and the hostname resolves |
| Uploads fail at the end | server quota or maximum body size | check server quota and the reverse proxy's body-size limit |

## Related repositories

The operational documentation for the reference deployment behind this client lives in a **private**
repository and is not published here. This repository ships only client-facing material.
