// Guards the translation files and the "no hard-coded text" rule.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:phoenixstore_desktop/core/i18n/formatters.dart';

Map<String, String> _flatten(Map<String, dynamic> json, [String prefix = '']) {
  final out = <String, String>{};
  json.forEach((key, value) {
    final path = prefix.isEmpty ? key : '$prefix.$key';
    if (value is Map) {
      out.addAll(_flatten(Map<String, dynamic>.from(value), path));
    } else {
      out[path] = '$value';
    }
  });
  return out;
}

Set<String> _placeholders(String value) =>
    RegExp(r'\{(\w*)\}').allMatches(value).map((m) => m.group(1)!).toSet();

List<String> get _languageCodes {
  final manifest =
      jsonDecode(File('lib/locale/languages.json').readAsStringSync()) as List;
  return manifest.map((e) => (e as Map)['code'] as String).toList();
}

Map<String, String> _load(String code) => _flatten(
  Map<String, dynamic>.from(
    jsonDecode(File('lib/locale/$code.json').readAsStringSync()) as Map,
  ),
);

void main() {
  test('every language in languages.json has a translation file', () {
    for (final code in _languageCodes) {
      expect(File('lib/locale/$code.json').existsSync(), isTrue, reason: code);
    }
  });

  test('all languages have the same keys and placeholders as English', () {
    final reference = _load('en');
    for (final code in _languageCodes.where((c) => c != 'en')) {
      final other = _load(code);
      final missing = reference.keys.toSet().difference(other.keys.toSet());
      final extra = other.keys.toSet().difference(reference.keys.toSet());
      expect(missing, isEmpty, reason: '$code.json is missing keys');
      expect(extra, isEmpty, reason: '$code.json has unknown keys');
      for (final key in reference.keys) {
        // Plural forms may drop the number ("قطعتان" = two items); only the
        // general form must keep it.
        final pluralForm = RegExp(r'\.(zero|one|two|few|many)$').hasMatch(key);
        if (pluralForm) continue;
        expect(
          _placeholders(other[key]!),
          _placeholders(reference[key]!),
          reason: '$code.json "$key" placeholders differ',
        );
        expect(other[key]!.trim(), isNotEmpty, reason: '$code.json "$key"');
      }
    }
  });

  test('every key used in the code exists in the English file', () {
    final keys = _load('en').keys.toSet();
    // Plural keys are stored as maps (sell.items.one ...).
    final pluralRoots = keys
        .where((k) => k.endsWith('.other'))
        .map((k) => k.substring(0, k.length - '.other'.length))
        .toSet();
    final used = <String, String>{};
    final pattern = RegExp(
      r"""(?:\btr|\.tr|plural|trExists)\(\s*'([a-zA-Z]+\.[a-zA-Z0-9_.]+)'""",
    );
    for (final file in _dartFiles()) {
      for (final match in pattern.allMatches(file.readAsStringSync())) {
        used[match.group(1)!] = file.path;
      }
    }
    final unknown = used.keys
        .where((k) => !keys.contains(k) && !pluralRoots.contains(k))
        .map((k) => '$k (${used[k]})')
        .toList();
    expect(unknown, isEmpty);
  });

  test('no hard-coded visible text in widgets', () {
    // A string literal handed to something the user reads.
    final visible = RegExp(
      r"""(?:\bText\(|labelText:|hintText:|helperText:|errorText:|tooltip:|title:|subtitle:|message:|label:|semanticsLabel:|suffixText:|prefixText:)\s*(?:const\s+)?(?:Text\(\s*)?'([^']*)'""",
    );
    final word = RegExp(r'\p{L}{2,}', unicode: true);
    final hits = <String>[];
    for (final file in _dartFiles()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        for (final match in visible.allMatches(line)) {
          final literal = match
              .group(1)!
              .replaceAll(RegExp(r'\$\{[^}]*\}|\$\w+'), '');
          if (word.hasMatch(literal)) {
            hits.add('${file.path}:${i + 1}  ${line.trim()}');
          }
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('Arabic numbers and dates use Western digits', () async {
    await initializeDateFormatting();
    final locale = Fmt.intlLocaleFor('ar');
    final number = NumberFormat('#,##0.00', locale).format(1234567.5);
    final date = DateFormat(
      'dd/MM/yyyy · HH:mm',
      locale,
    ).format(DateTime(2026, 11, 8, 9, 5));
    expect(number, matches(RegExp(r'^[0-9.,‎‏؜ ]+$')));
    expect(date, '08/11/2026 · 09:05');
  });
}

Iterable<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));
