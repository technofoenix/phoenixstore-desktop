import 'package:flutter/foundation.dart';

/// API server selected for this terminal.
///
/// The URL comes from the build environment:
///   flutter run   --dart-define-from-file=.env.development   (http://localhost)
///   flutter build --dart-define-from-file=.env.production    (https://domain)
///
/// Plain `http://` is only accepted for this machine (localhost). Any other
/// host must use `https://`, so credentials and tokens never cross the shop
/// network in clear text. Debug builds also accept private LAN addresses for
/// testing against a server on another PC.
class ServerConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// A release build without `API_BASE_URL` gets no server at all, so a missing
  /// env file fails loudly instead of silently pointing at localhost.
  static String get defaultBaseUrl => _envBaseUrl.isNotEmpty
      ? _envBaseUrl
      : (kReleaseMode ? '' : 'https://phoenixapistore.dpdns.org');

  static String _baseUrl = normalize(defaultBaseUrl);

  static String get baseUrl => _baseUrl;

  static set baseUrl(String value) {
    final normalized = normalize(value);
    if (normalized.isNotEmpty && isAllowed(normalized)) _baseUrl = normalized;
  }

  /// True when the configured server may receive credentials.
  static bool get isConfigured => _baseUrl.isNotEmpty && isAllowed(_baseUrl);

  /// Accepts values with/without a scheme and tolerates a pasted `/api/v1`
  /// suffix. Every request already carries `/api/v1/...`, so keeping the
  /// prefix in the base would produce `/api/v1/api/v1/...` and a 404.
  ///
  /// A missing scheme becomes `https://`, except for local and LAN hosts.
  static String normalize(String input) {
    var value = input.trim();
    if (value.isEmpty) return '';
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      final host = Uri.tryParse('http://$value')?.host ?? '';
      // A bare local/LAN address almost never has a certificate; it is still
      // refused in release builds by [isAllowed].
      value = isLoopback(host) || isPrivateLan(host)
          ? 'http://$value'
          : 'https://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    const apiSuffix = '/api/v1';
    if (value.endsWith(apiSuffix)) {
      value = value.substring(0, value.length - apiSuffix.length);
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  /// Whether requests (and the bearer token) may be sent to [url].
  ///
  /// [allowLan] defaults to debug mode; tests pass it explicitly.
  static bool isAllowed(String url, {bool? allowLan}) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    if (uri.scheme == 'https') return true;
    if (uri.scheme != 'http') return false;
    if (isLoopback(uri.host)) return true;
    return (allowLan ?? kDebugMode) && isPrivateLan(uri.host);
  }

  static bool isLoopback(String host) {
    final h = host.toLowerCase();
    return h == 'localhost' ||
        h.endsWith('.localhost') ||
        h == '127.0.0.1' ||
        h == '::1' ||
        h == '[::1]';
  }

  static bool isPrivateLan(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final octets = parts.map(int.tryParse).toList();
    if (octets.any((o) => o == null || o < 0 || o > 255)) return false;
    final a = octets[0]!, b = octets[1]!;
    return a == 10 ||
        (a == 192 && b == 168) ||
        (a == 172 && b >= 16 && b <= 31);
  }

  /// Uploaded files (product images, logos) come back from the API as
  /// root-relative paths (`/uploads/SKU/a.jpg`); widgets that fetch them
  /// directly need the server address in front. Absolute URLs pass through.
  static String resolveMedia(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (RegExp(r'^(https?:)?//', caseSensitive: false).hasMatch(trimmed) ||
        trimmed.startsWith('data:')) {
      return trimmed;
    }
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    return trimmed.startsWith('/') ? '$base$trimmed' : '$base/$trimmed';
  }
}
