import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'screens/local_gallery_screen.dart';
import 'screens/remote_gallery_screen.dart';
import 'screens/settings_screen.dart';
import 'services/webdav_service.dart';

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

class NasPhotoManagerApp extends StatelessWidget {
  const NasPhotoManagerApp({super.key, required this.webdavService});

  final WebdavService webdavService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NAS Photo Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: HomeShell(webdavService: webdavService),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.webdavService});

  final WebdavService webdavService;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final GlobalKey<RemoteGalleryScreenState> _remoteKey =
      GlobalKey<RemoteGalleryScreenState>();
  late final List<Widget> _screens;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _screens = <Widget>[
      RemoteGalleryScreen(key: _remoteKey, webdavService: widget.webdavService),
      LocalGalleryScreen(webdavService: widget.webdavService),
      SettingsScreen(
        webdavService: widget.webdavService,
        onSaved: () => _remoteKey.currentState?.reload(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 0) {
            _remoteKey.currentState?.reload();
          }
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_outlined),
            activeIcon: Icon(Icons.cloud),
            label: 'NAS Photos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library_outlined),
            activeIcon: Icon(Icons.photo_library),
            label: 'Local Photos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
