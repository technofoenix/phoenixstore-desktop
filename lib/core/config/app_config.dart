import 'package:flutter/foundation.dart';

import 'server_config.dart';

/// Runtime configuration for the desktop terminal.
///
/// The API server comes from the env file passed at build time:
/// `flutter run -d macos --dart-define-from-file=.env.development`
/// `flutter build windows --release --dart-define-from-file=.env.production`
/// Remote servers must use https (see [ServerConfig.isAllowed]).
class AppConfig {
  static String get apiBaseUrl => ServerConfig.baseUrl;

  /// Currency code sent to the API (labels on screen come from the
  /// translation files: `common.currency`).
  static const String currency = 'DZD';

  /// Set by `flutter build --build-name`; falls back to pubspec's version.
  static const String version = String.fromEnvironment(
    'FLUTTER_BUILD_NAME',
    defaultValue: '1.0.0',
  );

  static bool get isDebug => kDebugMode;
}
