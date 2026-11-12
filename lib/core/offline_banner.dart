import 'package:flutter/material.dart';

import 'network_status.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final NetworkStatusController? controller =
        NetworkStatusScope.maybeOf(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool visible = controller != null && controller.isOffline;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: !visible
          ? const SizedBox.shrink(key: ValueKey<String>('network-online'))
          : Material(
              key: const ValueKey<String>('network-offline'),
              color: scheme.errorContainer,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 18,
                        color: scheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          controller.isChecking
                              ? 'Checking the connection…'
                              : 'You are offline. Local browsing still works; '
                                    'NAS actions will retry when you reconnect.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onErrorContainer),
                        ),
                      ),
                      TextButton(
                        onPressed: controller.isChecking
                            ? null
                            : controller.checkNow,
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.onErrorContainer,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
