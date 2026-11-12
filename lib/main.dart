import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/app.dart';
import 'core/error_handling.dart';
import 'services/webdav_service.dart';

export 'core/app.dart' show NasPhotoManagerApp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorHandlers();

  runZonedGuarded(() async {
    await _requestPhotoPermissions();
    runApp(NasPhotoManagerApp(webdavService: WebdavService()));
  }, (Object error, StackTrace stack) {
    debugPrint('Unhandled zone error: $error');
    debugPrintStack(stackTrace: stack);
  });
}

Future<void> _requestPhotoPermissions() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;

  try {
    final PermissionStatus photos = await Permission.photos.request();
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
