import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'screens/help_screen.dart';
import 'screens/local_gallery_screen.dart';
import 'screens/remote_gallery_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tutorial_screen.dart';
import 'services/webdav_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPhotoPermissions();
  runApp(NasPhotoManagerApp(webdavService: WebdavService()));
}

Future<void> _requestPhotoPermissions() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;

  try {
    final photos = await Permission.photos.request();
    if (!photos.isGranted && !photos.isLimited) {
      // Android 12 and earlier expose the gallery through READ_EXTERNAL_STORAGE.
      // On Android 13+ and iOS this request is a harmless no-op when the photo
      // permission above already covers access.
      await Permission.storage.request();
    }
  } catch (_) {
    // The local gallery requests the same permission through photo_manager and
    // presents a dedicated explanation if access is denied.
  }
}

class NasPhotoManagerApp extends StatefulWidget {
  const NasPhotoManagerApp({super.key, required this.webdavService});

  final WebdavService webdavService;

  @override
  State<NasPhotoManagerApp> createState() => _NasPhotoManagerAppState();
}

class _NasPhotoManagerAppState extends State<NasPhotoManagerApp> {
  final ThemeController _themeController = ThemeController();

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeController,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'NAS Photo Manager',
        debugShowCheckedModeBanner: false,
        theme: OneDriveTheme.light,
        darkTheme: OneDriveTheme.dark,
        themeMode: themeMode,
        home: HomeShell(
          webdavService: widget.webdavService,
          themeController: _themeController,
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.webdavService,
    required this.themeController,
  });

  final WebdavService webdavService;
  final ThemeController themeController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final GlobalKey<RemoteGalleryScreenState> _remoteKey =
      GlobalKey<RemoteGalleryScreenState>();

  late final List<Widget> _screens = <Widget>[
    RemoteGalleryScreen(
      key: _remoteKey,
      webdavService: widget.webdavService,
      themeController: widget.themeController,
      onOpenSettings: () => _select(4),
      onOpenLocalPhotos: () => _select(1),
    ),
    LocalGalleryScreen(
      webdavService: widget.webdavService,
      themeController: widget.themeController,
      onOpenSettings: () => _select(4),
    ),
    TutorialScreen(
      themeController: widget.themeController,
      onOpenSettings: () => _select(4),
      onOpenHelp: () => _select(3),
    ),
    HelpScreen(
      webdavService: widget.webdavService,
      themeController: widget.themeController,
      onOpenSettings: () => _select(4),
    ),
    SettingsScreen(
      webdavService: widget.webdavService,
      onSaved: () => _remoteKey.currentState?.reload(),
    ),
  ];

  int _currentIndex = 0;

  void _select(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) {
      _remoteKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _select,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'NAS Photos',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'Local Photos',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Tutorial',
          ),
          NavigationDestination(
            icon: Icon(Icons.help_outline),
            selectedIcon: Icon(Icons.help),
            label: 'Help',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
