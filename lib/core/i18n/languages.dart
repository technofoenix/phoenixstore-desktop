import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One entry of `lib/locale/languages.json`.
///
/// The manifest is the single list of languages the terminal offers. Adding a
/// language means adding `lib/locale/<code>.json` and one entry here; no Dart
/// code changes (see README, "Languages").
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.name,
    required this.rtl,
    required this.font,
  });

  final String code;

  /// The language's own name, shown in its own script in the switcher.
  final String name;
  final bool rtl;
  final String font;

  Locale get locale => Locale(code);

  factory AppLanguage.fromJson(Map<String, dynamic> json) => AppLanguage(
    code: json['code'] as String,
    name: json['name'] as String? ?? json['code'] as String,
    rtl: json['dir'] == 'rtl',
    font: json['font'] as String? ?? AppLanguages.defaultFont,
  );
}

class AppLanguages {
  static const manifestPath = 'lib/locale/languages.json';
  static const translationsPath = 'lib/locale';
  static const defaultFont = 'Inter';

  /// Used when the device language is not offered.
  static const preferredCode = 'fr';
  static const fallbackCode = 'en';

  static List<AppLanguage> _all = const [
    AppLanguage(
      code: 'ar',
      name: 'العربية',
      rtl: true,
      font: 'IBMPlexSansArabic',
    ),
    AppLanguage(code: 'fr', name: 'Français', rtl: false, font: 'Inter'),
    AppLanguage(code: 'en', name: 'English', rtl: false, font: 'Inter'),
  ];

  static List<AppLanguage> get all => _all;

  static List<Locale> get locales => _all.map((l) => l.locale).toList();

  static Future<void> load([AssetBundle? bundle]) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString(manifestPath);
      final list = (jsonDecode(raw) as List)
          .map((e) => AppLanguage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (list.isNotEmpty) _all = list;
    } catch (_) {
      // Keep the built-in list; the app must always start.
    }
  }

  static AppLanguage of(Locale locale) => _all.firstWhere(
    (l) => l.code == locale.languageCode,
    orElse: () => _all.firstWhere(
      (l) => l.code == fallbackCode,
      orElse: () => _all.first,
    ),
  );

  /// The device language when offered, otherwise [preferredCode].
  static Locale startLocale(Locale device) {
    final match = _all.where((l) => l.code == device.languageCode);
    if (match.isNotEmpty) return match.first.locale;
    return Locale(preferredCode);
  }

  /// Fonts used as fallback so mixed text (a French product name inside an
  /// Arabic screen) always has glyphs.
  static List<String> fallbackFonts(String primary) =>
      {for (final l in _all) l.font}.where((f) => f != primary).toList();
}
