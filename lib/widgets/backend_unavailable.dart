import 'package:flutter/material.dart';

import '../theme.dart';

/// A calm, reusable offline/coming-soon surface for isolated remote modules.
/// It deliberately avoids raw plugin or HTTP errors: the shell explains what
/// is unavailable, shows the configured endpoint when useful, and keeps the
/// rest of the app reachable.
class BackendUnavailable extends StatelessWidget {
  const BackendUnavailable({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.eyebrow = 'Isolated module',
    this.statusLabel = 'Backend offline',
    this.endpoint,
    this.primaryLabel,
    this.primaryIcon,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String eyebrow;
  final String statusLabel;
  final String? endpoint;
  final String? primaryLabel;
  final IconData? primaryIcon;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final OneDriveTokens tokens = OneDriveTokens.of(context);
    final bool canAct = primaryLabel != null && onPrimary != null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        scheme.primaryContainer.withValues(alpha: 0.72),
                        scheme.surface,
                        scheme.surface,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          _Pill(
                            icon: Icons.shield_outlined,
                            label: eyebrow,
                            foreground: scheme.primary,
                            background: scheme.surface.withValues(alpha: 0.72),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: _Pill(
                              icon: Icons.cloud_off_outlined,
                              label: statusLabel,
                              foreground: tokens.secondaryText,
                              background: scheme.surface.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: scheme.outlineVariant),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(icon, size: 32, color: scheme.primary),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: tokens.secondaryText,
                          height: 1.55,
                        ),
                      ),
                      if (endpoint != null && endpoint!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.66),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.link,
                                size: 15,
                                color: tokens.secondaryText,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  endpoint!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    color: tokens.secondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (canAct) ...<Widget>[
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            FilledButton.icon(
                              onPressed: onPrimary,
                              icon: Icon(primaryIcon ?? Icons.refresh),
                              label: Text(primaryLabel!),
                            ),
                            if (secondaryLabel != null &&
                                onSecondary != null)
                              TextButton(
                                onPressed: onSecondary,
                                child: Text(secondaryLabel!),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer.withValues(alpha: 0.55),
                    border: Border(
                      top: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The rest of the shell stays available. This module '
                          'never receives the app DOM, device permissions or '
                          'top-level navigation.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.secondaryText,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
