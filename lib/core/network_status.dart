import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'app_config.dart';

typedef NetworkProbe = Future<bool> Function();

/// A small, dependency-free connectivity monitor. It deliberately probes DNS
/// instead of assuming that a Wi-Fi icon means the tailnet is reachable.
class NetworkStatusController extends ChangeNotifier {
  NetworkStatusController({
    this.interval = const Duration(seconds: 20),
    NetworkProbe? probe,
  }) : _probe = probe ?? _defaultProbe;

  final Duration interval;
  final NetworkProbe _probe;

  Timer? _timer;
  bool _offline = false;
  bool _checking = false;
  bool _disposed = false;

  bool get isOffline => _offline;
  bool get isChecking => _checking;

  void start() {
    if (_timer != null || _disposed) return;
    unawaited(checkNow());
    _timer = Timer.periodic(interval, (_) => unawaited(checkNow()));
  }

  /// Cancels the periodic probe without disposing the controller. The app
  /// stops an injected controller on teardown and still lets its owner restart
  /// or reuse it.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> checkNow() async {
    if (_checking || _disposed) return;
    _checking = true;
    notifyListeners();

    var online = false;
    try {
      online = await _probe().timeout(const Duration(seconds: 6));
    } catch (_) {
      online = false;
    }

    if (_disposed) return;
    _checking = false;
    _offline = !online;
    notifyListeners();
  }

  static Future<bool> _defaultProbe() async {
    try {
      final Uri? uri = Uri.tryParse(AppConfig.aiUrl);
      if (uri == null || uri.host.isEmpty) return false;
      final List<InternetAddress> result = await InternetAddress.lookup(
        uri.host,
      );
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}

class NetworkStatusScope extends InheritedNotifier<NetworkStatusController> {
  const NetworkStatusScope({
    super.key,
    required NetworkStatusController controller,
    required super.child,
  }) : super(notifier: controller);

  static NetworkStatusController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NetworkStatusScope>()
        ?.notifier;
  }
}
