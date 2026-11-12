import 'package:flutter/material.dart';

/// Installs the app-wide error UI before runApp. Keep this free of module,
/// theme and service imports: an ErrorWidget must render even when the rest of
/// the widget tree failed.
void installErrorHandlers() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF1F1F1F),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'This screen hit an unexpected error.\n'
              'The rest of the app is still protected.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
            ),
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Unhandled Flutter error: ${details.exceptionAsString()}');
  };
}
