import 'package:flutter/material.dart';

import '../../screens/remote_gallery_screen.dart';
import '../../services/webdav_service.dart';
import '../../theme.dart';

class FilesModule extends StatelessWidget {
  const FilesModule({
    super.key,
    required this.webdavService,
    required this.themeController,
    required this.onOpenSettings,
    required this.onOpenPhotos,
  });

  final WebdavService webdavService;
  final ThemeController themeController;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenPhotos;

  @override
  Widget build(BuildContext context) {
    return RemoteGalleryScreen(
      webdavService: webdavService,
      themeController: themeController,
      onOpenSettings: onOpenSettings,
      onOpenLocalPhotos: onOpenPhotos,
    );
  }
}
