import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/webdav_service.dart';

class LocalGalleryScreen extends StatefulWidget {
  const LocalGalleryScreen({super.key, required this.webdavService});

  final WebdavService webdavService;

  @override
  State<LocalGalleryScreen> createState() => _LocalGalleryScreenState();
}

class _LocalGalleryScreenState extends State<LocalGalleryScreen> {
  final Set<String> _selectedIds = <String>{};
  List<AssetEntity> _assets = const <AssetEntity>[];
  bool _loading = true;
  bool _uploading = false;
  double _uploadProgress = 0;
  bool _permissionDenied = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });

    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth && !permission.hasAccess) {
        if (!mounted) return;
        setState(() {
          _permissionDenied = true;
          _loading = false;
        });
        return;
      }

      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
        hasAll: true,
      );
      if (paths.isEmpty) {
        if (!mounted) return;
        setState(() {
          _assets = const <AssetEntity>[];
          _loading = false;
        });
        return;
      }

      final assets = await paths.first.getAssetListPaged(page: 0, size: 300);
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _selectedIds.removeWhere(
          (id) => !assets.any((asset) => asset.id == id),
        );
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

  Future<void> _uploadSelected() async {
    if (_selectedIds.isEmpty || _uploading) return;

    final selected = _assets
        .where((asset) => _selectedIds.contains(asset.id))
        .toList(growable: false);
    if (selected.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    var uploaded = 0;
    var skipped = 0;
    try {
      await widget.webdavService.connect();

      for (var index = 0; index < selected.length; index++) {
        final asset = selected[index];
        final localFile = await asset.file;
        if (localFile == null) {
          skipped++;
          continue;
        }

        final remoteName = await _remoteName(asset, localFile.path);
        await widget.webdavService.uploadFile(
          localFile.path,
          '/uploads/$remoteName',
          onProgress: (sent, total) {
            if (!mounted || total <= 0) return;
            final fileProgress = (sent / total).clamp(0.0, 1.0);
            setState(() {
              _uploadProgress = (index + fileProgress) / selected.length;
            });
          },
        );
        uploaded++;
      }

      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadProgress = 1;
        _selectedIds.clear();
      });
      final skippedText = skipped > 0 ? ' $skipped could not be read.' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uploaded $uploaded of ${selected.length} photos to /uploads.$skippedText',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $error')));
    }
  }

  Future<void> _pickFiles() async {
    if (_uploading) return;

    final selectedFiles = await FilePicker.pickFiles(type: FileType.image);
    final files = selectedFiles
        .where((file) => file.path != null)
        .toList(growable: false);
    if (files.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    var uploaded = 0;
    try {
      await widget.webdavService.connect();
      for (var index = 0; index < files.length; index++) {
        final file = files[index];
        final remoteName =
            '${DateTime.now().millisecondsSinceEpoch}_${_safeFileName(file.name)}';
        await widget.webdavService.uploadFile(
          file.path!,
          '/uploads/$remoteName',
          onProgress: (sent, total) {
            if (!mounted || total <= 0) return;
            setState(() {
              _uploadProgress =
                  (index + (sent / total).clamp(0.0, 1.0)) / files.length;
            });
          },
        );
        uploaded++;
      }

      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadProgress = 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded $uploaded file(s) to /uploads.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $error')));
    }
  }

  Future<String> _remoteName(AssetEntity asset, String localPath) async {
    final original = asset.title?.trim();
    final base = (original == null || original.isEmpty)
        ? localPath.split('/').last
        : original;
    final extension = _extension(base);
    final stem = extension.isEmpty
        ? base
        : base.substring(0, base.length - extension.length);
    return '${DateTime.now().microsecondsSinceEpoch}_'
        '${asset.id}_${_safeFileName(stem)}$extension';
  }

  static String _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot).toLowerCase();
  }

  static String _safeFileName(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? 'photo' : cleaned;
  }

  void _toggle(AssetEntity asset) {
    if (_uploading) return;
    setState(() {
      if (!_selectedIds.add(asset.id)) {
        _selectedIds.remove(asset.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Photos'),
        actions: [
          IconButton(
            tooltip: 'Upload files from device',
            onPressed: _uploading ? null : _pickFiles,
            icon: const Icon(Icons.upload_file_outlined),
          ),
          IconButton(
            tooltip: 'Refresh local photos',
            onPressed: _loading ? null : _loadAssets,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildGallery()),
          if (_selectedIds.isNotEmpty || _uploading) _buildUploadBar(),
        ],
      ),
    );
  }

  Widget _buildGallery() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_permissionDenied) {
      return _LocalMessage(
        icon: Icons.photo_library_outlined,
        title: 'Photo access is off',
        message: 'Allow photo access in system settings to choose photos for upload.',
        actionLabel: 'Open settings',
        onAction: () => PhotoManager.openSetting(),
      );
    }
    if (_error != null) {
      return _LocalMessage(
        icon: Icons.error_outline,
        title: 'Could not read local photos',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadAssets,
      );
    }
    if (_assets.isEmpty) {
      return _LocalMessage(
        icon: Icons.photo_outlined,
        title: 'No photos found',
        message: 'The device photo library is empty or still loading.',
        actionLabel: 'Refresh',
        onAction: _loadAssets,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAssets,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(6),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: _assets.length,
        itemBuilder: (context, index) {
          final asset = _assets[index];
          final selected = _selectedIds.contains(asset.id);
          return _LocalAssetTile(
            asset: asset,
            selected: selected,
            onTap: () => _toggle(asset),
          );
        },
      ),
    );
  }

  Widget _buildUploadBar() {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_uploading)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(value: _uploadProgress),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _uploading
                        ? 'Uploading selected photos…'
                        : '${_selectedIds.length} selected',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _uploading ? null : _uploadSelected,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Upload Selected'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalAssetTile extends StatelessWidget {
  const _LocalAssetTile({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final AssetEntity asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List?>(
                future: asset.thumbnailDataWithSize(
                  const ThumbnailSize.square(300),
                  quality: 80,
                ),
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  if (bytes == null) {
                    return const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  return Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  );
                },
              ),
              if (selected)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primary
                        : Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    selected ? Icons.check : Icons.add,
                    size: 16,
                    color: Colors.white,
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

class _LocalMessage extends StatelessWidget {
  const _LocalMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

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
          ],
        ),
      ),
    );
  }
}
