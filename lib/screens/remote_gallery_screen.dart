import 'dart:io' as io;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../services/webdav_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'local_gallery_screen.dart';
import 'settings_screen.dart';

enum _GalleryViewMode { grid, list }

enum _PhotoAction { open, download }

/// NAS gallery: root images streamed with authenticated thumbnails, shown as
/// a OneDrive-style grid or list, with search, refresh and a theme switch.
class RemoteGalleryScreen extends StatefulWidget {
  const RemoteGalleryScreen({
    super.key,
    required this.webdavService,
    this.themeController,
    this.onOpenSettings,
    this.onOpenLocalPhotos,
  });

  final WebdavService webdavService;
  final ThemeController? themeController;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenLocalPhotos;

  @override
  State<RemoteGalleryScreen> createState() => RemoteGalleryScreenState();
}

class RemoteGalleryScreenState extends State<RemoteGalleryScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<webdav.File> _images = const <webdav.File>[];
  bool _loading = true;
  bool _needsSetup = false;
  String? _error;
  _GalleryViewMode _viewMode = _GalleryViewMode.grid;
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<webdav.File> get _visibleImages {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _images;
    return _images
        .where(
          (file) =>
              (file.name ?? file.path ?? '').toLowerCase().contains(query),
        )
        .toList(growable: false);
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

  Future<void> _downloadImage(webdav.File file) async {
    final remotePath = file.path ?? '/${file.name ?? ''}';
    final displayName = file.name ?? 'Photo';

    setState(() => _loading = true);
    try {
      final documents = await getApplicationDocumentsDirectory();
      final folder = io.Directory('${documents.path}/NAS Downloads');
      await folder.create(recursive: true);
      final target =
          '${folder.path}/${DateTime.now().microsecondsSinceEpoch}_${_safeFileName(displayName)}';

      await widget.webdavService.downloadFile(remotePath, target);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded "$displayName" to NAS Downloads.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Download failed: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onPhotoAction(webdav.File file, _PhotoAction action) {
    switch (action) {
      case _PhotoAction.open:
        _openImage(file);
      case _PhotoAction.download:
        _downloadImage(file);
    }
  }

  void _startSearch() {
    setState(() => _searching = true);
  }

  void _stopSearch() {
    _searchController.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  void _openSettings() {
    final onOpenSettings = widget.onOpenSettings;
    if (onOpenSettings != null) {
      onOpenSettings();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          webdavService: widget.webdavService,
          onSaved: reload,
        ),
      ),
    );
  }

  void _openLocalGallery() {
    final onOpenLocalPhotos = widget.onOpenLocalPhotos;
    if (onOpenLocalPhotos != null) {
      onOpenLocalPhotos();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocalGalleryScreen(
          webdavService: widget.webdavService,
          themeController: widget.themeController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      floatingActionButton: _searching
          ? null
          : FloatingActionButton.extended(
              onPressed: _openLocalGallery,
              icon: const Icon(Icons.add),
              label: const Text('Upload'),
            ),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final ThemeController? themeController = widget.themeController;

    if (_searching) {
      return AppBar(
        leading: IconButton(
          tooltip: 'Close search',
          onPressed: _stopSearch,
          icon: const Icon(Icons.arrow_back),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: 'Search NAS photos',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      );
    }

    return AppBar(
      title: const Text('NAS Photos'),
      leading: AvatarButton(onPressed: _openSettings),
      actions: <Widget>[
        IconButton(
          tooltip: 'Search NAS photos',
          visualDensity: VisualDensity.compact,
          onPressed: _startSearch,
          icon: const Icon(Icons.search),
        ),
        IconButton(
          tooltip: 'Refresh NAS photos',
          visualDensity: VisualDensity.compact,
          onPressed: _loading ? null : reload,
          icon: const Icon(Icons.refresh),
        ),
        PopupMenuButton<_GalleryViewMode>(
          tooltip: 'Change view',
          icon: const Icon(Icons.view_agenda_outlined),
          onSelected: (value) => setState(() => _viewMode = value),
          itemBuilder: (context) => <PopupMenuEntry<_GalleryViewMode>>[
            CheckedPopupMenuItem<_GalleryViewMode>(
              value: _GalleryViewMode.grid,
              checked: _viewMode == _GalleryViewMode.grid,
              child: const Text('Grid view'),
            ),
            CheckedPopupMenuItem<_GalleryViewMode>(
              value: _GalleryViewMode.list,
              checked: _viewMode == _GalleryViewMode.list,
              child: const Text('List view'),
            ),
          ],
        ),
        if (themeController != null)
          ThemeToggleButton(controller: themeController),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading && _images.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_needsSetup) {
      return EmptyState(
        icon: Icons.settings_ethernet,
        title: 'Connect your NAS',
        message:
            'Enter the NAS address, username, and password in Settings. '
            'The password is stored only in the platform secure store.',
        actionLabel: 'Open Settings',
        actionIcon: Icons.settings_outlined,
        onAction: _openSettings,
      );
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'NAS unavailable',
        message: _error!,
        actionLabel: 'Retry',
        actionIcon: Icons.refresh,
        onAction: reload,
        secondaryLabel: 'Open Settings',
        onSecondary: _openSettings,
      );
    }
    if (_images.isEmpty) {
      return EmptyState(
        icon: Icons.add_photo_alternate_outlined,
        title: 'No photos on the NAS yet',
        message:
            'Upload photos from this phone, or copy files into the NAS root, '
            'then refresh.',
        actionLabel: 'Upload photos',
        actionIcon: Icons.add,
        onAction: _openLocalGallery,
        secondaryLabel: 'Refresh',
        onSecondary: reload,
      );
    }

    final images = _visibleImages;
    if (images.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'No matches',
        message: 'No NAS photos match “$_query”.',
        actionLabel: 'Clear search',
        onAction: _stopSearch,
      );
    }

    return RefreshIndicator(
      onRefresh: reload,
      child: _viewMode == _GalleryViewMode.grid
          ? _buildGrid(images)
          : _buildList(images),
    );
  }

  Widget _buildGrid(List<webdav.File> images) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 104),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final file = images[index];
        final path = file.path ?? '/${file.name ?? ''}';
        return _RemoteGridTile(
          imageUrl: widget.webdavService.fileUrl(path),
          headers: widget.webdavService.authHeaders,
          label: file.name ?? 'Photo',
          onTap: () => _openImage(file),
          onAction: (action) => _onPhotoAction(file, action),
        );
      },
    );
  }

  Widget _buildList(List<webdav.File> images) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 104),
      itemCount: images.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, indent: 68, color: scheme.outlineVariant),
      itemBuilder: (context, index) {
        final file = images[index];
        final path = file.path ?? '/${file.name ?? ''}';
        final name = file.name ?? 'Photo';
        return PhotoListRow(
          leading: RemoteThumb(
            imageUrl: widget.webdavService.fileUrl(path),
            headers: widget.webdavService.authHeaders,
          ),
          title: name,
          subtitle: _subtitle(file),
          onTap: () => _openImage(file),
          trailing: _PhotoMenuButton(
            label: name,
            onSelected: (action) => _onPhotoAction(file, action),
          ),
        );
      },
    );
  }

  static String _subtitle(webdav.File file) {
    final List<String> parts = <String>[];
    if (file.mTime != null) {
      parts.add('Modified ${_formatDate(file.mTime!)}');
    }
    if (file.size != null && file.size! > 0) {
      parts.add(_formatSize(file.size!));
    }
    return parts.isEmpty ? 'Photo' : parts.join(' · ');
  }

  static String _formatDate(DateTime time) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${time.day.toString().padLeft(2, '0')} '
        '${months[time.month - 1]} ${time.year}';
  }

  static String _formatSize(int bytes) {
    const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    int unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final String text = unit == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(value >= 10 ? 0 : 1);
    return '$text ${units[unit]}';
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

class _PhotoMenuButton extends StatelessWidget {
  const _PhotoMenuButton({required this.label, required this.onSelected});

  final String label;
  final ValueChanged<_PhotoAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_PhotoAction>(
      tooltip: 'Options for $label',
      icon: const Icon(Icons.more_horiz),
      onSelected: onSelected,
      itemBuilder: (context) => const <PopupMenuEntry<_PhotoAction>>[
        PopupMenuItem<_PhotoAction>(
          value: _PhotoAction.open,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.open_in_full_outlined),
            title: Text('Open'),
          ),
        ),
        PopupMenuItem<_PhotoAction>(
          value: _PhotoAction.download,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.download_outlined),
            title: Text('Download'),
          ),
        ),
      ],
    );
  }
}

class _RemoteGridTile extends StatelessWidget {
  const _RemoteGridTile({
    required this.imageUrl,
    required this.headers,
    required this.label,
    required this.onTap,
    required this.onAction,
  });

  final String imageUrl;
  final Map<String, String> headers;
  final String label;
  final VoidCallback onTap;
  final ValueChanged<_PhotoAction> onAction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
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
              Positioned(
                top: 4,
                right: 4,
                child: MoreAffordance<_PhotoAction>(
                  tooltip: 'Options for $label',
                  onSelected: onAction,
                  itemBuilder: (context) =>
                      const <PopupMenuEntry<_PhotoAction>>[
                        PopupMenuItem<_PhotoAction>(
                          value: _PhotoAction.open,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.open_in_full_outlined),
                            title: Text('Open'),
                          ),
                        ),
                        PopupMenuItem<_PhotoAction>(
                          value: _PhotoAction.download,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.download_outlined),
                            title: Text('Download'),
                          ),
                        ),
                      ],
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
