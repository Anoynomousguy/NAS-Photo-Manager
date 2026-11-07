import 'dart:io' as io;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../services/webdav_service.dart';
import 'local_gallery_screen.dart';
import 'settings_screen.dart';

class RemoteGalleryScreen extends StatefulWidget {
  const RemoteGalleryScreen({super.key, required this.webdavService});

  final WebdavService webdavService;

  @override
  State<RemoteGalleryScreen> createState() => RemoteGalleryScreenState();
}

class RemoteGalleryScreenState extends State<RemoteGalleryScreen> {
  List<webdav.File> _images = const <webdav.File>[];
  bool _loading = true;
  bool _needsSetup = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _needsSetup = false;
    });

    try {
      final config = await widget.webdavService.loadConfig();
      if (!config.hasCredentials) {
        if (!mounted) return;
        setState(() {
          _needsSetup = true;
          _loading = false;
        });
        return;
      }

      await widget.webdavService.connect();
      final files = await widget.webdavService.listFiles('/');
      final images =
          files.where((file) => file.isDir != true && _isImage(file)).toList()
            ..sort((a, b) {
              final aTime = a.mTime ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bTime = b.mTime ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });

      if (!mounted) return;
      setState(() {
        _images = images;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openImage(webdav.File file) async {
    final remotePath = file.path ?? '/${file.name ?? ''}';
    final displayName = file.name ?? 'Photo';

    setState(() => _loading = true);
    try {
      final tempDirectory = await getTemporaryDirectory();
      final localName =
          '${DateTime.now().microsecondsSinceEpoch}_${_safeFileName(displayName)}';
      final localFile = io.File('${tempDirectory.path}/$localName');

      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 14),
                  Text('Downloading photo…'),
                ],
              ),
            ),
          ),
        ),
      );

      await widget.webdavService.downloadFile(remotePath, localFile.path);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              RemoteImageViewerScreen(file: localFile, title: displayName),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Download failed: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openLocalGallery() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocalGalleryScreen(webdavService: widget.webdavService),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          webdavService: widget.webdavService,
          onSaved: reload,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NAS Photos'),
        actions: [
          IconButton(
            tooltip: 'Refresh NAS photos',
            onPressed: _loading ? null : reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openLocalGallery,
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Upload photos'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _images.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_needsSetup) {
      return _MessagePanel(
        icon: Icons.settings_ethernet,
        title: 'Connect your NAS',
        message:
            'Enter the WebDAV URL, username, and password in Settings. '
            'The password is stored only in the platform secure store.',
        actionLabel: 'Open Settings',
        onAction: _openSettings,
      );
    }
    if (_error != null) {
      return _MessagePanel(
        icon: Icons.cloud_off_outlined,
        title: 'NAS unavailable',
        message: _error!,
        actionLabel: 'Retry',
        onAction: reload,
        secondaryLabel: 'Settings',
        onSecondary: _openSettings,
      );
    }
    if (_images.isEmpty) {
      return _MessagePanel(
        icon: Icons.photo_outlined,
        title: 'No photos on the NAS',
        message:
            'Upload photos from the local gallery or add files to the NAS '
            'root, then refresh.',
        actionLabel: 'Refresh',
        onAction: reload,
      );
    }

    return RefreshIndicator(
      onRefresh: reload,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 92),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final file = _images[index];
          final path = file.path ?? '/${file.name ?? ''}';
          return _RemoteImageTile(
            imageUrl: widget.webdavService.fileUrl(path),
            headers: widget.webdavService.authHeaders,
            label: file.name ?? 'Photo',
            onTap: () => _openImage(file),
          );
        },
      ),
    );
  }

  static bool _isImage(webdav.File file) {
    final mime = file.mimeType?.toLowerCase() ?? '';
    if (mime.startsWith('image/')) return true;

    final name = (file.name ?? file.path ?? '').toLowerCase();
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return false;
    final extension = name.substring(dot + 1);
    return const <String>{
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'heic',
      'heif',
      'bmp',
      'tif',
      'tiff',
      'avif',
    }.contains(extension);
  }

  static String _safeFileName(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_').trim();
    return cleaned.isEmpty ? 'photo' : cleaned;
  }
}

class _RemoteImageTile extends StatelessWidget {
  const _RemoteImageTile({
    required this.imageUrl,
    required this.headers,
    required this.label,
    required this.onTap,
  });

  final String imageUrl;
  final Map<String, String> headers;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                httpHeaders: headers,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, _) => const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, _, _) =>
                    const Center(child: Icon(Icons.broken_image_outlined)),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 14, 6, 5),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Colors.transparent, Colors.black54],
                    ),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RemoteImageViewerScreen extends StatelessWidget {
  const RemoteImageViewerScreen({
    super.key,
    required this.file,
    required this.title,
  });

  final io.File file;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: PhotoView(
        imageProvider: FileImage(file),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        minScale: PhotoViewComputedScale.contained * 0.8,
        maxScale: PhotoViewComputedScale.covered * 3,
        initialScale: PhotoViewComputedScale.contained,
        loadingBuilder: (context, event) =>
            const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Text(
            'Could not display this image.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel),
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
