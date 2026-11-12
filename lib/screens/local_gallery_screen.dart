import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../core/network_status.dart';
import '../services/webdav_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'settings_screen.dart';

enum _GalleryViewMode { grid, list }

enum _GalleryMenuAction { refresh, grid, list }

enum _LocalAction { upload }

/// Device gallery with OneDrive-style selection: tap to select, the header
/// shows “N selected”, and the bottom bar uploads to /uploads on the NAS.
class LocalGalleryScreen extends StatefulWidget {
  const LocalGalleryScreen({
    super.key,
    required this.webdavService,
    this.themeController,
    this.onOpenSettings,
    this.onBack,
  });

  final WebdavService webdavService;
  final ThemeController? themeController;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onBack;

  @override
  State<LocalGalleryScreen> createState() => _LocalGalleryScreenState();
}

class _LocalGalleryScreenState extends State<LocalGalleryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = <String>{};

  List<AssetEntity> _assets = const <AssetEntity>[];
  bool _loading = true;
  bool _uploading = false;
  double _uploadProgress = 0;
  bool _permissionDenied = false;
  String? _error;
  _GalleryViewMode _viewMode = _GalleryViewMode.grid;
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    await _uploadAssets(selected, clearSelectionOnDone: true);
  }

  Future<void> _uploadAsset(AssetEntity asset) async {
    if (_uploading) return;
    await _uploadAssets(<AssetEntity>[asset]);
  }

  Future<void> _uploadAssets(
    List<AssetEntity> selected, {
    bool clearSelectionOnDone = false,
  }) async {
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
        if (clearSelectionOnDone) {
          _selectedIds.clear();
        }
      });
      final skippedText = skipped > 0 ? ' $skipped could not be read.' : '';
      final noun = selected.length == 1 ? 'photo' : 'photos';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uploaded $uploaded of ${selected.length} $noun to /uploads.$skippedText',
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
    if (files.isEmpty || !mounted) return;

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

  void _clearSelection() {
    if (_uploading) return;
    setState(_selectedIds.clear);
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
        builder: (_) => SettingsScreen(webdavService: widget.webdavService),
      ),
    );
  }

  List<AssetEntity> get _visibleAssets {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _assets;
    return _assets
        .where((asset) => (asset.title ?? '').toLowerCase().contains(query))
        .toList(growable: false);
  }

  bool get _selectionActive => _selectedIds.isNotEmpty || _uploading;

  @override
  Widget build(BuildContext context) {
    final NetworkStatusController? network = NetworkStatusScope.maybeOf(
      context,
    );
    final bool offline = network?.isOffline == true;

    return Scaffold(
      appBar: _buildAppBar(),
      floatingActionButton: _uploading
          ? null
          : FloatingActionButton(
              tooltip: 'Upload files from device',
              onPressed: _pickFiles,
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: _selectionActive ? _buildUploadBar() : null,
      body: Column(
        children: <Widget>[
          if (offline) _NasOfflineNotice(controller: network),
          Expanded(child: _buildGallery()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final ThemeController? themeController = widget.themeController;

    if (_selectedIds.isNotEmpty && !_searching) {
      return AppBar(
        leading: IconButton(
          tooltip: 'Exit selection',
          onPressed: _uploading ? null : _clearSelection,
          icon: const Icon(Icons.close),
        ),
        title: Text('${_selectedIds.length} selected'),
        actions: <Widget>[
          if (themeController != null)
            ThemeToggleButton(controller: themeController),
        ],
      );
    }

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
            hintText: 'Search local photos',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      );
    }

    final VoidCallback? onBack = widget.onBack;
    return AppBar(
      title: const Text('Local Photos'),
      leading: onBack != null
          ? IconButton(
              tooltip: 'Back to Photos',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            )
          : AvatarButton(onPressed: _openSettings),
      actions: <Widget>[
        IconButton(
          tooltip: 'Search local photos',
          visualDensity: VisualDensity.compact,
          onPressed: _startSearch,
          icon: const Icon(Icons.search),
        ),
        PopupMenuButton<_GalleryMenuAction>(
          tooltip: 'More options',
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case _GalleryMenuAction.refresh:
                _loadAssets();
              case _GalleryMenuAction.grid:
                setState(() => _viewMode = _GalleryViewMode.grid);
              case _GalleryMenuAction.list:
                setState(() => _viewMode = _GalleryViewMode.list);
            }
          },
          itemBuilder: (context) => <PopupMenuEntry<_GalleryMenuAction>>[
            const PopupMenuItem<_GalleryMenuAction>(
              value: _GalleryMenuAction.refresh,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.refresh),
                title: Text('Refresh'),
              ),
            ),
            const PopupMenuDivider(),
            CheckedPopupMenuItem<_GalleryMenuAction>(
              value: _GalleryMenuAction.grid,
              checked: _viewMode == _GalleryViewMode.grid,
              child: const Text('Grid view'),
            ),
            CheckedPopupMenuItem<_GalleryMenuAction>(
              value: _GalleryMenuAction.list,
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

  Widget _buildGallery() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_permissionDenied) {
      return EmptyState(
        icon: Icons.no_photography_outlined,
        title: 'Photo access is off',
        message:
            'Allow photo access in system settings to choose photos for '
            'upload.',
        actionLabel: 'Open settings',
        actionIcon: Icons.settings_outlined,
        onAction: PhotoManager.openSetting,
      );
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not read local photos',
        message: _error!,
        actionLabel: 'Retry',
        actionIcon: Icons.refresh,
        onAction: _loadAssets,
      );
    }
    if (_assets.isEmpty) {
      return EmptyState(
        icon: Icons.photo_outlined,
        title: 'No photos on this device',
        message:
            'Take a photo or copy pictures to this phone, then refresh to '
            'upload them to the NAS.',
        actionLabel: 'Refresh',
        actionIcon: Icons.refresh,
        onAction: _loadAssets,
      );
    }

    final assets = _visibleAssets;
    if (assets.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'No matches',
        message: 'No local photos match “$_query”.',
        actionLabel: 'Clear search',
        onAction: _stopSearch,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAssets,
      child: _viewMode == _GalleryViewMode.grid
          ? _buildGrid(assets)
          : _buildList(assets),
    );
  }

  Widget _buildGrid(List<AssetEntity> assets) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 104),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        final asset = assets[index];
        return _LocalAssetTile(
          asset: asset,
          selected: _selectedIds.contains(asset.id),
          onTap: () => _toggle(asset),
          onAction: (action) {
            switch (action) {
              case _LocalAction.upload:
                _uploadAsset(asset);
            }
          },
        );
      },
    );
  }

  Widget _buildList(List<AssetEntity> assets) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 104),
      itemCount: assets.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, indent: 68, color: scheme.outlineVariant),
      itemBuilder: (context, index) {
        final asset = assets[index];
        final selected = _selectedIds.contains(asset.id);
        return PhotoListRow(
          highlighted: selected,
          leading: _LocalThumb(asset: asset, size: 120),
          title: asset.title ?? 'Photo',
          subtitle: _assetSubtitle(asset),
          onTap: () => _toggle(asset),
          trailing: _SelectionCheck(
            selected: selected,
            onPressed: () => _toggle(asset),
          ),
        );
      },
    );
  }

  static String _assetSubtitle(AssetEntity asset) {
    return 'Photo · ${_formatDate(asset.modifiedDateTime)}';
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

  Widget _buildUploadBar() {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_uploading)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    minHeight: 5,
                  ),
                ),
              ),
            Row(
              children: <Widget>[
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

class _NasOfflineNotice extends StatelessWidget {
  const _NasOfflineNotice({required this.controller});

  final NetworkStatusController? controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool checking = controller?.isChecking ?? false;

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 7, 8, 7),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: 17,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'NAS offline — local photos stay available; uploads resume '
                'when the tailnet reconnects.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  height: 1.35,
                ),
              ),
            ),
            TextButton(
              onPressed: checking ? null : controller?.checkNow,
              style: TextButton.styleFrom(
                foregroundColor: scheme.onPrimaryContainer,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(checking ? 'Checking…' : 'Retry'),
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
    required this.onAction,
  });

  final AssetEntity asset;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<_LocalAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _LocalThumb(asset: asset, size: 300),
              if (selected)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              Positioned(
                top: 6,
                right: 6,
                child: _SelectionCheck(selected: selected, onPressed: onTap),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: MoreAffordance<_LocalAction>(
                  tooltip: 'Options for ${asset.title ?? 'photo'}',
                  onSelected: onAction,
                  itemBuilder: (context) =>
                      const <PopupMenuEntry<_LocalAction>>[
                        PopupMenuItem<_LocalAction>(
                          value: _LocalAction.upload,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.cloud_upload_outlined),
                            title: Text('Upload'),
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

/// Circle checkmarks: empty ring when unselected, brand check when selected.
class _SelectionCheck extends StatelessWidget {
  const _SelectionCheck({required this.selected, required this.onPressed});

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : Colors.black38,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Icon(
            selected ? Icons.check : Icons.radio_button_unchecked,
            size: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _LocalThumb extends StatelessWidget {
  const _LocalThumb({required this.asset, required this.size});

  final AssetEntity asset;
  final int size;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(
        ThumbnailSize.square(size),
        quality: size >= 300 ? 80 : 70,
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
        return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
      },
    );
  }
}
