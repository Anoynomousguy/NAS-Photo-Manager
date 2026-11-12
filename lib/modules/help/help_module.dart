import 'package:flutter/material.dart';

import '../../screens/help_screen.dart';
import '../../services/webdav_service.dart';
import '../../theme.dart';
import '../../core/module.dart';

class HelpModule extends StatelessWidget {
  const HelpModule({
    super.key,
    required this.webdavService,
    required this.themeController,
    required this.moduleContext,
  });

  final WebdavService webdavService;
  final ThemeController themeController;
  final ModuleContext moduleContext;

  @override
  Widget build(BuildContext context) {
    return HelpScreen(
      webdavService: webdavService,
      themeController: themeController,
      role: moduleContext.auth.role,
      onOpenSettings: moduleContext.openSettings,
      onOpenTutorial: moduleContext.openTutorial,
    );
  }
}
