import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

/// Configuration loaded from the platform secure store.
class WebdavConfig {
  const WebdavConfig({
    required this.url,
    required this.username,
    required this.password,
  });

  final String url;
  final String username;
  final String password;

  bool get hasCredentials => username.trim().isNotEmpty && password.isNotEmpty;
}

/// A thin, app-specific wrapper around the WebDAV client.
///
/// Credentials are written to, and read from, [FlutterSecureStorage]. They are
/// never compiled into the app or committed to source control.
class WebdavService {
  WebdavService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String defaultUrl = 'https://your-nas.your-tailnet.ts.net:8443/dav';
  static const int maxDownloadBytes = 512 * 1024 * 1024;

  static const String _urlKey = 'nas_photo_manager.webdav.url';
  static const String _usernameKey = 'nas_photo_manager.webdav.username';
  static const String _passwordKey = 'nas_photo_manager.webdav.password';

  final FlutterSecureStorage _storage;

  webdav.Client? _client;
  WebdavConfig? _config;

  bool get isConnected => _client != null;

  String get baseUrl => _config?.url ?? defaultUrl;

  /// Persists credentials in the platform keychain/keystore and resets the
  /// client so the next operation reconnects with the new values.
  Future<void> saveCredentials({
    required String url,
    required String username,
    required String password,
  }) async {
    final normalizedUrl = normalizeUrl(url);
    if (username.trim().isEmpty) {
      throw const WebdavException('Username is required.');
    }
    if (password.isEmpty) {
      throw const WebdavException('Password is required.');
    }

    await _storage.write(key: _urlKey, value: normalizedUrl);
    await _storage.write(key: _usernameKey, value: username.trim());
    await _storage.write(key: _passwordKey, value: password);

    _config = WebdavConfig(
      url: normalizedUrl,
      username: username.trim(),
      password: password,
    );
    _client = null;
  }

  /// Reads the current credentials. Missing values fall back to the NAS
  /// defaults so the settings screen always has a usable starting point.
  Future<WebdavConfig> loadConfig() async {
    final url = await _storage.read(key: _urlKey);
    final username = await _storage.read(key: _usernameKey);
    final password = await _storage.read(key: _passwordKey);

    final config = WebdavConfig(
      url: normalizeUrl(url ?? defaultUrl),
      username: username ?? '',
      password: password ?? '',
    );
    _config = config;
    return config;
  }

  /// Validates the endpoint and credentials. A successful OPTIONS request is
  /// preferred; some WebDAV servers only implement PROPFIND, so a directory
  /// listing is used as a fallback.
  Future<void> connect() async {
    final config = await loadConfig();
    if (!config.hasCredentials) {
      throw const WebdavException(
        'No NAS credentials saved. Open Settings and enter the URL, username, and password.',
      );
    }

    final client = webdav.newClient(
      config.url,
      user: config.username,
      password: config.password,
    );
    // Dufs returns multiple WWW-Authenticate challenges on a 401. webdav_client
    // 1.2.2 reads that header with Headers.value, which throws when the header
    // has more than one value. Pre-authenticating with Basic Auth means the
    // server never issues the 401 challenge in the first place.
    client.auth = webdav.BasicAuth(user: config.username, pwd: config.password);
    client.setConnectTimeout(15000);
    client.setSendTimeout(60000);
    client.setReceiveTimeout(60000);
    client.setHeaders(<String, dynamic>{'accept-charset': 'utf-8'});

    try {
      await client.ping();
    } catch (_) {
      // OPTIONS is optional in some servers; PROPFIND proves credentials and
      // connectivity equally well.
      try {
        await client.readDir('/');
      } catch (error) {
        throw WebdavException(
          'Could not connect to the NAS. Check the URL and credentials. ${_message(error)}',
        );
      }
    }

    _client = client;
    _config = config;
  }

  /// Lists a remote directory. Directories and non-image files are returned
  /// too; the gallery filters them for display.
  Future<List<webdav.File>> listFiles(String path) async {
    final client = await _ensureClient();
    try {
      return await client.readDir(_normalizeRemotePath(path));
    } catch (error) {
      throw WebdavException('Could not list NAS files. ${_message(error)}');
    }
  }

  /// Uploads a local file to a remote WebDAV path.
  ///
  /// Missing parent directories are created first. Dufs and most WebDAV
  /// servers return 405 when a directory already exists, which is handled by
  /// the client's `mkdirAll`.
  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final source = io.File(localPath);
    if (!await source.exists()) {
      throw const WebdavException('The local file could not be found.');
    }

    final client = await _ensureClient();
    final target = _normalizeRemotePath(remotePath);
    final parent = _parentPath(target);
    if (parent != '/') {
      try {
        await client.mkdirAll(parent);
      } catch (_) {
        // The upload will surface a meaningful error if the directory is
        // genuinely inaccessible.
      }
    }

    try {
      await client.writeFromFile(localPath, target, onProgress: onProgress);
    } catch (error) {
      throw WebdavException('Could not upload the file. ${_message(error)}');
    }
  }

  /// Downloads a remote file to a local path, creating the local parent
  /// directory when necessary.
  Future<io.File> downloadFile(
    String remotePath,
    String localPath, {
    int? expectedSize,
    void Function(int received, int total)? onProgress,
  }) async {
    if (expectedSize != null && expectedSize > maxDownloadBytes) {
      throw const WebdavException(
        'The remote file is too large to download safely.',
      );
    }
    final client = await _ensureClient();
    final destination = io.File(localPath);
    await destination.parent.create(recursive: true);

    try {
      await client.read2File(
        _normalizeRemotePath(remotePath),
        localPath,
        onProgress: onProgress,
      );
      return destination;
    } catch (error) {
      throw WebdavException('Could not download the file. ${_message(error)}');
    }
  }

  /// Headers for displaying a remote image through [CachedNetworkImage].
  /// The password stays in secure storage and is only used in memory here.
  Map<String, String> get authHeaders {
    final config = _config;
    if (config == null || !config.hasCredentials) {
      return const <String, String>{};
    }
    final encoded = base64Encode(
      utf8.encode('${config.username}:${config.password}'),
    );
    return <String, String>{'Authorization': 'Basic $encoded'};
  }

  /// Fully-qualified URL for a WebDAV file, suitable for an image widget.
  String fileUrl(String remotePath) {
    final normalized = _normalizeRemotePath(remotePath);
    final encodedPath = normalized
        .split('/')
        .map((segment) => segment.isEmpty ? '' : Uri.encodeComponent(segment))
        .join('/');
    return '${baseUrl.replaceAll(RegExp(r'/+$'), '')}$encodedPath';
  }

  Future<webdav.Client> _ensureClient() async {
    final existing = _client;
    if (existing != null) {
      return existing;
    }
    await connect();
    return _client!;
  }

  static String normalizeUrl(String input) {
    var value = input.trim();
    if (value.isEmpty) {
      throw const WebdavException('WebDAV URL is required.');
    }
    if (!value.contains('://')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      throw const WebdavException('Enter a valid WebDAV URL.');
    }
    if (uri.scheme != 'https') {
      throw const WebdavException(
        'WebDAV URL must use HTTPS so credentials are never sent in clear text.',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw const WebdavException(
        'Do not put credentials in the WebDAV URL; use the fields below.',
      );
    }
    if (uri.hasQuery || uri.hasFragment) {
      throw const WebdavException('WebDAV URL must not contain a query or fragment.');
    }
    // Uri.normalize() resolves dot segments in uri.path, so inspect the raw
    // path from the original input as well. The value below is what gets
    // stored and later handed to the HTTP client.
    final int authorityStart = value.indexOf('://') + 3;
    final int pathStart = value.indexOf('/', authorityStart);
    final String rawPath = pathStart < 0 ? '' : value.substring(pathStart);
    final String decodedPath;
    try {
      decodedPath = Uri.decodeComponent(rawPath);
    } on FormatException {
      throw const WebdavException('Enter a valid WebDAV URL.');
    } on ArgumentError {
      throw const WebdavException('Enter a valid WebDAV URL.');
    }
    if (_hasUnsafePathSegments(decodedPath)) {
      throw const WebdavException('WebDAV URL contains an invalid path.');
    }
    return value.replaceAll(RegExp(r'/+$'), '');
  }

  /// Reject paths that could escape the configured WebDAV root. Repeated
  /// decoding catches double-encoded `..` segments before a server sees them.
  static bool isSafeRemotePath(String input) {
    return !_hasUnsafePathSegments(input.trim());
  }

  static bool _hasUnsafePathSegments(String input) {
    var value = input;
    for (var i = 0; i < 3; i++) {
      if (value.contains('\u0000') || value.contains('\\')) return true;
      if (value.split('/').any((segment) => segment == '.' || segment == '..')) {
        return true;
      }
      try {
        final String decoded = Uri.decodeComponent(value);
        if (decoded == value) break;
        value = decoded;
      } on FormatException {
        // A literal percent sign is legal in a path. Stop decoding here and
        // inspect what has already been decoded rather than rejecting it.
        break;
      } on ArgumentError {
        // This Dart SDK reports a truncated percent escape as ArgumentError.
        break;
      }
    }
    if (value.contains('\u0000') || value.contains('\\')) return true;
    return value.split('/').any((segment) => segment == '.' || segment == '..');
  }

  static String _normalizeRemotePath(String input) {
    final value = input.trim();
    if (value.isEmpty || value == '/') {
      return '/';
    }
    if (!isSafeRemotePath(value)) {
      throw const WebdavException('Invalid remote path.');
    }
    return value.startsWith('/') ? value : '/$value';
  }

  static String _parentPath(String path) {
    final normalized = _normalizeRemotePath(path);
    if (normalized == '/') {
      return '/';
    }
    final parts = normalized.split('/')..removeLast();
    final parent = parts.join('/');
    return parent.isEmpty ? '/' : parent;
  }

  static String _message(Object error) {
    final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length > 220 ? '${text.substring(0, 220)}…' : text;
  }
}

class WebdavException implements Exception {
  const WebdavException(this.message);

  final String message;

  @override
  String toString() => message;
}
