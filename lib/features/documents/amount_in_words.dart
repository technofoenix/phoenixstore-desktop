/// French amount-in-words for the "Arrêtée la présente facture à la somme
/// de" line. Mirrors the backoffice `amountInWords.ts`.
library;

const _units = [
  'zéro',
  'un',
  'deux',
  'trois',
  'quatre',
  'cinq',
  'six',
  'sept',
  'huit',
  'neuf',
  'dix',
  'onze',
  'douze',
  'treize',
  'quatorze',
  'quinze',
  'seize',
];
const _tens = [
  '',
  'dix',
  'vingt',
  'trente',
  'quarante',
  'cinquante',
  'soixante',
];

String _belowHundred(int n, bool last) {
  if (n <= 16) return _units[n];
  if (n < 20) return 'dix-${_units[n - 10]}';
  final ten = n ~/ 10;
  final unit = n % 10;
  if (ten == 7 || ten == 9) {
    final base = ten == 7 ? 'soixante' : 'quatre-vingt';
    final rest = _belowHundred(10 + unit, last);
    return ten == 7 && unit == 1 ? '$base et $rest' : '$base-$rest';
  }
  if (ten == 8) {
    return unit == 0
        ? (last ? 'quatre-vingts' : 'quatre-vingt')
        : 'quatre-vingt-${_units[unit]}';
  }
  if (unit == 0) return _tens[ten];
  if (unit == 1) return '${_tens[ten]} et un';
  return '${_tens[ten]}-${_units[unit]}';
}

String _belowThousand(int n, bool last) {
  final hundreds = n ~/ 100;
  final rest = n % 100;
  if (hundreds == 0) return _belowHundred(rest, last);
  final head = hundreds == 1
      ? 'cent'
      : '${_units[hundreds]} ${rest == 0 && last ? 'cents' : 'cent'}';
  return rest == 0 ? head : '$head ${_belowHundred(rest, last)}';
}

/// A non-negative integer in French words ("mille deux cent cinquante").
String integerToFrenchWords(int value) {
  var n = value.abs();
  if (n == 0) return _units[0];
  final parts = <String>[];
  for (final (size, one, many) in const [
    (1000000000, 'milliard', 'milliards'),
    (1000000, 'million', 'millions'),
  ]) {
    final count = n ~/ size;
    if (count > 0) {
      parts.add('${_belowThousand(count, true)} ${count > 1 ? many : one}');
      n %= size;
    }
  }
  final thousands = n ~/ 1000;
  if (thousands > 0) {
    parts.add(
      thousands == 1 ? 'mille' : '${_belowThousand(thousands, false)} mille',
    );
    n %= 1000;
  }
  if (n > 0) parts.add(_belowThousand(n, true));
  return parts.join(' ');
}

const _currencyWords = {
  'DZD': ('dinar algérien', 'dinars algériens', 'centime', 'centimes'),
  'DA': ('dinar algérien', 'dinars algériens', 'centime', 'centimes'),
  'EUR': ('euro', 'euros', 'centime', 'centimes'),
  'USD': ('dollar', 'dollars', 'cent', 'cents'),
};

/// `1250.5, 'DZD'` -> "Mille deux cent cinquante dinars algériens et
/// cinquante centimes".
String amountInWordsFr(double amount, String currency) {
  final safe = amount.isFinite ? amount.abs() : 0.0;
  final totalCents = (safe * 100).round();
  final units = totalCents ~/ 100;
  final cents = totalCents % 100;
  final words =
      _currencyWords[currency.toUpperCase()] ??
      (currency, currency, 'centime', 'centimes');
  final needsDe = units >= 1000000 && units % 1000000 == 0;
  var text =
      '${integerToFrenchWords(units)} ${needsDe ? 'de ' : ''}'
      '${units > 1 ? words.$2 : words.$1}';
  if (cents > 0) {
    text +=
        ' et ${integerToFrenchWords(cents)} '
        '${cents > 1 ? words.$4 : words.$3}';
  }
  return text[0].toUpperCase() + text.substring(1);
}
