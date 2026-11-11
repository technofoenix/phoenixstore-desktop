import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoenixstore_desktop/core/network/api_client.dart';

DioException _http(int status, Map<String, dynamic> body) {
  final request = RequestOptions(
    path: '/api/v1/desktop/orders',
    method: 'POST',
  );
  return DioException(
    requestOptions: request,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: request, statusCode: status, data: body),
  );
}

/// Loads the real English file into easy_localization's singleton so the
/// messages are checked exactly as a cashier would read them.
void _loadEnglish() {
  final map = Map<String, dynamic>.from(
    jsonDecode(File('lib/locale/en.json').readAsStringSync()) as Map,
  );
  Localization.load(const Locale('en'), translations: Translations(map));
}

void main() {
  setUpAll(_loadEnglish);

  test('known API codes are translated with their details', () {
    final e = toApiException(
      _http(400, {
        'message': 'Insufficient stock in backoffice for this article',
        'code': 'INSUFFICIENT_STOCK',
        'errors': {
          'code': 'INSUFFICIENT_STOCK',
          'available': 2,
          'requested': 5,
        },
      }),
    );
    expect(e.code, 'INSUFFICIENT_STOCK');
    expect(
      e.message,
      startsWith('Not enough stock: 2 available, 5 requested.'),
    );
  });

  test('server errors never show the raw server text', () {
    final e = toApiException(
      _http(500, {'message': 'PrismaClientKnownRequestError: column x'}),
    );
    expect(e.message, isNot(contains('Prisma')));
    expect(e.message, startsWith('The server had a problem'));
  });

  test('validation errors list their fields', () {
    final e = toApiException(
      _http(400, {
        'message': 'Validation error',
        'errors': [
          {'field': 'items.0.quantity', 'message': 'Too small'},
        ],
      }),
    );
    expect(e.message, contains('items.0.quantity: Too small'));
  });

  test('network failures get the network sentence', () {
    final e = toApiException(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionTimeout,
        error: const SocketException('timeout'),
      ),
    );
    expect(e.statusCode, isNull);
    expect(e.message, startsWith('The server did not answer'));
  });

  test('non-HTTP errors become a generic message', () {
    final e = toApiException(StateError('boom'));
    expect(e.message, isNot(contains('boom')));
  });
}
