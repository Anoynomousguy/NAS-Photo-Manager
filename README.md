# NAS Photo Manager

Flutter WebDAV photo client for the Fortress NAS.

![Status: maintained](https://img.shields.io/badge/status-maintained-brightgreen)
![Flutter](https://img.shields.io/badge/Flutter-3.47.9-blue)

A Flutter app for browsing, uploading, and downloading photos stored on a private
NAS over WebDAV. The gallery loads authenticated thumbnails, downloads full-size
originals on demand, and uploads from the device gallery. Credentials live in the
platform secure store and are never compiled into the build.

## Status

Maintained. The client targets the Fortress NAS. The earlier single-node stack in
[RMC-Secure-NAS-Node](https://github.com/Anoynomousguy/RMC-Secure-NAS-Node) is
kept for reference only and is no longer the deployment target.

## Features

- **NAS photos** — grid of image files from the NAS root, authenticated
  thumbnails, pull-to-refresh, and a full-screen `photo_view` viewer after
  downloading the original to a temporary file.
- **Local photos** — `photo_manager` gallery with multi-select and an
  **Upload Selected** action that writes to `/uploads` on the NAS. `file_picker`
  also allows uploading arbitrary image files from the device.
- **Settings** — WebDAV URL, username, and password fields. Saving persists the
  values in `flutter_secure_storage` and performs a real connection check before
  reporting success.
- Permissions are requested at startup and again by the gallery when needed.
- Upload progress is shown per selected photo; the default NAS endpoint is
  prefilled.

## Target NAS

- WebDAV endpoint: `https://your-nas.your-tailnet.ts.net:8443`
- Authentication: HTTP Basic Auth
- Username: `admin`
- Password: entered in the app's Settings screen and stored in the platform
  secure store (Android Keystore / iOS Keychain). No password or token is
  compiled into this repository.

The endpoint is published over the private tailnet by the Fortress NAS. The
device must be signed in to the same tailnet to reach it, or use an equivalent
SSH tunnel while developing.

## Quick start

```sh
flutter --version       # tested with Flutter 3.47.9 / Dart 3.13.7
flutter pub get
flutter analyze
flutter build apk --debug
```

On first launch, open **Settings**, confirm the URL, enter the NAS username and
password, and tap **Save**. The app verifies the connection before confirming the
save.

The Android build uses `compileSdk = 37` because `permission_handler_android`
14.1.1 requires it. Install Android SDK Platform 37 (the `platforms;android-37.0`
package) and Build-Tools 37 when building locally.

`flutter build ios --no-codesign` requires a macOS host; CI runs it on
`macos-latest` without signing certificates. Store distribution signing is a
separate step once the app is ready to ship.

## Repository map

```text
lib/
  main.dart                       App shell, permission startup, bottom navigation
  core/                           Config, auth context, route guards, offline banner
  services/webdav_service.dart    Credentials, connect, list, upload, download
  screens/                        Remote gallery, local gallery, settings, help
  modules/                        Role-filtered feature modules (photos, files, AI, admin)
  widgets/                        Shared backend-unavailable and common widgets
android/                          Android permissions and platform project
ios/                              Info.plist usage descriptions and ATS config
test/widget_test.dart             URL normalisation and service tests
.github/workflows/build.yml       macOS iOS build without code signing
SECURITY.md                       Security boundaries and platform hardening
```

## Security

The implemented boundaries — HTTPS-only transport, secure-store credentials,
path normalisation, download size limits and platform hardening — are documented
in [SECURITY.md](SECURITY.md). Report problems privately; do not open a public
issue containing hostnames, addresses or credentials.

## Related repositories

- [NAS-CONFIDENTIAL](https://github.com/Anoynomousguy/NAS-CONFIDENTIAL) — private
  operational archive for the Fortress NAS (not publicly viewable).
- [RMC-Secure-NAS-Node](https://github.com/Anoynomousguy/RMC-Secure-NAS-Node) —
  earlier single-node stack, kept for reference.

## Documentation

- [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) — connecting the client to any WebDAV server.
