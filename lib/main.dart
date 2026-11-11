import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/errors/error_reporter.dart';
import 'core/i18n/formatters.dart';
import 'core/i18n/languages.dart';
import 'core/network/session_events.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/ui.dart';
import 'features/auth/account_blocked_screen.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/change_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/documents/document_service.dart';
import 'features/sales/cart_controller.dart';
import 'features/shell/desktop_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ErrorReporter.init();
  EasyLocalization.logger.enableBuildModes = [];
  await EasyLocalization.ensureInitialized();
  await AppLanguages.load();
  await Fmt.init();
  await DocumentStrings.load();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    EasyLocalization(
      supportedLocales: AppLanguages.locales,
      path: AppLanguages.translationsPath,
      fallbackLocale: const Locale(AppLanguages.fallbackCode),
      startLocale: AppLanguages.startLocale(
        ui.PlatformDispatcher.instance.locale,
      ),
      useOnlyLangCode: true,
      // The chosen language is stored on disk and restored at the next start.
      saveLocale: true,
      child: ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const PhoenixStoreDesktopApp(),
      ),
    ),
  );
}

class PhoenixStoreDesktopApp extends StatelessWidget {
  const PhoenixStoreDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    final language = AppLanguages.of(context.locale);
    return MaterialApp(
      onGenerateTitle: (context) => context.tr('app.name'),
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.build(language),
      themeMode: ThemeMode.light,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedMessage = ref.watch(accountBlockedProvider);
    if (blockedMessage != null) {
      return AccountBlockedScreen(message: blockedMessage);
    }

    final auth = ref.watch(authControllerProvider);

    return auth.when(
      loading: () => const BootScreen(),
      error: (_, _) => const LoginScreen(),
      data: (user) {
        if (user == null) return const LoginScreen();
        if (user.mustChangePassword) return const ChangePasswordScreen();
        return const DesktopShell();
      },
    );
  }
}

class BootScreen extends StatelessWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: AppColors.line),
              ),
              child: Image.asset('assets/logos/logo-pos.png'),
            ),
            const SizedBox(height: Space.lg),
            Text(context.tr('app.starting'), style: text.titleMedium),
            const SizedBox(height: Space.md),
            const SizedBox(width: 160, child: Skeleton(height: 6)),
          ],
        ),
      ),
    );
  }
}
