import 'package:flutter/material.dart';

import '../core/auth_context.dart';
import '../core/module.dart';
import 'admin/admin_module.dart';
import 'ai/ai_module.dart';
import 'files/files_module.dart';
import 'help/help_module.dart';
import 'photos/photos_module.dart';

/// The mobile equivalent of src/modules/manifest.json. New features are added
/// by creating a module folder and appending one entry here; the shell itself
/// does not need to change.
final List<ModuleDefinition> appModules = <ModuleDefinition>[
  ModuleDefinition(
    id: 'files',
    title: 'Files',
    path: '/files',
    icon: Icons.cloud_outlined,
    selectedIcon: Icons.cloud,
    requiredRole: UserRole.user,
    searchable: true,
    builder: (_, ModuleContext module) => FilesModule(
      webdavService: module.webdavService,
      themeController: module.themeController,
      onOpenSettings: module.openSettings,
      onOpenPhotos: () => module.openModule('/photos'),
    ),
  ),
  ModuleDefinition(
    id: 'photos',
    title: 'Photos',
    path: '/photos',
    icon: Icons.photo_library_outlined,
    selectedIcon: Icons.photo_library,
    requiredRole: UserRole.user,
    builder: (_, ModuleContext module) => PhotosModule(
      webdavService: module.webdavService,
      themeController: module.themeController,
      onOpenSettings: module.openSettings,
      onOpenHelp: () => module.openModule('/help'),
    ),
  ),
  ModuleDefinition(
    id: 'ai',
    title: 'AI Assistant',
    navLabel: 'AI',
    path: '/ai',
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome,
    requiredRole: UserRole.user,
    builder: (_, ModuleContext module) => AiModule(
      themeController: module.themeController,
      onOpenSettings: module.openSettings,
      onOpenHelp: () => module.openModule('/help'),
    ),
  ),
  ModuleDefinition(
    id: 'admin',
    title: 'Administration',
    navLabel: 'Admin',
    path: '/admin',
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings,
    requiredRole: UserRole.admin,
    builder: (_, ModuleContext module) => AdminModule(
      themeController: module.themeController,
      onOpenSettings: module.openSettings,
    ),
  ),
  ModuleDefinition(
    id: 'help',
    title: 'Help',
    path: '/help',
    icon: Icons.help_outline,
    selectedIcon: Icons.help,
    requiredRole: UserRole.user,
    builder: (_, ModuleContext module) => HelpModule(
      webdavService: module.webdavService,
      themeController: module.themeController,
      moduleContext: module,
    ),
  ),
];
