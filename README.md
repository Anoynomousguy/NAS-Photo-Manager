# NAS Photo Manager

A Flutter mobile app for working with photos stored on a private NAS over
WebDAV. It can browse the NAS gallery, download and view photos at full size,
and upload photos from the device.

## Target NAS

- WebDAV endpoint: `https://your-nas.your-tailnet.ts.net:8443`
- Authentication: HTTP Basic Auth
- Username: `admin`
- Password: **entered in the app's Settings screen and stored in the platform
  secure store** (Android Keystore / iOS Keychain). No password or token is
  compiled into this repository.

The endpoint is served by Dufs through Tailscale Serve. The device must be
signed in to the same tailnet to reach the NAS (or use an equivalent SSH
tunnel while developing).

## Features

- **NAS Photos** — grid of image files from the NAS root, authenticated
  thumbnails, pull-to-refresh, and a full-screen `photo_view` viewer after
  downloading the original to a temporary file.
- **Local Photos** — `photo_manager` gallery with multi-select and an
  **Upload Selected** action that writes to `/uploads` on the NAS.
  `file_picker` also allows uploading arbitrary image files from the device.
- **Settings** — WebDAV URL, username, and password fields. Saving persists
  the values in `flutter_secure_storage` and performs a real connection check
  before reporting success.
- Permissions are requested at startup and again by the gallery when needed.
- Upload progress is shown per selected photo; the default NAS endpoint is
  prefilled.

## Project layout

```text
lib/
  main.dart                       App shell + permission startup + bottom navigation
  services/
    webdav_service.dart           Secure credentials, connect, list, upload, download
  screens/
    remote_gallery_screen.dart    NAS grid + full-screen photo viewer
    local_gallery_screen.dart     Local photo multi-select + upload
    settings_screen.dart          Credential entry + connection test
android/                          Android permissions and platform project
ios/                              Info.plist usage descriptions and ATS config
.github/workflows/build.yml       macOS iOS build without code signing
```

## Run locally

```sh
flutter --version       # tested with Flutter 3.47.9 / Dart 3.13.7
flutter pub get
flutter run
```

On first launch, open **Settings**, confirm the URL, enter the NAS username and
password, and tap **Save**. The app verifies the connection before confirming
the save.

### Android

The manifest requests:

- `android.permission.INTERNET`
- `android.permission.READ_EXTERNAL_STORAGE`
- `android.permission.READ_MEDIA_IMAGES`
- `android.permission.READ_MEDIA_VISUAL_USER_SELECTED` for Android 14 limited
  photo access

Android 13+ uses the granular media permission; Android 12 and earlier use
the legacy storage permission.

### iOS

`ios/Runner/Info.plist` includes:

- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`
- `NSLocalNetworkUsageDescription`
- `NSAppTransportSecurity` with arbitrary loads and local networking enabled
  for local-network WebDAV endpoints

The iOS project uses Swift Package Manager. `permission_handler_apple` detects
`NSPhotoLibraryUsageDescription` in `Info.plist` and compiles photo permission
support automatically; no Podfile macro is required.

## Build

```sh
flutter build apk --debug       # Android debug APK
flutter build ios --no-codesign # macOS host required; also runs in CI
```

The Android build currently uses `compileSdk = 37` because
`permission_handler_android` 14.1.1 requires it. Install Android SDK Platform
37 (the `platforms;android-37.0` package) and Build-Tools 37 when building
locally. The checked-in debug APK is not committed; it is a build artifact.

## iOS CI

`.github/workflows/build.yml` runs on every push to `main` and on manual
dispatch:

1. Checkout code
2. Set up Flutter (stable channel)
3. `flutter pub get`
4. `flutter build ios --no-codesign`

The build intentionally skips Apple code signing, so it can run on
`macos-latest` without developer certificates. Store distribution signing is a
separate step once the app is ready to ship.

## Security notes

- Credentials live only in the platform secure store and in memory for the
  duration of a request.
- The Basic-auth header used for thumbnail loading is derived at runtime; it is
  never written to the repo.
- `.gitignore` excludes `.env`, private keys, build output, and iOS/Android
  local dependency artifacts.
- The app targets the tailnet endpoint and does not require public inbound
  ports.