import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Locale-aware numbers, money and dates. Arabic uses the Algerian locale,
/// which writes Western digits (0-9) like receipts and barcodes do.
class Fmt {
  Fmt._();

  static Future<void> init() => initializeDateFormatting();

  static String intlLocale(BuildContext context) =>
      intlLocaleFor(context.locale.languageCode);

  static String intlLocaleFor(String code) => switch (code) {
    'ar' => 'ar_DZ',
    _ => code,
  };

  /// `1 234,50` (fr), `1,234.50` (en), `1.234,50` (ar).
  static String number(BuildContext context, num value, {int decimals = 2}) {
    final pattern = decimals == 0 ? '#,##0' : '#,##0.${'0' * decimals}';
    return _clean(NumberFormat(pattern, intlLocale(context)).format(value));
  }

  /// Amount followed by the local currency label (DA, DZD, د.ج).
  static String money(BuildContext context, num value) =>
      '${number(context, value)} ${context.tr('common.currency')}';

  static String integer(BuildContext context, num value) =>
      number(context, value, decimals: 0);

  static String date(BuildContext context, DateTime value) =>
      DateFormat('dd/MM/yyyy', intlLocale(context)).format(value);

  static String dateTime(BuildContext context, DateTime value) =>
      DateFormat('dd/MM/yyyy · HH:mm', intlLocale(context)).format(value);

  /// Drops bidi marks intl adds to some locales, so amounts can be
  /// isolated in LTR runs without stray invisible characters.
  static String _clean(String value) => value
      .replaceAll(RegExp('[\u200E\u200F\u061C]'), '')
      // French groups thousands with a narrow no-break space; use the
      // regular no-break space every bundled font has.
      .replaceAll('\u202F', '\u00A0');
}
