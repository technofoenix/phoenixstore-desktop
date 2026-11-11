// The language picked in Settings applies at once (text and direction) and
// is still active after the app restarts.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:phoenixstore_desktop/core/i18n/languages.dart';
import 'package:phoenixstore_desktop/core/models/models.dart';
import 'package:phoenixstore_desktop/core/storage/session_store.dart';
import 'package:phoenixstore_desktop/features/api/desktop_api.dart';
import 'package:phoenixstore_desktop/features/auth/auth_controller.dart';
import 'package:phoenixstore_desktop/features/sales/cart_controller.dart';
import 'package:phoenixstore_desktop/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'inspector/fake_api.dart';

class _SignedIn extends AuthController {
  @override
  Future<SessionUser?> build() async => const SessionUser(
    id: 'u1',
    fullName: 'Amina Haddad',
    email: 'amina@boutique.example',
    role: 'CLIENT',
    phoneNumber: '0551234567',
    mobilePermissions: [],
    desktopPermissions: [],
    mustChangePassword: false,
  );
}

class _Memory implements SessionStorage {
  final data = <String, String>{};
  @override
  Future<void> delete(String key) async => data.remove(key);
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

/// Boots the app the way `main()` does (saved language first).
Future<void> _boot(WidgetTester tester) async {
  await tester.runAsync(() async {
    await EasyLocalization.ensureInitialized();
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: AppLanguages.locales,
        path: AppLanguages.translationsPath,
        fallbackLocale: const Locale(AppLanguages.fallbackCode),
        startLocale: const Locale('fr'),
        useOnlyLangCode: true,
        saveLocale: true,
        child: ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
            desktopApiProvider.overrideWithValue(FakeDesktopApi()),
            authControllerProvider.overrideWith(_SignedIn.new),
            sessionStoreProvider.overrideWithValue(SessionStore(_Memory())),
          ],
          child: const PhoenixStoreDesktopApp(),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

TextDirection _direction(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(Scaffold).first));

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting();
  });

  testWidgets('Settings switches language at once and keeps it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _boot(tester);
    expect(find.text('Caisse'), findsWidgets);
    expect(_direction(tester), TextDirection.ltr);

    await tester.tap(find.byKey(const ValueKey('nav-6')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Paramètres'), findsWidgets);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('lang-ar')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Applied instantly, without a restart.
    expect(find.text('الإعدادات'), findsWidgets);
    expect(_direction(tester), TextDirection.rtl);

    // Stored on disk.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locale'), contains('ar'));

    // "Restart": a fresh tree reads the saved language.
    await tester.pumpWidget(const SizedBox());
    await _boot(tester);
    expect(find.text('الصندوق'), findsWidgets);
    expect(_direction(tester), TextDirection.rtl);
  });
}
