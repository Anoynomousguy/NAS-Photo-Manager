# Modular development — NAS Photo Manager

The mobile app is a manifest-driven Flutter shell. `AppShell` owns the app
frame, role filtering, route guard, lazy module mounting, the polished bottom
navigation and module reveal skeletons. Features live under `lib/modules/` and
are registered in one manifest file.

```
lib/
  core/                  shell, auth, RBAC, config, network state, skeletons
  modules/
    manifest.dart        source of truth for navigation and access
    files/
    photos/
    ai/
    admin/
    help/
  screens/               shared implementation screens behind wrappers
  services/              WebDAV and storage services
  widgets/               shared visual components
```

## Add a new module (example: Shopping)

### 1. Create the folder and widget

Create:

```
lib/modules/shopping/shopping_module.dart
```

A module receives a `ModuleContext`. It must not import another module.

```dart
import 'package:flutter/material.dart';

import '../../core/module.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class ShoppingModule extends StatelessWidget {
  const ShoppingModule({
    super.key,
    required this.themeController,
    required this.onOpenSettings,
    required this.moduleContext,
  });

  final ThemeController themeController;
  final VoidCallback onOpenSettings;
  final ModuleContext moduleContext;

  @override
  Widget build(BuildContext context) {
    final OneDriveTokens tokens = OneDriveTokens.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping'),
        leading: AvatarButton(onPressed: onOpenSettings),
        actions: <Widget>[
          ThemeToggleButton(controller: themeController),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Shared list',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This module automatically inherits the shell theme, '
                    'navigation and access checks.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### 2. Register it in the manifest

Open `lib/modules/manifest.dart`, import the file, and append one
`ModuleDefinition`:

```dart
import 'shopping/shopping_module.dart';

// ...inside appModules...
ModuleDefinition(
  id: 'shopping',
  title: 'Shopping',
  path: '/shopping',
  icon: Icons.shopping_bag_outlined,
  selectedIcon: Icons.shopping_bag,
  requiredRole: UserRole.user,
  searchable: false,
  builder: (_, ModuleContext module) => ShoppingModule(
    themeController: module.themeController,
    onOpenSettings: module.openSettings,
    moduleContext: module,
  ),
),
```

That is all. `AppShell` reads `appModules`, filters by role, builds the bottom
navigation, mounts the module lazily, and uses the same guard for any
`openModule('/shopping')` call.

## Manifest fields

| Field | Purpose |
| --- | --- |
| `id` | Stable unique key and test identifier. |
| `title` | Page title and accessible name. |
| `navLabel` | Optional short label for the bottom bar. |
| `path` | In-app path used by `ModuleContext.openModule`. |
| `icon` | Unselected Material icon. |
| `selectedIcon` | Filled icon shown when the tab is active. |
| `requiredRole` | `UserRole.user` or `UserRole.admin`. |
| `showInNav` | Set `false` for a module reachable only through another module. |
| `searchable` | Declares that the module supports shell search. |
| `builder` | Creates the module widget from the shared `ModuleContext`. |

Do not edit `AppShell` just to add a normal navigation module.

## Roles and route protection

Roles are hierarchical:

| Role | Can open |
| --- | --- |
| `user` | every `requiredRole: UserRole.user` module |
| `admin` | all member modules plus admin-only modules |

`AuthScope` is the single role source. `AppShell` removes forbidden modules
from the bottom bar, and `RouteGuard` repeats the check before `openModule`
changes tabs. `AdminModule` also checks the role before rendering its body.

Local role previews are compile-time defines:

```bash
flutter run --dart-define=APP_ROLE=admin --dart-define=APP_USER=Admin
flutter run --dart-define=APP_ROLE=user --dart-define=APP_USER=Member
```

The default is `user`. The shell deliberately does not promote a cached role
when offline.

## Module context and dependency rules

`ModuleContext` is the only shell surface a module needs:

- `webdavService`
- `themeController`
- `auth`
- `openModule(path)`
- `openSettings()`
- `openTutorial()`

Rules:

1. Never import from another module folder.
2. Never construct your own `NavigationBar`; use the shell.
3. Never read the role from a local flag. Use `AuthScope.of(context)` or
   `module.auth`.
4. Keep asynchronous work cancellable and set `_loading`/`_error` states.
5. Wrap remote or plugin-backed surfaces in a calm offline/error state rather
   than letting an exception escape.
6. Keep destructive actions out of mobile admin surfaces unless the core
   security model explicitly changes.

Reusable pieces:

- `lib/core/loading_skeleton.dart` — pulsing blocks and module skeleton.
- `lib/widgets/backend_unavailable.dart` — polished offline/coming-soon card.
- `lib/widgets/common.dart` — avatar, theme toggle, empty state, rows.
- `lib/theme.dart` — Material 3 color, type, navigation and motion tokens.

## Environment variables

The app uses compile-time `--dart-define` values, with tailnet placeholders in
`lib/core/app_config.dart`:

| Define | Default | Purpose |
| --- | --- | --- |
| `APP_ROLE` | `user` | Mock session role while no real provider is wired. |
| `APP_USER` | `Member` | Display name for the mock session. |
| `PHOTOS_URL` | `https://your-nas.your-tailnet.ts.net:8082/` | Reserved NAS Photos backend (API scaffold). |
| `AI_URL` | `https://your-nas.your-tailnet.ts.net:3000/` | Open WebUI / assistant backend. |

A ready-to-copy set is in `dart_defines.example.json`:

```bash
flutter run --dart-define-from-file=dart_defines.example.json
```

The values are endpoints, not secrets. Keep the services on the private
tailnet; do not expose them publicly just to make the demo work.

## Themes, transitions and offline states

`OneDriveTheme.light` and `.dark` are Material 3 themes with the shared
OneDrive/fortress palette. The shell uses `NavigationBar` with filled selected
icons, a top hairline and a soft shadow. Module switches cross-fade and lift,
and a `ModuleSkeleton` covers the first reveal for
`AppConfig.moduleRevealDuration`. Pushed pages use
`OneDrivePageTransitionsBuilder`.

Network state comes from `NetworkStatusController`. The `OfflineBanner` is
global; the Photos gallery shows a local-only notice, and AI shows the full
`BackendUnavailable` surface immediately when the network probe is down.

## Build, test and verify

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The widget tests mount the real manifest and assert:

- a member sees Files, Photos, AI and Help but no Admin;
- an admin sees Administration;
- `RouteGuard` denies the admin module to a member;
- navigation to Help updates the selected destination.

Run with an attached device:

```bash
flutter devices
flutter run -d <device-id> \
  --dart-define-from-file=dart_defines.example.json
```

Install the debug APK directly:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```
