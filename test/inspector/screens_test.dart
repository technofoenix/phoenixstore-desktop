// UI inspector: renders every screen and dialog of the desktop terminal at
// several window sizes and in every language, records layout errors
// (RenderFlex overflow, exceptions), the text direction, and saves a PNG.
//
//   flutter test test/inspector --dart-define=SHOTS=docs/redesign/after
//   flutter test test/inspector --dart-define=SHOTS=docs/redesign/after --dart-define=STRICT=true
//
// With STRICT=true any layout error fails the test (used after the redesign).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:phoenixstore_desktop/core/models/models.dart';
import 'package:phoenixstore_desktop/core/network/session_events.dart';
import 'package:phoenixstore_desktop/core/storage/session_store.dart';
import 'package:phoenixstore_desktop/features/api/desktop_api.dart';
import 'package:phoenixstore_desktop/features/auth/auth_controller.dart';
import 'package:phoenixstore_desktop/features/sales/cart_controller.dart';
import 'package:phoenixstore_desktop/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

const shotsDir = String.fromEnvironment('SHOTS', defaultValue: '');
const strict = bool.fromEnvironment('STRICT');
const onlyLocales = String.fromEnvironment('LOCALES', defaultValue: 'ar,fr,en');
const onlySizes = String.fromEnvironment(
  'SIZES',
  defaultValue: '1440x900,1280x800,1024x768,900x640',
);
const onlyScenario = String.fromEnvironment('SCENARIO', defaultValue: '');

const _user = SessionUser(
  id: 'u1',
  fullName: 'Amina Haddad',
  email: 'amina@boutique.example',
  role: 'CLIENT',
  phoneNumber: '0551234567',
  mobilePermissions: [],
  desktopPermissions: [],
  mustChangePassword: false,
);

enum AuthMode { signedIn, signedOut, mustChange, booting }

class _FakeAuth extends AuthController {
  _FakeAuth(this.mode);
  final AuthMode mode;

  @override
  Future<SessionUser?> build() {
    switch (mode) {
      case AuthMode.signedIn:
        return Future.value(_user);
      case AuthMode.signedOut:
        return Future.value(null);
      case AuthMode.mustChange:
        return Future.value(
          const SessionUser(
            id: 'u1',
            fullName: 'Amina Haddad',
            email: 'amina@boutique.example',
            role: 'CLIENT',
            phoneNumber: '0551234567',
            mobilePermissions: [],
            desktopPermissions: [],
            mustChangePassword: true,
          ),
        );
      case AuthMode.booting:
        return Completer<SessionUser?>().future;
    }
  }
}

class _Blocked extends AccountBlockedNotifier {
  @override
  String? build() => 'Your boutique account was suspended by the wholesaler.';
}

class _MemoryStorage implements SessionStorage {
  final data = <String, String>{};
  @override
  Future<void> delete(String key) async => data.remove(key);
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

/// A tab is opened by its key (redesign) or its old English label.
const _tabs = [
  'Sell',
  'Sales',
  'Clients',
  'Stock',
  'Orders',
  'Charges',
  'Settings',
];

class Scenario {
  const Scenario(
    this.name, {
    this.auth = AuthMode.signedIn,
    this.mode = DataMode.loaded,
    this.tab,
    this.blocked = false,
    this.failContext = false,
    this.act,
  });

  final String name;
  final AuthMode auth;
  final DataMode mode;
  final int? tab;
  final bool blocked;
  final bool failContext;
  final Future<void> Function(WidgetTester tester)? act;
}

Future<bool> _tapFirst(WidgetTester tester, List<Finder> finders) async {
  for (final finder in finders) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder.first);
      await tester.tap(finder.first, warnIfMissed: false);
      await _settle(tester);
      return true;
    }
  }
  return false;
}

Future<void> _settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _addToTicket(WidgetTester tester) async {
  await _tapFirst(tester, [
    find.byKey(const ValueKey('product-p1')),
    find.text('Huile Elio 1L'),
  ]);
  await _tapFirst(tester, [
    find.byKey(const ValueKey('product-p2')),
    find.text('Semoule extra Safina 5kg'),
  ]);
}

final scenarios = <Scenario>[
  const Scenario('boot', auth: AuthMode.booting),
  const Scenario('login', auth: AuthMode.signedOut),
  Scenario(
    'login_error',
    auth: AuthMode.signedOut,
    act: (tester) async {
      await _tapFirst(tester, [
        find.byKey(const ValueKey('login.submit')),
        find.widgetWithText(FilledButton, 'Sign in'),
      ]);
    },
  ),
  const Scenario('change_password', auth: AuthMode.mustChange),
  const Scenario('account_blocked', blocked: true),
  const Scenario('shell_error', failContext: true),
  for (final (tab, name) in [
    (0, 'sell'),
    (1, 'history'),
    (2, 'clients'),
    (3, 'stock'),
    (4, 'orders'),
    (5, 'charges'),
  ]) ...[
    Scenario('${name}_loaded', tab: tab),
    Scenario('${name}_empty', tab: tab, mode: DataMode.empty),
    Scenario('${name}_error', tab: tab, mode: DataMode.error),
    Scenario('${name}_loading', tab: tab, mode: DataMode.loading),
  ],
  Scenario('sell_ticket', tab: 0, act: _addToTicket),
  Scenario(
    'sell_credit',
    tab: 0,
    act: (tester) async {
      await _addToTicket(tester);
      final opened = await _tapFirst(tester, [
        find.byKey(const ValueKey('pay-CREDIT')),
      ]);
      if (!opened) {
        // Before the redesign payment was a dropdown.
        await _tapFirst(tester, [find.text('Cash')]);
        await _tapFirst(tester, [find.text('Credit').last]);
      }
    },
  ),
  Scenario(
    'dialog_sale_completed',
    tab: 0,
    act: (tester) async {
      await _addToTicket(tester);
      await _tapFirst(tester, [
        find.byKey(const ValueKey('sell.complete')),
        find.text('Complete sale'),
      ]);
    },
  ),
  Scenario(
    'dialog_record_payment',
    tab: 1,
    act: (tester) async {
      await _tapFirst(tester, [
        find.byKey(const ValueKey('history.pay-s2')),
        find.byTooltip('Record versement'),
      ]);
    },
  ),
  Scenario(
    'dialog_new_order',
    tab: 4,
    act: (tester) async {
      await _tapFirst(tester, [
        find.byKey(const ValueKey('orders.new')),
        find.text('New order'),
      ]);
      await _tapFirst(tester, [
        find.byKey(const ValueKey('order-add-p1')),
        find.text('Huile Elio 1L'),
      ]);
    },
  ),
  Scenario(
    'dialog_record_charge',
    tab: 5,
    act: (tester) async {
      await _tapFirst(tester, [
        find.byKey(const ValueKey('charges.new')),
        find.text('Record charge'),
      ]);
    },
  ),
  const Scenario('settings', tab: 6),
  Scenario(
    'sell_qty_typed',
    tab: 0,
    act: (tester) async {
      await _addToTicket(tester);
      final field = find.byKey(const ValueKey('qty-field-p1'));
      await tester.enterText(field, '7');
      await _settle(tester);
    },
  ),
  Scenario(
    'dialog_sale_details',
    tab: 1,
    act: (tester) async {
      await _tapFirst(tester, [find.byKey(const ValueKey('sale-row-s2'))]);
    },
  ),
  Scenario(
    'dialog_order_details',
    tab: 4,
    act: (tester) async {
      await _tapFirst(tester, [find.byKey(const ValueKey('order-row-o1'))]);
    },
  ),
  Scenario(
    'dialog_client_details',
    tab: 2,
    act: (tester) async {
      await _tapFirst(tester, [
        find.byKey(const ValueKey('client-row-Karim Benali')),
      ]);
    },
  ),
  Scenario(
    'dialog_new_order_qty',
    tab: 4,
    act: (tester) async {
      await _tapFirst(tester, [find.byKey(const ValueKey('orders.new'))]);
      await _tapFirst(tester, [find.byKey(const ValueKey('order-add-p1'))]);
      await tester.enterText(
        find.byKey(const ValueKey('order-qty-field-p1')),
        '48',
      );
      await _settle(tester);
    },
  ),
  Scenario(
    'stock_filtered',
    tab: 3,
    act: (tester) async {
      await _tapFirst(tester, [find.byKey(const ValueKey('stock.family'))]);
      await _tapFirst(tester, [find.text('Boissons').last]);
      await _tapFirst(tester, [find.byKey(const ValueKey('stock.category'))]);
      await _tapFirst(tester, [find.text('Jus').last]);
    },
  ),
];

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    var any = false;
    for (final path in files) {
      final file = File(path);
      if (!file.existsSync()) continue;
      any = true;
      final bytes = file.readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    if (any) await loader.load();
  }

  final fontDir = Directory('assets/fonts');
  final fontFiles = fontDir.existsSync()
      ? fontDir.listSync().whereType<File>().map((f) => f.path).toList()
      : <String>[];
  await load('Inter', fontFiles.where((f) => f.contains('Inter-')).toList());
  await load(
    'IBMPlexSansArabic',
    fontFiles.where((f) => f.contains('IBMPlexSansArabic-')).toList(),
  );
  final material = '$flutterRoot/bin/cache/artifacts/material_fonts';
  await load('MaterialIcons', ['$material/MaterialIcons-Regular.otf']);
  await load('Roboto', [
    '$material/Roboto-Regular.ttf',
    '$material/Roboto-Medium.ttf',
    '$material/Roboto-Bold.ttf',
  ]);
}

final results = <Map<String, Object?>>[];
late SharedPreferences prefs;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableBuildModes = [];
    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting();
    prefs = await SharedPreferences.getInstance();
    await _loadFonts();
  });

  tearDownAll(() {
    if (shotsDir.isEmpty) return;
    Directory(shotsDir).createSync(recursive: true);
    File(
      '$shotsDir/report.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
  });

  final locales = onlyLocales.split(',');
  final sizes = onlySizes.split(',').map((s) {
    final parts = s.split('x');
    return Size(double.parse(parts[0]), double.parse(parts[1]));
  });

  for (final scenario in scenarios) {
    if (onlyScenario.isNotEmpty &&
        !onlyScenario.split(',').contains(scenario.name)) {
      continue;
    }
    for (final locale in locales) {
      for (final size in sizes) {
        final id =
            '${scenario.name}_${locale}_${size.width.toInt()}x${size.height.toInt()}';
        testWidgets(id, (tester) async {
          await prefs.clear();
          final errors = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) {
            final text = details.exceptionAsString().split('\n').first;
            if (const bool.fromEnvironment('VERBOSE')) {
              debugPrint(details.toString());
            }
            errors.add(text);
          };

          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final boundary = GlobalKey();
          final app = RepaintBoundary(
            key: boundary,
            child: EasyLocalization(
              supportedLocales: const [
                Locale('ar'),
                Locale('fr'),
                Locale('en'),
              ],
              path: 'lib/locale',
              fallbackLocale: const Locale('en'),
              startLocale: Locale(locale),
              saveLocale: false,
              useOnlyLangCode: true,
              child: ProviderScope(
                overrides: [
                  sharedPrefsProvider.overrideWithValue(prefs),
                  desktopApiProvider.overrideWithValue(
                    FakeDesktopApi(
                      mode: scenario.mode,
                      failContext: scenario.failContext,
                    ),
                  ),
                  authControllerProvider.overrideWith(
                    () => _FakeAuth(scenario.auth),
                  ),
                  sessionStoreProvider.overrideWithValue(
                    SessionStore(_MemoryStorage()),
                  ),
                  if (scenario.blocked)
                    accountBlockedProvider.overrideWith(_Blocked.new),
                ],
                child: const PhoenixStoreDesktopApp(),
              ),
            ),
          );

          await tester.runAsync(() async {
            await tester.pumpWidget(app);
            await Future<void>.delayed(const Duration(milliseconds: 200));
          });
          await _settle(tester);

          var reached = true;
          final tab = scenario.tab;
          if (tab != null && tab > 0) {
            reached = await _tapFirst(tester, [
              find.byKey(ValueKey('nav-$tab')),
              find.text(_tabs[tab]),
            ]);
          }
          if (reached && scenario.act != null) {
            await scenario.act!(tester);
          }
          await _settle(tester);

          final exception = tester.takeException();
          if (exception != null) {
            errors.add('$exception'.split('\n').first);
          }

          final direction = Directionality.maybeOf(
            tester.element(find.byType(Scaffold).first),
          );

          if (shotsDir.isNotEmpty) {
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory(shotsDir)..createSync(recursive: true);
              File(
                '${dir.path}/$id.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
            });
          }

          results.add({
            'id': id,
            'scenario': scenario.name,
            'locale': locale,
            'size': '${size.width.toInt()}x${size.height.toInt()}',
            'reached': reached,
            'direction': direction?.name,
            'errors': errors,
          });

          FlutterError.onError = previous;
          // Unmount so pending timers of this screen do not leak.
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));

          if (strict) {
            expect(reached, isTrue, reason: 'scenario could not be reached');
            expect(errors, isEmpty, reason: errors.join('\n'));
            if (locale == 'ar') {
              expect(direction, TextDirection.rtl);
            } else {
              expect(direction, TextDirection.ltr);
            }
          }
        });
      }
    }
  }
}
