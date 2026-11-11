import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/server_config.dart';
import '../storage/session_store.dart';
import 'session_events.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Code of the error raised when the server URL is plain HTTP to a remote host.
const insecureServerCode = 'INSECURE_SERVER';

/// Turns any error from a request into one sentence a cashier can act on.
///
/// Order of preference:
///  1. a translation for the API's machine code (`errors.code.<CODE>`), so
///     the message follows the terminal's language;
///  2. field messages of a validation error;
///  3. the API's own message for 4xx errors;
///  4. a generic translated sentence for network failures and 5xx.
/// The method/URL/status line is only added in debug builds.
ApiException toApiException(Object error) {
  if (error is ApiException) return error;
  if (error is DioException && error.error is ApiException) {
    return error.error as ApiException;
  }
  if (error is! DioException) {
    return ApiException(tr('errors.unexpected'));
  }

  final data = error.response?.data;
  final body = data is Map ? data : const {};
  final status = error.response?.statusCode;
  final code = body['code'] is String ? body['code'] as String : null;
  final details = body['errors'];

  String message;
  if (status == null) {
    message = _networkMessage(error);
  } else if (code != null && trExists('errors.code.$code')) {
    message = tr('errors.code.$code', namedArgs: _namedArgs(details));
  } else if (details is List && details.isNotEmpty) {
    message = details
        .whereType<Map>()
        .map((e) => '${e['field'] ?? ''}: ${e['message'] ?? ''}')
        .join('\n');
    message = '${tr('errors.validation')}\n$message';
  } else if (status >= 500) {
    message = tr('errors.server');
  } else if (status == 401) {
    message = tr('errors.sessionExpired');
  } else if (status == 403) {
    message = body['message'] is String
        ? body['message'] as String
        : tr('errors.forbidden');
  } else if (status == 404) {
    message =
        '${body['message'] is String ? body['message'] : tr('errors.notFound')}'
        '\n${tr('errors.notFoundHint')}';
  } else {
    message = body['message'] is String
        ? body['message'] as String
        : tr('errors.unexpected');
  }

  if (kDebugMode && status != null) {
    final request = error.requestOptions;
    message +=
        '\n${tr('errors.httpStatus', namedArgs: {'method': request.method, 'url': '${request.uri}', 'status': '$status'})}';
  }
  return ApiException(message, code: code, statusCode: status);
}

/// Values the API puts in `errors` (e.g. available/requested for
/// INSUFFICIENT_STOCK), usable as {placeholders} in translations.
Map<String, String> _namedArgs(Object? details) {
  if (details is! Map) return const {};
  return {
    for (final entry in details.entries)
      if (entry.value is num || entry.value is String)
        '${entry.key}': '${entry.value}',
  };
}

/// Connection failures carry Dio's English text; show our own sentence.
String _networkMessage(DioException error) => switch (error.type) {
  DioExceptionType.badCertificate => tr('errors.badCertificate'),
  _ => tr('errors.network'),
};

const _connectTimeout = Duration(seconds: 15);
const _receiveTimeout = Duration(seconds: 20);

final dioProvider = Provider<Dio>((ref) {
  final store = ref.watch(sessionStoreProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: ServerConfig.baseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ),
  );

  Future<String?>? refreshing;

  Future<String?> refreshToken() async {
    final tokens = await store.read();
    if (tokens == null) return null;
    if (!ServerConfig.isConfigured) return null;
    final bare = Dio(
      BaseOptions(
        baseUrl: ServerConfig.baseUrl,
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
      ),
    );
    try {
      final response = await bare.post(
        '/api/v1/users/refresh',
        data: {'refreshToken': tokens.refreshToken},
      );
      final data = (response.data as Map)['data'] as Map;
      final next = Map<String, dynamic>.from(data['tokens'] as Map);
      final access = next['accessToken'] as String?;
      final refresh = next['refreshToken'] as String?;
      if (access == null || access.isEmpty) return null;
      await store.write(
        SessionTokens(
          accessToken: access,
          refreshToken: refresh ?? tokens.refreshToken,
          tenantId: tokens.tenantId,
          warehouseId: tokens.warehouseId,
        ),
      );
      return access;
    } on DioException catch (e) {
      // The server refused the refresh token: the session is over.
      final status = e.response?.statusCode;
      if (status != null && status >= 400 && status < 500) return null;
      // Network down or server error: keep the session, fail this request.
      rethrow;
    }
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.baseUrl = ServerConfig.baseUrl;
        // Never send credentials or the bearer token over plain HTTP to a
        // remote host (or anywhere, when no server is configured).
        if (!ServerConfig.isConfigured) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
              error: ApiException(
                tr('errors.insecureServer'),
                code: insecureServerCode,
              ),
            ),
          );
          return;
        }
        final tokens = await store.read();
        if (tokens != null) {
          options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final path = error.requestOptions.path;
        final isAuthCall =
            path.contains('/users/login') || path.contains('/users/refresh');
        final data = error.response?.data;
        final code = data is Map && data['code'] is String
            ? data['code'] as String
            : null;

        if (!isAuthCall &&
            error.response?.statusCode == 403 &&
            const {
              'ACCOUNT_DISABLED',
              'ACCOUNT_INACTIVE',
              'ACCOUNT_PENDING',
            }.contains(code)) {
          await store.clear();
          final message = data is Map && data['message'] is String
              ? data['message'] as String
              : tr('errors.accountInactive');
          ref.read(accountBlockedProvider.notifier).block(message);
          handler.next(error);
          return;
        }

        if (error.response?.statusCode != 401 || isAuthCall) {
          handler.next(error);
          return;
        }
        // All requests that fail together share one refresh call.
        final pending = refreshing ??= refreshToken().whenComplete(
          () => refreshing = null,
        );
        final String? access;
        try {
          access = await pending;
        } catch (_) {
          handler.next(error);
          return;
        }
        if (access == null) {
          // Refresh token rejected or expired: sign out instead of letting
          // every later request fail with 401.
          if (await store.read() != null) {
            await store.clear();
            ref.read(sessionExpiredProvider.notifier).expire();
          }
          handler.next(error);
          return;
        }
        final options = error.requestOptions;
        options.headers['Authorization'] = 'Bearer $access';
        try {
          final retry = await dio.fetch(options);
          handler.resolve(retry);
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      },
    ),
  );

  return dio;
});
