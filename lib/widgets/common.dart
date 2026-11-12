import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Compact circular avatar that opens the account (Settings) surface,
/// mirroring the OneDrive mobile top bar.
class AvatarButton extends StatelessWidget {
  const AvatarButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: 'Account and settings',
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: scheme.primaryContainer,
        child: Icon(Icons.person, size: 18, color: scheme.onPrimaryContainer),
      ),
    );
  }
}

/// Switches the app between the light and the dark OneDrive theme.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    final Brightness platformBrightness = MediaQuery.platformBrightnessOf(
      context,
    );
    final bool isDark = controller.isDark(platformBrightness);
    return IconButton(
      tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
      visualDensity: VisualDensity.compact,
      onPressed: () => controller.toggle(platformBrightness),
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
    );
  }
}

/// Fluent-style empty state: a soft brand-colored icon, a title, an
/// explanation, and one filled action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final OneDriveTokens tokens = OneDriveTokens.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 24),
              actionIcon == null
                  ? FilledButton(onPressed: onAction, child: Text(actionLabel!))
                  : FilledButton.icon(
                      onPressed: onAction,
                      icon: Icon(actionIcon),
                      label: Text(actionLabel!),
                    ),
            ],
            if (secondaryLabel != null && onSecondary != null) ...<Widget>[
              const SizedBox(height: 4),
              TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 64dp two-line list row used by the photo lists: thumbnail or type icon,
/// 16/24 file name, 13dp secondary metadata, and a trailing affordance.
class PhotoListRow extends StatelessWidget {
  const PhotoListRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.highlighted = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OneDriveTokens tokens = OneDriveTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.only(left: 16, right: 4),
        color: highlighted ? tokens.selection : null,
        child: Row(
          children: <Widget>[
            SizedBox(width: 40, height: 40, child: leading),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Square, rounded authenticated thumbnail used by the NAS photo lists.
class RemoteThumb extends StatelessWidget {
  const RemoteThumb({
    super.key,
    required this.imageUrl,
    required this.headers,
    this.radius = 8,
  });

  final String imageUrl;
  final Map<String, String> headers;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          httpHeaders: headers,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (BuildContext context, String url) => const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (BuildContext context, String url, Object error) =>
              const Center(child: Icon(Icons.broken_image_outlined, size: 20)),
        ),
      ),
    );
  }
}

/// Small translucent “…” affordance laid over grid thumbnails, matching the
/// OneDrive photo grid.
class MoreAffordance<T> extends StatelessWidget {
  const MoreAffordance({
    super.key,
    required this.tooltip,
    required this.onSelected,
    required this.itemBuilder,
  });

  final String tooltip;
  final ValueChanged<T> onSelected;
  final PopupMenuItemBuilder<T> itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<T>(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onSelected: onSelected,
        itemBuilder: itemBuilder,
        child: const SizedBox(
          width: 26,
          height: 26,
          child: Icon(Icons.more_horiz, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
