import 'package:flutter/material.dart';

import '../services/webdav_service.dart';
import '../theme.dart';
import 'auth_context.dart';

typedef ModuleBuilder =
    Widget Function(BuildContext context, ModuleContext moduleContext);

@immutable
class ModuleDefinition {
  const ModuleDefinition({
    required this.id,
    required this.title,
    required this.path,
    required this.icon,
    required this.requiredRole,
    required this.builder,
    this.selectedIcon,
    this.navLabel,
    this.showInNav = true,
    this.searchable = false,
  });

  final String id;
  final String title;
  final String path;
  final IconData icon;
  final IconData? selectedIcon;
  final UserRole requiredRole;
  final ModuleBuilder builder;
  final String? navLabel;
  final bool showInNav;
  final bool searchable;

  String get label => navLabel ?? title;
}

/// The only dependency surface modules receive from the shell. Modules never
/// import each other; navigation and settings are callbacks owned by the core.
@immutable
class ModuleContext {
  const ModuleContext({
    required this.webdavService,
    required this.themeController,
    required this.auth,
    required this.openModule,
    required this.openSettings,
    required this.openTutorial,
  });

  final WebdavService webdavService;
  final ThemeController themeController;
  final AuthContext auth;
  final ValueChanged<String> openModule;
  final VoidCallback openSettings;
  final VoidCallback openTutorial;
}
