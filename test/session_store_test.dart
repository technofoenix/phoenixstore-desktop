import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoenixstore_desktop/core/storage/session_store.dart';

class _MemoryStorage implements SessionStorage {
  final Map<String, String> data = {};
  bool fail = false;

  void _throwIfNeeded() {
    if (fail) throw StateError('keychain unavailable');
  }

  @override
  Future<String?> read(String key) async {
    _throwIfNeeded();
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _throwIfNeeded();
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _throwIfNeeded();
    data.remove(key);
  }
}

void main() {
  test('macOS uses the legacy keychain (avoids entitlement -34018)', () {
    if (!Platform.isMacOS) return;
    final storage = createSecureStorage();
    expect(storage.mOptions, isA<MacOsOptions>());
    expect(
      (storage.mOptions as MacOsOptions).usesDataProtectionKeychain,
      isFalse,
    );
  });

  test(
    'session round-trips tokens, tenant, warehouse; device id survives sign-out',
    () async {
      final backing = _MemoryStorage();
      final store = SessionStore(backing);

      final device = await store.deviceId();
      expect(device, startsWith('desktop-'));
      await store.write(
        const SessionTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          tenantId: 'tenant',
          warehouseId: 'warehouse',
        ),
      );

      final tokens = await store.read();
      expect(tokens?.accessToken, 'access');
      expect(tokens?.refreshToken, 'refresh');
      expect(tokens?.tenantId, 'tenant');
      expect(tokens?.warehouseId, 'warehouse');
      expect(await store.deviceId(), device);
      expect(store.usingMemoryFallback, isFalse);

      await store.clear();
      expect(await store.read(), isNull);
      expect(await store.deviceId(), device);
    },
  );

  test('incomplete tokens are treated as signed out', () async {
    final backing = _MemoryStorage();
    backing.data['desktop.ACCESS_TOKEN'] = 'access';
    final store = SessionStore(backing);

    expect(await store.read(), isNull);
  });

  test('falls back to memory when the keychain throws', () async {
    final backing = _MemoryStorage()..fail = true;
    final store = SessionStore(backing);

    await expectLater(
      store.write(
        const SessionTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          warehouseId: 'warehouse',
        ),
      ),
      completes,
    );
    final device = await store.deviceId();

    final tokens = await store.read();
    expect(tokens?.accessToken, 'access');
    expect(tokens?.warehouseId, 'warehouse');
    expect(await store.deviceId(), device);
    expect(store.usingMemoryFallback, isTrue);

    await store.clear();
    expect(await store.read(), isNull);
  });
}
