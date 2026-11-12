import 'package:flutter/material.dart';

import '../../core/auth_context.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class AdminModule extends StatelessWidget {
  const AdminModule({
    super.key,
    required this.themeController,
    required this.onOpenSettings,
  });

  final ThemeController themeController;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final AuthContext auth = AuthScope.of(context);
    final ThemeData theme = Theme.of(context);
    final OneDriveTokens tokens = OneDriveTokens.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        leading: AvatarButton(onPressed: onOpenSettings),
        actions: <Widget>[ThemeToggleButton(controller: themeController)],
      ),
      body: !auth.canAccess(UserRole.admin)
          ? const EmptyState(
              icon: Icons.lock_outline,
              title: 'Administrator access required',
              message:
                  'This module is hidden and routed around unless the core '
                  'Auth Context has the administrator role.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.admin_panel_settings_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Administrator workspace',
                              style: theme.textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Signed in as ${auth.username} with the '
                          '${auth.role.label} role.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'User management and quota controls live in the '
                          'web portal. This mobile module is intentionally '
                          'read-only so a phone cannot silently change '
                          'account permissions.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const _AdminCard(
                  icon: Icons.shield_outlined,
                  title: 'Access is checked twice',
                  body:
                      'The shell removes Administration from the navigation '
                      'bar for members, and this screen repeats the role check '
                      'before rendering admin content.',
                ),
                const _AdminCard(
                  icon: Icons.view_module_outlined,
                  title: 'Manifest-controlled modules',
                  body:
                      'Files, Photos, AI Assistant and Help are member '
                      'modules. Administration declares requiredRole: admin '
                      'in the manifest, so the core route guard blocks direct '
                      'attempts to reach it.',
                ),
                const _AdminCard(
                  icon: Icons.security_outlined,
                  title: 'Offline behaviour',
                  body:
                      'If the NAS or tailnet is unavailable, the shell keeps '
                      'its cached navigation and shows an offline banner. It '
                      'does not promote a cached member session to admin.',
                ),
              ],
            ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OneDriveTokens tokens = OneDriveTokens.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
