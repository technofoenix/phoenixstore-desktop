import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Minimal storage contract so the session logic can be unit tested without
/// the platform keychain.
abstract class SessionStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// macOS data-protection keychain access requires a keychain-access-group
/// entitlement (and therefore a provisioning profile). Desktop builds are
/// distributed ad-hoc, so use the legacy keychain instead. Without this,
/// every secure-storage call fails with OSStatus -34018.
FlutterSecureStorage createSecureStorage() {
  if (Platform.isMacOS) {
    return const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    );
  }
  return const FlutterSecureStorage();
}

class SecureSessionStorage implements SessionStorage {
  const SecureSessionStorage(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class SessionTokens {
  const SessionTokens({
    required this.accessToken,
    required this.refreshToken,
    this.tenantId,
    this.warehouseId,
  });

  final String accessToken;
  final String refreshToken;
  final String? tenantId;
  final String? warehouseId;

  SessionTokens copyWith({String? warehouseId}) => SessionTokens(
    accessToken: accessToken,
    refreshToken: refreshToken,
    tenantId: tenantId,
    warehouseId: warehouseId ?? this.warehouseId,
  );
}

/// Persists the desktop session. The access token is long-lived (see API), and
/// remembering the last boutique keeps the terminal on the same till.
///
/// If the OS keychain is unavailable the store degrades to memory instead of
/// throwing, so a broken keychain can never block the terminal from starting.
class SessionStore {
  SessionStore(this._storage);

  final SessionStorage _storage;
  final Map<String, String> _memory = {};
  bool _useMemory = false;

  bool get usingMemoryFallback => _useMemory;

  static const _kAccess = 'desktop.ACCESS_TOKEN';
  static const _kRefresh = 'desktop.REFRESH_TOKEN';
  static const _kTenant = 'desktop.TENANT_ID';
  static const _kWarehouse = 'desktop.WAREHOUSE_ID';
  static const _kDevice = 'desktop.DEVICE_ID';

  Future<String?> _read(String key) async {
    if (_useMemory) return _memory[key];
    try {
      return await _storage.read(key);
    } catch (_) {
      _useMemory = true;
      return _memory[key];
    }
  }

  Future<void> _write(String key, String value) async {
    if (_useMemory) {
      _memory[key] = value;
      return;
    }
    try {
      await _storage.write(key, value);
    } catch (_) {
      _useMemory = true;
      _memory[key] = value;
    }
  }

  Future<void> _delete(String key) async {
    if (_useMemory) {
      _memory.remove(key);
      return;
    }
    try {
      await _storage.delete(key);
    } catch (_) {
      _useMemory = true;
      _memory.remove(key);
    }
  }

  /// Stable id of this installation, sent with every sale so the API can tell
  /// tills apart. Created on first use and kept across sign-outs.
  Future<String> deviceId() async {
    final existing = await _read(_kDevice);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = 'desktop-${const Uuid().v4()}';
    await _write(_kDevice, created);
    return created;
  }

  Future<SessionTokens?> read() async {
    final access = await _read(_kAccess);
    final refresh = await _read(_kRefresh);
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      return null;
    }
    return SessionTokens(
      accessToken: access,
      refreshToken: refresh,
      tenantId: await _read(_kTenant),
      warehouseId: await _read(_kWarehouse),
    );
  }

  Future<void> write(SessionTokens tokens) async {
    await _write(_kAccess, tokens.accessToken);
    await _write(_kRefresh, tokens.refreshToken);
    final tenantId = tokens.tenantId;
    if (tenantId != null) await _write(_kTenant, tenantId);
    final warehouseId = tokens.warehouseId;
    if (warehouseId != null) await _write(_kWarehouse, warehouseId);
  }

  Future<void> saveWarehouse(String warehouseId) =>
      _write(_kWarehouse, warehouseId);

  Future<void> clear() async {
    await _delete(_kAccess);
    await _delete(_kRefresh);
    await _delete(_kTenant);
    await _delete(_kWarehouse);
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => createSecureStorage(),
);

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SessionStore(SecureSessionStorage(ref.watch(secureStorageProvider))),
);
