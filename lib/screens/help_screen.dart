import 'package:flutter/material.dart';

import '../core/auth_context.dart';
import '../services/webdav_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class _FaqEntry {
  const _FaqEntry(this.question, this.answer);

  final String question;
  final String answer;
}

const List<_FaqEntry> _faq = <_FaqEntry>[
  _FaqEntry(
    "Can't connect to the NAS",
    'The phone must be on the same tailnet as the NAS, and the URL in '
        'Settings must match the WebDAV address (it ends in /dav). Check both, '
        'then run Test connection below.',
  ),
  _FaqEntry(
    'Wrong password',
    'The NAS password comes from your NAS administrator; the app never '
        'changes it. Enter it in Settings and press Save — the app tests the '
        'connection before storing anything.',
  ),
  _FaqEntry(
    'Why do uploads fail?',
    'Usually the NAS is out of space or the phone lost the Tailscale '
        'connection. Check the free space on the NAS, then retry. Photos that '
        'already uploaded stay on the NAS.',
  ),
  _FaqEntry(
    'Which files are supported?',
    'JPG, PNG, HEIC, WebP and GIF pictures appear in the NAS gallery. Other '
        'file types stay hidden from the photo list.',
  ),
  _FaqEntry(
    'Where are my uploads?',
    'Everything you upload from this phone lands in the /uploads folder on '
        'the NAS.',
  ),
  _FaqEntry(
    'Privacy & security',
    'The password is kept in the Android Keystore / iOS Keychain, and all '
        'traffic runs over your private tailnet — nothing is sent anywhere '
        'else.',
  ),
];

const List<_FaqEntry> _adminFaq = <_FaqEntry>[
  _FaqEntry(
    'How do I manage members?',
    'Use the web portal Administration module. This mobile app deliberately '
        'does not expose account or quota mutations, so a phone cannot change '
        'another person\'s access.',
  ),
  _FaqEntry(
    'Why is a module missing for someone?',
    'Modules declare a requiredRole in the manifest. Members see Files, '
        'Photos, AI Assistant and Help; Administration is admin-only. The shell '
        'filters the navigation bar before it builds those routes.',
  ),
  _FaqEntry(
    'What should I do after a suspected session leak?',
    'Revoke the session at the identity portal, then reopen this app. The '
        'offline fallback is always the member role and never restores an '
        'administrator session from cache.',
  ),
  _FaqEntry(
    'Why does the NAS show offline?',
    'The app probes DNS every 20 seconds. Tailscale can be connected while '
        'the NAS is asleep or unreachable; restore the NAS and press Retry in '
        'the offline banner.',
  ),
  _FaqEntry(
    'Where are audit logs?',
    'Server-side logs and user administration live in the web portal. The '
        'mobile client only renders the current session and its permitted '
        'modules.',
  ),
];

List<_FaqEntry> _faqsFor(UserRole role) =>
    role == UserRole.admin ? _adminFaq : _faq;

/// FAQ accordion plus connection diagnostics that reuse the WebDAV service.
class HelpScreen extends StatefulWidget {
  const HelpScreen({
    super.key,
    required this.webdavService,
    this.themeController,
    this.onOpenSettings,
    this.role,
    this.onOpenTutorial,
  });

  final WebdavService webdavService;
  final ThemeController? themeController;
  final VoidCallback? onOpenSettings;
  final UserRole? role;
  final VoidCallback? onOpenTutorial;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _configuredUrl = WebdavService.defaultUrl;
  bool _configLoaded = false;
  String? _configError;

  bool _testing = false;
  String? _testMessage;
  bool _testFailed = false;

  @override
  void initState() {
    super.initState();
    _loadConfiguredUrl();
  }

  Future<void> _loadConfiguredUrl() async {
    String url;
    String? error;
    try {
      final WebdavConfig config = await widget.webdavService.loadConfig();
      url = config.url;
    } catch (_) {
      url = WebdavService.defaultUrl;
      error = 'Saved settings could not be read; showing the default address.';
    }
    if (!mounted) return;
    setState(() {
      _configuredUrl = url;
      _configError = error;
      _configLoaded = true;
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testMessage = null;
    });

    String message;
    bool failed;
    try {
      await widget.webdavService.connect();
      message = 'Connection verified — the NAS answered.';
      failed = false;
    } catch (error) {
      message = error.toString();
      failed = true;
    }

    if (!mounted) return;
    setState(() {
      _testing = false;
      _testMessage = message;
      _testFailed = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ThemeController? themeController = widget.themeController;
    final UserRole role =
        widget.role ?? AuthScope.maybeOf(context)?.role ?? UserRole.user;
    final List<_FaqEntry> faqs = _faqsFor(role);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help'),
        leading: widget.onOpenSettings == null
            ? null
            : AvatarButton(onPressed: widget.onOpenSettings!),
        actions: <Widget>[
          if (themeController != null)
            ThemeToggleButton(controller: themeController),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: <Widget>[
          _RoleGuideCard(role: role, onOpenTutorial: widget.onOpenTutorial),
          const SizedBox(height: 20),
          Text('Frequently asked questions', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final _FaqEntry entry in faqs) ...<Widget>[
            _FaqTile(entry: entry),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          Text('Diagnostics', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildDiagnosticsCard(theme),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'Support: contact your NAS administrator.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: OneDriveTokens.of(context).secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsCard(ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    final OneDriveTokens tokens = OneDriveTokens.of(context);
    final String host = Uri.tryParse(_configuredUrl)?.host ?? '—';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.wifi_tethering, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Connection', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Read-only check of the address saved in Settings.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.secondaryText,
              ),
            ),
            const SizedBox(height: 14),
            _DiagnosticsRow(
              label: 'Configured URL',
              value: _configLoaded || _configError != null
                  ? _configuredUrl
                  : 'Reading secure storage…',
            ),
            const SizedBox(height: 8),
            _DiagnosticsRow(label: 'Host', value: host),
            if (_configError != null) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: tokens.secondaryText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _configError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_testMessage != null) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testFailed
                      ? scheme.errorContainer
                      : scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      _testFailed
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      size: 20,
                      color: _testFailed
                          ? scheme.onErrorContainer
                          : scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _testFailed
                              ? scheme.onErrorContainer
                              : scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt_outlined),
                  label: Text(_testing ? 'Testing…' : 'Test connection'),
                ),
                if (widget.onOpenSettings != null)
                  TextButton(
                    onPressed: widget.onOpenSettings,
                    child: const Text('Open Settings'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleGuideCard extends StatelessWidget {
  const _RoleGuideCard({required this.role, this.onOpenTutorial});

  final UserRole role;
  final VoidCallback? onOpenTutorial;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final OneDriveTokens tokens = OneDriveTokens.of(context);
    final bool admin = role == UserRole.admin;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  admin ? Icons.admin_panel_settings_outlined : Icons.person_outline,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    admin ? 'Administrator guide' : 'Member guide',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    role.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              admin
                  ? 'You can open Administration in addition to every member '
                        'module. Account and quota changes remain in the web '
                        'portal; this app is intentionally read-only for admin '
                        'data.'
                  : 'Files, Photos, AI Assistant and Help are available to you. '
                        'Administration is hidden by the core route guard, and '
                        'direct attempts are blocked before the module mounts.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.secondaryText,
              ),
            ),
            if (onOpenTutorial != null) ...<Widget>[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onOpenTutorial,
                icon: const Icon(Icons.school_outlined, size: 18),
                label: const Text('Open the getting-started tutorial'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsRow extends StatelessWidget {
  const _DiagnosticsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OneDriveTokens tokens = OneDriveTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 116,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.secondaryText,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.entry});

  final _FaqEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OneDriveTokens tokens = OneDriveTokens.of(context);
    return Card(
      child: ExpansionTile(
        title: Text(entry.question, style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            entry.answer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
