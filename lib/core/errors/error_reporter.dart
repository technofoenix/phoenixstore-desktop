import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../network/api_client.dart';
import '../theme/app_theme.dart';

/// Attached to MaterialApp so errors can be shown from anywhere, including
/// code that has no BuildContext (unawaited futures, print jobs).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// One place for unexpected errors: they are written to a local log file
/// (support can ask the shop for it) and shown to the cashier as one short,
/// translated sentence instead of a crash or a silent failure.
class ErrorReporter {
  static File? _logFile;
  static const _maxLogBytes = 1024 * 1024;

  /// Hooks Flutter's and the platform's uncaught-error handlers. Call once in
  /// `main()` after `WidgetsFlutterBinding.ensureInitialized()`.
  static Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final logs = Directory('${dir.path}${Platform.pathSeparator}logs');
      await logs.create(recursive: true);
      final file = File(
        '${logs.path}${Platform.pathSeparator}phoenixstore.log',
      );
      if (await file.exists() && await file.length() > _maxLogBytes) {
        await file.rename('${file.path}.1');
      }
      _logFile = File(file.path);
    } catch (_) {
      // No writable support dir: keep going without a log file.
    }

    FlutterError.onError = (details) {
      record(details.exception, details.stack, context: 'flutter');
      if (kDebugMode) FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack, context: 'uncaught');
      show(error);
      return true;
    };
  }

  static String? get logPath => _logFile?.path;

  /// Writes the error to the log (and the console in debug builds).
  static void record(Object error, StackTrace? stack, {String? context}) {
    final line =
        '${DateTime.now().toIso8601String()} [${context ?? 'error'}] '
        '$error\n${stack ?? ''}\n';
    if (kDebugMode) debugPrint(line);
    final file = _logFile;
    if (file == null) return;
    unawaited(
      file
          .writeAsString(line, mode: FileMode.append, flush: true)
          .then((_) {}, onError: (Object _) {}),
    );
  }

  /// Shows [error] as a short message at the bottom of the window.
  static void show(Object error, {String? fallback}) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(messageFor(error, fallback: fallback)),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// The sentence to show for [error]: API errors carry their own translated
  /// message; anything else is an unexpected failure.
  static String messageFor(Object error, {String? fallback}) {
    if (error is ApiException || error is DioException) {
      return toApiException(error).message;
    }
    return fallback ?? tr('errors.unexpected');
  }

  /// Runs [action]; on failure records the error, shows a message and returns
  /// null. For fire-and-forget actions such as printing a document.
  static Future<T?> guard<T>(
    Future<T> Function() action, {
    String? fallback,
    String? context,
  }) async {
    try {
      return await action();
    } catch (error, stack) {
      record(error, stack, context: context);
      show(error, fallback: fallback);
      return null;
    }
  }
}
