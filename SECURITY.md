# NAS Photo Manager security notes

The client is intentionally conservative about transport, stored credentials
and embedded web content. These are the implemented boundaries and the limits
of the guarantee.

## Transport and credentials

- WebDAV URLs must be `https://`. The URL is rejected if it contains embedded
  credentials, a query, a fragment, an encoded traversal segment or a
  backslash. The default endpoint is HTTPS on the private tailnet.
- Basic credentials are kept in the platform secure store (Android
  Keystore-backed storage / iOS Keychain). They are never compiled into the app
  or written to the repository. The settings screen only displays a password
  after the user explicitly reveals it.
- Remote paths are normalized and checked for `.` / `..` segments before any
  list, upload or download. Gallery entries with unsafe paths are discarded.
- Downloads with a known size over `WebdavService.maxDownloadBytes` (512 MiB)
  are refused before the connection is opened. This is a guard, not a streaming
  quota: an untrusted server can still lie about the size.

## Platform hardening

- Android disables application backup, cleartext traffic and legacy external
  storage, and uses a base network security config that permits only HTTPS.
- iOS no longer sets `NSAllowsArbitraryLoads`; ATS defaults apply, so HTTP is
  rejected. Local-network access still requires the user's permission.
- The AI WebView is locked to the scheme, host and effective port of `AI_URL`.
  Navigation to any other HTTPS origin or scheme is blocked. If an AI provider
  needs an external OAuth/identity-provider redirect, add that exact origin to
  the allowlist deliberately; it is blocked today by design.
- Offline mode uses a DNS probe of the configured NAS/AI host, not a generic
  public website, so the UI reflects reachability of the actual service.

## Release signing

The release build no longer falls back to the public Android debug key. Put
your keystore parameters in `android/key.properties` (already ignored by git):

```properties
storePassword=...
keyPassword=...
keyAlias=...
storeFile=../keystore.jks
```

Without that file the release APK is left unsigned rather than being signed
with a key anyone can reproduce. Debug builds continue to use the debug key.

## Verification performed

- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- iOS/Android release builds require the platform SDKs and a real signing key;
  only the debug Android build is verified on this Linux host.

## Limits

This does not protect against a compromised OS/keychain, a malicious or
mis-issued TLS certificate, a malicious NAS that returns oversized or deceptive
content, screenshot/clipboard malware, or a stolen unlocked device. Certificate
pinning and remote attestation are not implemented.