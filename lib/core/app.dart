import 'package:flutter/material.dart';

import '../services/webdav_service.dart';
import '../theme.dart';
import 'auth_context.dart';
import 'network_status.dart';
import 'offline_banner.dart';
import 'shell.dart';

class NasPhotoManagerApp extends StatefulWidget {
  const NasPhotoManagerApp({
    super.key,
    required this.webdavService,
    this.auth,
    this.networkStatus,
  });

  final WebdavService webdavService;
  final AuthContext? auth;
  final NetworkStatusController? networkStatus;

  @override
  State<NasPhotoManagerApp> createState() => _NasPhotoManagerAppState();
}

class _NasPhotoManagerAppState extends State<NasPhotoManagerApp> {
  final ThemeController _themeController = ThemeController();
  late final AuthContext _auth;
  late final NetworkStatusController _network;
  late final bool _ownsNetwork;

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? AuthContext.fromEnvironment();
    _ownsNetwork = widget.networkStatus == null;
    _network = widget.networkStatus ?? NetworkStatusController();
    _network.start();
  }

  @override
  void dispose() {
    // The app starts the probe, so it must always stop it. An injected
    // controller stays reusable by its owner after the widget is disposed.
    _network.stop();
    if (_ownsNetwork) {
      _network.dispose();
    }
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      auth: _auth,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: _themeController,
        builder: (BuildContext context, ThemeMode themeMode, _) {
          return MaterialApp(
            title: 'NAS Photo Manager',
            debugShowCheckedModeBanner: false,
            theme: OneDriveTheme.light,
            darkTheme: OneDriveTheme.dark,
            themeMode: themeMode,
            builder: (BuildContext context, Widget? child) {
              return NetworkStatusScope(
                controller: _network,
                child: Column(
                  children: <Widget>[
                    const OfflineBanner(),
                    Expanded(child: child ?? const SizedBox.shrink()),
                  ],
                ),
              );
            },
            home: AppShell(
              webdavService: widget.webdavService,
              themeController: _themeController,
            ),
          );
        },
      ),
    );
  }
}
