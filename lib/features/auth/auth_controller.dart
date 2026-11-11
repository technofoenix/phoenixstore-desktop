import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/session_events.dart';
import '../../core/storage/session_store.dart';
import '../sales/cart_controller.dart';

class AuthController extends AsyncNotifier<SessionUser?> {
  Dio get _dio => ref.read(dioProvider);
  SessionStore get _store => ref.read(sessionStoreProvider);

  @override
  Future<SessionUser?> build() async {
    // The API client clears the stored session when the refresh token is
    // rejected; go back to the login screen.
    ref.listen(sessionExpiredProvider, (_, _) => state = const AsyncData(null));
    final tokens = await _store.read();
    if (tokens == null) return null;
    try {
      return await _loadMe();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _store.clear();
        return null;
      }
      rethrow;
    }
  }

  Future<SessionUser> _loadMe() async {
    final response = await _dio.get('/api/v1/auth/me');
    return SessionUser.fromMe(
      Map<String, dynamic>.from((response.data as Map)['data'] as Map),
    );
  }

  Future<void> login({
    required String phoneNumber,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await _dio.post(
        '/api/v1/users/login',
        data: {'phoneNumber': phoneNumber, 'password': password},
      );
      final data = Map<String, dynamic>.from(
        (response.data as Map)['data'] as Map,
      );
      final tokens = Map<String, dynamic>.from(data['tokens'] as Map);
      await _store.write(
        SessionTokens(
          accessToken: tokens['accessToken'] as String,
          refreshToken: tokens['refreshToken'] as String,
          tenantId: tokens['tenantId'] as String?,
        ),
      );
      return _loadMe();
    });
  }

  Future<void> changePassword(String password) async {
    final response = await _dio.post(
      '/api/v1/auth/force-change-password',
      data: {'password': password},
    );
    if (response.statusCode != 200) {
      throw ApiException(tr('errors.changePasswordFailed'));
    }
    state = await AsyncValue.guard(_loadMe);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_loadMe);
  }

  Future<void> logout() async {
    await _store.clear();
    // An open ticket belongs to the cashier who built it.
    await clearSavedCarts(ref.read(sharedPrefsProvider));
    ref.invalidate(cartProvider);
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, SessionUser?>(AuthController.new);
