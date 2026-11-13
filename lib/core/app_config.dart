abstract final class AppConfig {
  /// The private tailnet host used by the NAS services. These values are safe
  /// placeholders, not secrets; override them at build time as the services
  /// move. Keep the mobile client on the tailnet rather than exposing ports.
  /// The <nas-host> is reached by its MagicDNS hostname rather than its tailnet IP,
  /// because the Tailscale TLS certificate is issued for the hostname only.
  /// Never hardcode the raw tailnet address here: it leaks host identity into
  /// source and fails certificate validation.
  static const String tailnetHost = 'https://your-nas.your-tailnet.ts.net';

  /// Override with:
  /// flutter build apk --debug --dart-define=AI_URL=https://host/ai/
  static const String aiUrl = String.fromEnvironment(
    'AI_URL',
    defaultValue: 'https://your-nas.your-tailnet.ts.net:3000/',
  );

  /// The Photos backend currently exposes an API only; the WebDAV gallery is
  /// served by the NAS/Dufs endpoint. Keep this URL for the future gallery
  /// integration and override it at build time when that UI is available.
  static const String photosUrl = String.fromEnvironment(
    'PHOTOS_URL',
    defaultValue: 'https://your-nas.your-tailnet.ts.net:8082/',
  );

  static const Duration webViewTimeout = Duration(seconds: 18);
  static const Duration moduleRevealDuration = Duration(milliseconds: 420);
}
