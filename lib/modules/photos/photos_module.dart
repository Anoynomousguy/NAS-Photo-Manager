import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../screens/local_gallery_screen.dart';
import '../../services/webdav_service.dart';
import '../../theme.dart';
import '../../widgets/backend_unavailable.dart';
import '../../widgets/common.dart';

class PhotosModule extends StatefulWidget {
  const PhotosModule({
    super.key,
    required this.webdavService,
    required this.themeController,
    required this.onOpenSettings,
    required this.onOpenHelp,
  });

  final WebdavService webdavService;
  final ThemeController themeController;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHelp;

  @override
  State<PhotosModule> createState() => _PhotosModuleState();
}

class _PhotosModuleState extends State<PhotosModule> {
  bool _showLocalGallery = false;

  @override
  Widget build(BuildContext context) {
    if (_showLocalGallery) {
      return LocalGalleryScreen(
        webdavService: widget.webdavService,
        themeController: widget.themeController,
        onOpenSettings: widget.onOpenSettings,
        onBack: () => setState(() => _showLocalGallery = false),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photos'),
        leading: AvatarButton(onPressed: widget.onOpenSettings),
        actions: <Widget>[
          ThemeToggleButton(controller: widget.themeController),
        ],
      ),
      body: BackendUnavailable(
        icon: Icons.photo_library_outlined,
        eyebrow: 'NAS gallery',
        statusLabel: 'Coming soon',
        title: 'Photos is ready for its next home',
        message:
            'The NAS photo service is not connected yet. The shell, Files '
            'and local photos are ready now; the remote gallery will appear '
            'here once its backend URL is live.',
        endpoint: AppConfig.photosUrl,
        primaryLabel: 'Browse this device',
        primaryIcon: Icons.phone_android,
        onPrimary: () => setState(() => _showLocalGallery = true),
        secondaryLabel: 'Open Help',
        onSecondary: widget.onOpenHelp,
      ),
    );
  }
}
