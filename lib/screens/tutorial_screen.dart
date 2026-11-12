import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// A single onboarding step shown as a card.
class _TutorialStep {
  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

const List<_TutorialStep> _steps = <_TutorialStep>[
  _TutorialStep(
    icon: Icons.waving_hand_outlined,
    title: 'Welcome',
    body:
        'NAS Photo Manager shows the pictures stored on your home NAS and '
        'lets you add photos from this phone. Everything travels over your '
        'private Tailscale network.',
  ),
  _TutorialStep(
    icon: Icons.settings_ethernet,
    title: 'Connect to the NAS',
    body:
        'Open Settings and keep the pre-filled NAS address. Enter the '
        'username admin and the NAS password. The password is kept in the '
        'Android Keystore / iOS Keychain, never in this app.',
  ),
  _TutorialStep(
    icon: Icons.photo_library_outlined,
    title: 'Browse NAS photos',
    body:
        'NAS Photos lists every picture in the NAS root with thumbnails. '
        'Tap one to download it, then pinch to zoom full screen.',
  ),
  _TutorialStep(
    icon: Icons.cloud_upload_outlined,
    title: 'Upload from the phone',
    body:
        'In Local Photos, tap pictures to select them — several at once — '
        'then press Upload Selected to send them to the /uploads folder on '
        'the NAS.',
  ),
  _TutorialStep(
    icon: Icons.shield_outlined,
    title: 'Stay private',
    body:
        'The app only reaches the NAS over your tailnet, so nothing is '
        'exposed to the public internet. If something does not work, the '
        'Help tab has quick answers.',
  ),
];

/// Step-by-step onboarding with an in-memory progress checklist.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({
    super.key,
    this.themeController,
    this.onOpenSettings,
    this.onOpenHelp,
  });

  final ThemeController? themeController;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenHelp;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final Set<int> _done = <int>{};

  void _toggle(int index) {
    setState(() {
      if (!_done.add(index)) {
        _done.remove(index);
      }
    });
  }

  void _resetProgress() => setState(_done.clear);

  @override
  Widget build(BuildContext context) {
    final ThemeController? themeController = widget.themeController;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutorial'),
        leading: widget.onOpenSettings == null
            ? null
            : AvatarButton(onPressed: widget.onOpenSettings!),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reset progress',
            visualDensity: VisualDensity.compact,
            onPressed: _done.isEmpty ? null : _resetProgress,
            icon: const Icon(Icons.refresh),
          ),
          if (themeController != null)
            ThemeToggleButton(controller: themeController),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: <Widget>[
          _ProgressCard(
            done: _done.length,
            total: _steps.length,
            onGoToSettings: widget.onOpenSettings,
          ),
          const SizedBox(height: 16),
          for (int index = 0; index < _steps.length; index++) ...<Widget>[
            _StepCard(
              index: index,
              step: _steps[index],
              done: _done.contains(index),
              onToggle: () => _toggle(index),
              onOpenHelp: index == _steps.length - 1 ? widget.onOpenHelp : null,
            ),
            if (index < _steps.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.done,
    required this.total,
    this.onGoToSettings,
  });

  final int done;
  final int total;
  final VoidCallback? onGoToSettings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final OneDriveTokens tokens = OneDriveTokens.of(context);
    final double fraction = total == 0 ? 0 : done / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.school_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Getting started',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '$done of $total done',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: fraction, minHeight: 6),
            ),
            const SizedBox(height: 10),
            Text(
              'Tick off each step as you go. Progress is kept on this screen '
              'only — nothing is saved to the network.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.secondaryText,
              ),
            ),
            if (onGoToSettings != null) ...<Widget>[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onGoToSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Go to Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.index,
    required this.step,
    required this.done,
    required this.onToggle,
    this.onOpenHelp,
  });

  final int index;
  final _TutorialStep step;
  final bool done;
  final VoidCallback onToggle;
  final VoidCallback? onOpenHelp;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final OneDriveTokens tokens = OneDriveTokens.of(context);
    final Duration motion = _motion(context);

    return Card(
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AnimatedContainer(
                duration: motion,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: done ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(step.icon, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'STEP ${index + 1}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(step.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      step.body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                    if (onOpenHelp != null) ...<Widget>[
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: onOpenHelp,
                        icon: const Icon(Icons.help_outline, size: 18),
                        label: const Text('Open Help'),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: done ? 'Mark as not done' : 'Mark as done',
                onPressed: onToggle,
                icon: AnimatedSwitcher(
                  duration: motion,
                  child: Icon(
                    done ? Icons.check_circle : Icons.radio_button_unchecked,
                    key: ValueKey<bool>(done),
                    color: done ? scheme.primary : scheme.outlineVariant,
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

/// Collapses implicit animations when the platform asks for reduced motion.
Duration _motion(BuildContext context) {
  final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return reduce ? Duration.zero : const Duration(milliseconds: 200);
}
