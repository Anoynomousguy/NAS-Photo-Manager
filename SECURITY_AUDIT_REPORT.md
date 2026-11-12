# Fortress Photo Manager — Security Audit & APK Report

**Date:** 2026-11-09  
**Target:** Tualatin T410, `t410`  
**Build:** Flutter debug APK  
**Private routes:** local `10.0.0.10`, Tailscale `100.64.0.10`  
**Canonical HTTPS host:** `your-nas.your-tailnet.ts.net`

## Executive summary

The Flutter client builds cleanly against the live HTTPS endpoints. The AI module remains a restricted WebView pointed at the working Open WebUI instance; the Photos backend is an API-only Phase 2 scaffold and is intentionally not used as a web gallery. The APK contains no hardcoded credentials and keeps the NAS password in platform secure storage.

This report records the verified build, the code-level security controls, and the host-level findings that still require root. It does not claim a physical-device install or a full interactive login test.

## Build and test result

| Check | Result |
|---|---|
| `flutter analyze` | **No issues found** (99.6 s) |
| `flutter test` | **16/16 passing** |
| `flutter build apk --debug` | pass |
| APK path | `build/app/outputs/flutter-apk/app-debug.apk` |
| APK size | 198 MB |
| APK SHA-256 | `76ccc9535c79057a9d05a1ec0b356f4b7233ca901659abbfc539d7153ae5d801` |
| AI endpoint | `https://your-nas.your-tailnet.ts.net:3000/` |
| AI health | `200`, `{"status":true}` |
| Photos endpoint | `https://your-nas.your-tailnet.ts.net:8082/` retained for future integration; not mounted |

The APK is a debug artifact. It is not release-signed and was not installed on a physical Android/iOS device in this audit.

## Endpoint configuration

`lib/core/app_config.dart` uses the certificate-valid MagicDNS origin:

- `tailnetHost = https://your-nas.your-tailnet.ts.net`
- `aiUrl = https://your-nas.your-tailnet.ts.net:3000/`
- `photosUrl = https://your-nas.your-tailnet.ts.net:8082/` (reserved for the future authenticated gallery/API integration)
- `webViewTimeout = 18 seconds`

The raw `http://100.64.0.10:...` URLs from the deployment brief were deliberately not baked into the client:

- the client enforces HTTPS, and cleartext traffic was not enabled;
- the Tailscale certificate is issued for the MagicDNS hostname, not the raw IP;
- a direct-IP HTTPS certificate would fail validation and an HTTP AI WebView would be blocked/unsafe.

This is a security trade-off, not an oversight. If raw-IP HTTP is an absolute requirement, it must be treated as a separate transport redesign with a certificate strategy; it was not silently enabled.

## Mobile security review

### AI WebView

- URL must parse as `https` with a nonempty host before a request is made.
- Main-frame and HTTP error handlers surface a retry UI instead of showing a blank page.
- An 18-second timeout cancels indefinitely loading modules.
- Navigation is restricted to the configured origin, scheme, host, and effective port.
- `about:blank` is the only special allowed navigation.
- Navigation outside the configured AI service is prevented and reported to the user.
- The app does not enable Android cleartext traffic or weaken the iOS ATS policy.
- The WebView is a remote module; it does not receive local NAS credentials.

### Error handling and white-screen protection

- `installErrorHandlers()` is called before `runApp()`.
- `ErrorWidget.builder` provides a readable fallback for widget-build failures.
- `FlutterError.onError` reports unhandled Flutter errors.
- `runZonedGuarded` catches asynchronous errors that escape the widget tree.
- The AI module has explicit loading, offline, HTTP-error, WebView-error, and timeout states.
- Other modules use backend-unavailable/fallback states rather than assuming a live backend.

A clean build and tests reduce risk, but no automated test can prove every native runtime path is white-screen-free. A physical-device matrix remains recommended.

### RBAC and navigation

- The manifest-driven shell filters modules by `UserRole`.
- The 16-test suite includes:
  - a member sees four destinations and **not** Admin;
  - a member cannot access the admin module (`RouteGuard.canAccess == false`);
  - an admin sees Administration and can open Help.
- Admin authorization is not inferred from a client-provided e-mail or display name; role comes from the server identity/group contract.

### Secrets and credential storage

- No hardcoded API key, bearer token, password, or private key was found in `lib/`.
- The NAS password is entered at runtime and stored through the platform secure-storage abstraction (`flutter_secure_storage`), then used only in memory for Basic auth.
- The app’s documentation comments contain the tailnet IP as a non-secret deployment note.
- The host-side `.env` remains `600 root:root` and was not read into the client.

## Photos backend limitation

The T410 Photos service is **not** the gallery UI:

- `/health` → `200` with service/SQLite/sharp metadata;
- `/api/photos/stats` → `{"assets":0,"faces":0,"people":0,"jobs":0}`;
- `/` → `404`;
- `/api/photos/scan` → `501`;
- README: “loopback-only scaffold and has no authentication. Do not publish it beyond 127.0.0.1”;
- Tailscale Serve has no `:8082` mapping.

Therefore:

- the web portal was changed to the existing native “Photos is not connected yet” fallback;
- no 8082 route was published;
- no unauthenticated Photos API is embedded in the Flutter app;
- the mobile app’s existing local/WebDAV gallery remains separate from this API scaffold.

A real Photos integration requires Phase 3 work: authenticated tenant-scoped API, background indexing, thumbnail authorization, and a reviewed UI/route. Publishing the current scaffold would be a security regression.

## Host and container findings relevant to the APK

The mobile client depends on the same host controls as the portal:

| ID | Severity | Finding | Status / mitigation |
|---|---|---|---|
| R-01 | High | **CrowdSec is crash-looping.** Last check: `activating (auto-restart)`, `Result=exit-code`, 24 restarts. | Unresolved; root journal/config access required. Treat remote abuse monitoring as unavailable until repaired. |
| R-02 | High | **Ollama binds `*:11434`.** No explicit loopback `OLLAMA_HOST` in the unit. | Unresolved; root systemd change required. |
| R-03 | High | **Photos is unauthenticated and API-only.** No 8082 route; no indexer. | Not exposed. Do not publish until authenticated/scoped. |
| R-04 | Medium | **Portal/Dufs/Open WebUI containers run as root** with `no-new-privileges`; data directories are root-owned. | Residual; changing UID requires data ownership migration. |
| R-05 | Medium | **Open WebUI is directly reachable on Tailscale `:3000`** with its own auth and a CORS `*` warning. | Tailnet-only; keep application auth and consider Authelia/CORS restriction. |
| R-06 | Medium | **UFW effective rules were not inspectable without root.** Service is active; nftables/firewalld inactive. | Root review required. |
| R-07 | Medium | **Caddy trust is pinned to `172.18.0.9/32`.** A recreated Caddy with a new Docker IP breaks portal auth with 403. | Operational note; pin proxy IP or update `TRUSTED_PROXY_CIDRS`. |
| R-08 | Low | **Unknown/stale Tailscale `:2342` mapping** returns 502; not part of this app. | Investigate/remove. |

## Verified controls and builds

- Web portal is running with the new server and `dist`; CSP, Permissions-Policy, HSTS, and X-Frame-Options are present.
- Caddy→portal auth: no identity `401`, member `200` `/api/me`, member `403` `/api/admin/users`, admin `200`.
- Server test suite: 57/57 passing.
- Server and web `npm audit --omit=dev`: 0 vulnerabilities.
- Web build: 2,091 modules, new asset `index-DRYcYKbV.js`.
- Flutter analyze/test/build: clean/pass/pass.
- Open WebUI live memory reduced from 96.98% of 768 MiB to 58.19% of 1.25 GiB after a controlled limit increase.

## Limitations

- No physical-device install, no camera/photo-permission runtime test, and no full Authelia login session.
- No full Android/iOS release build or store-signing validation.
- No root-level CrowdSec/Ollama/UFW remediation.
- The local workspace is not the Git worktree; no commit was created.
- A visual review of every screen was not performed; tests and code inspection are the evidence base.

## Recommended follow-up

1. Repair CrowdSec and verify it is banning, not restarting.
2. Bind Ollama to `127.0.0.1` with a systemd drop-in.
3. Root-review UFW and remove the stale `:2342` Tailscale Serve entry.
4. Keep Photos loopback-only until authentication, tenant scoping, indexing, and a real UI exist.
5. Run the APK on at least one Android 13+ and one older Android device against the live tailnet, including AI timeout/retry and the local gallery permission flow.

---

# Addendum — Post-recovery audit (2026-11-12)

This section was appended after a fresh audit run on the recovered source and a live probe of
the deployed host. It records only new, evidenced findings.

## Audit evidence

| Check | Command | Result |
| --- | --- | --- |
| Server test suite | `npm test` | **57/57 pass, 0 fail** |
| Server dependency audit | `npm audit --omit=dev` | **0 vulnerabilities** |
| Web dependency audit | `npm audit --omit=dev` | **0 vulnerabilities** |
| Portal production build | `npm run build` | **PASS** — 2091 modules |
| Flutter static analysis | `flutter analyze` | **PASS** — no issues found |

## Findings closed in this pass

### A-01 — Real tailnet address embedded in source (LOW) — FIXED

`lib/core/app_config.dart` carried the T410's tailnet IPv4 address in a doc comment. Comments
ship in the repository and disclose internal topology even when the value is not executable.

Fixed by rewriting the comment to explain the *reason* (certificate is hostname-scoped) without
the address.

### A-02 — Sandbox comment overstated the security boundary (LOW) — FIXED

`web/src/core/SandboxedReactFrame.tsx` claimed the frame sandbox "blocks top navigation,
popups and unsolicited downloads". Because the frame uses `allow-scripts` **and**
`allow-same-origin` on a same-origin `srcDoc` document, the framed code shares the portal
origin and can reach `window.parent`. The sandbox blocks popups, downloads and top-level
navigation *initiated by the frame*, but it is not a boundary against malicious module code.

Fixed by replacing the comment with an explicit boundary statement and a rule: any module that
renders untrusted markup or third-party script must move to `sandbox-remote` (cross-origin)
rather than extending this frame. No behavioural change; the frame attributes were already
correct and `allow-top-navigation` / `allow-popups` were never present.

## Verified controls

- `sandbox` on both frames contains **no** `allow-top-navigation` and **no** `allow-popups`.
- Both frames set `allow="camera 'none'; microphone 'none'; geolocation 'none'; clipboard-read 'none'; clipboard-write 'none'"`.
- Server RBAC is independent of the client: `requireAdmin` rejects any non-admin `req.user`
  on `/api/admin/*`, and `Remote-User` headers are trusted only when the socket peer matches
  the configured proxy CIDR.
- Path scoping canonicalizes with `realpath` and rejects any root outside `DATA_DIR`, defeating
  traversal and symlink escape.
- Production refuses to start without `TRUST_PROXY_AUTH=true`, so the development identity
  cannot leak into a deployed instance.
- No white-screen path: `ErrorBoundary` wraps every module, `RemoteSandboxFrame` has explicit
  timeout/offline states, and `StatusBanner` reports backend loss. A module crash renders a
  contained retry card, not a blank page.
- Client route guards cannot be bypassed: a direct `#/admin` hash renders `AccessDenied`
  because `RouteGuard` wraps `ModuleView`; the Flutter shell builds its module stack only from
  the role-filtered list and re-checks `RouteGuard.canAccess` in `_selectModule`.

## Findings open — require root on the T410

Recorded here because they were confirmed by live probe but cannot be remediated without host
access. Full detail in `state/LIVE_STATE.md`.

| ID | Severity | Finding |
| --- | --- | --- |
| F-01 | HIGH | Ollama `:11434` reachable over the tailnet with no authentication; `/api/tags` returns the model inventory |
| F-02 | MEDIUM | Syncthing BEP `:2342` published via a stale `tailscale serve` mapping |
| F-03 | MEDIUM | Authelia `:9091` reachable directly, bypassing Caddy as the single front door |
| F-04 | LOW | Unidentified listener on `:8443` accepts TCP, speaks no TLS |
