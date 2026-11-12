import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_config.dart';
import '../../core/loading_skeleton.dart';
import '../../core/network_status.dart';
import '../../theme.dart';
import '../../widgets/backend_unavailable.dart';
import '../../widgets/common.dart';

class AiModule extends StatefulWidget {
  const AiModule({
    super.key,
    required this.themeController,
    required this.onOpenSettings,
    required this.onOpenHelp,
  });

  final ThemeController themeController;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHelp;

  @override
  State<AiModule> createState() => _AiModuleState();
}

class _AiModuleState extends State<AiModule> {
  late final WebViewController _controller;
  Uri? _allowedOrigin;
  Timer? _timeout;
  bool _loading = true;
  bool _forceOnline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final Uri? base = Uri.tryParse(AppConfig.aiUrl);
    if (base != null && base.scheme == 'https' && base.host.isNotEmpty) {
      _allowedOrigin = base;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
            _startTimeout();
          },
          onPageFinished: (String url) {
            _timeout?.cancel();
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = null;
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame == false) return;
            _fail('The AI assistant could not be loaded. ${error.description}');
          },
          onHttpError: (HttpResponseError error) {
            final int? status = error.response?.statusCode;
            if (status != null && status >= 400) {
              _fail('The AI assistant returned HTTP $status.');
            }
          },
          onNavigationRequest: _onNavigationRequest,
        ),
      );
    _load();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(AppConfig.webViewTimeout, () {
      _fail(
        'The AI assistant did not respond within '
        '${AppConfig.webViewTimeout.inSeconds} seconds. '
        'Check the NAS or tailnet connection, then retry.',
      );
    });
  }

  void _load() {
    final Uri? uri = Uri.tryParse(AppConfig.aiUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      _fail('AI_URL must be a valid HTTPS web address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _startTimeout();
    unawaited(_controller.loadRequest(uri));
  }

  int _effectivePort(Uri uri) {
    if (uri.hasPort) return uri.port;
    return uri.scheme == 'https' ? 443 : 80;
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final Uri? uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (uri.scheme == 'about' && uri.path == 'blank') {
      return NavigationDecision.navigate;
    }
    final Uri? allowed = _allowedOrigin;
    if (allowed == null ||
        uri.scheme != allowed.scheme ||
        uri.host.toLowerCase() != allowed.host.toLowerCase() ||
        _effectivePort(uri) != _effectivePort(allowed)) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Navigation outside the configured AI service was blocked.',
            ),
          ),
        );
      }
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _retryConnection() async {
    final NetworkStatusController? network = NetworkStatusScope.maybeOf(
      context,
    );
    if (network != null) {
      await network.checkNow();
      if (!mounted) return;
      if (network.isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Still offline. Reconnect to the tailnet and try again.',
            ),
          ),
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() => _forceOnline = true);
    _load();
  }

  void _fail(String message) {
    if (!mounted) return;
    _timeout?.cancel();
    if (!_loading && _error == message) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  Widget _buildScaffold(Widget body) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        leading: AvatarButton(onPressed: widget.onOpenSettings),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reload assistant',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          ThemeToggleButton(controller: widget.themeController),
        ],
      ),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final NetworkStatusController? network = NetworkStatusScope.maybeOf(
      context,
    );
    final bool offline = network?.isOffline == true && !_forceOnline;

    if (offline) {
      return _buildScaffold(
        BackendUnavailable(
          icon: Icons.auto_awesome_outlined,
          statusLabel: 'Backend offline',
          title: 'The AI assistant is out of reach',
          message:
              'The NAS or tailnet cannot be reached from this device. The '
              'rest of the app stays available, and the assistant will open '
              'again as soon as the private connection returns.',
          endpoint: AppConfig.aiUrl,
          primaryLabel: 'Retry connection',
          primaryIcon: Icons.refresh,
          onPrimary: _retryConnection,
          secondaryLabel: 'Open Help',
          onSecondary: widget.onOpenHelp,
        ),
      );
    }

    if (_error != null) {
      return _buildScaffold(
        BackendUnavailable(
          icon: Icons.smart_toy_outlined,
          statusLabel: 'Assistant unavailable',
          title: 'The assistant did not answer',
          message: _error!,
          endpoint: AppConfig.aiUrl,
          primaryLabel: 'Retry',
          primaryIcon: Icons.refresh,
          onPrimary: _load,
          secondaryLabel: 'Open Help',
          onSecondary: widget.onOpenHelp,
        ),
      );
    }

    return _buildScaffold(
      Stack(
        fit: StackFit.expand,
        children: <Widget>[
          WebViewWidget(controller: _controller),
          if (_loading)
            const Positioned.fill(
              child: _AiLoadingSkeleton(),
            ),
        ],
      ),
    );
  }
}

class _AiLoadingSkeleton extends StatelessWidget {
  const _AiLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Semantics(
      label: 'Opening the AI assistant',
      child: ExcludeSemantics(
        child: Material(
          color: scheme.surface,
          child: SkeletonPulse(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const SkeletonBlock(height: 38, width: 38, radius: 19),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const SkeletonBlock(height: 12, width: 142),
                          const SizedBox(height: 7),
                          const SkeletonBlock(height: 9, width: 94),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _SkeletonBubble(
                      width: 272,
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: _SkeletonBubble(width: 318),
                  ),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: _SkeletonBubble(width: 224),
                  ),
                  const Spacer(),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: scheme.outlineVariant),
                            color: scheme.surfaceContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SkeletonBlock(
                        height: 48,
                        width: 48,
                        radius: 14,
                        color: scheme.primaryContainer.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonBubble extends StatelessWidget {
  const _SkeletonBubble({required this.width, this.color});

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonBlock(height: 10, width: double.infinity),
          SizedBox(height: 8),
          SkeletonBlock(height: 10, width: 186),
        ],
      ),
    );
  }
}
