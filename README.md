# PhoenixStore Desktop

The boutique till of PhoenixStore (Flutter, macOS / Windows / Linux). It lets
you sell with a barcode scanner, print invoices and delivery notes, follow
sales and credit, check stock, order from the wholesaler and record shop
charges. The app works in Arabic (right to left), French and English.

```bash
flutter pub get
flutter run -d macos --dart-define=API_BASE_URL=http://192.168.1.10:4000
```

## Languages

All text on screen comes from JSON files in `lib/locale/`. There is no text
in the Dart code.

| File | What it holds |
|---|---|
| `lib/locale/en.json`, `fr.json`, `ar.json` | Every word shown on screen, one file per language |
| `lib/locale/languages.json` | The languages offered in **Settings → Language**: code, own name, direction (`ltr`/`rtl`) and font |
| `lib/locale/documents.json` | The wording of printed PDFs (invoice, delivery note, stock statement). PDFs stay in French whatever the screen language |

The language picked in Settings, or on the sign-in screen, applies at once
and is kept after a restart. On first launch the till uses the computer's
language when it is offered, and French otherwise.

### Change a text

1. Open the language file, for example `lib/locale/fr.json`.
2. Find the key, for example `"sell": { "complete": "Encaisser · {total}" }`,
   and change only the value on the right.
3. Keep the words in braces (`{total}`, `{name}`, `{count}`). The app fills
   them in.
4. Restart the app (or press `R` in `flutter run`).

### Add a language

1. Copy `lib/locale/en.json` to `lib/locale/<code>.json` (for example `es.json`)
   and translate every value. Keep the keys and the `{placeholders}`.
2. Add one line to `lib/locale/languages.json`:
   ```json
   { "code": "es", "name": "Español", "dir": "ltr", "font": "Inter" }
   ```
   Use `"dir": "rtl"` for right-to-left languages. The font must be one of
   the fonts in `pubspec.yaml` (`Inter` for Latin, `IBMPlexSansArabic` for
   Arabic script).
3. Run `flutter test test/i18n_test.dart`. It fails when a key or a
   placeholder is missing.

No Dart change is needed, because the whole `lib/locale/` folder is bundled
with the app.

### Keys and plurals

- Keys are grouped by screen: `sell.*`, `history.*`, `stock.*`, `orders.*`,
  `charges.*`, `settings.*`, `auth.*`. Shared words are under `common.*` and
  `nav.*`. Codes sent by the server (payment methods, statuses, expense
  categories) are under `payment.*`, `paymentStatus.*`, `orderStatus.*` and
  `expenseCategory.*`.
- Plurals are objects with `zero`, `one`, `two`, `few`, `many`, `other`
  (Arabic uses all six). `{}` is the number.
- Numbers, money and dates follow the language: `1 234,50 DA`,
  `1,234.50 DZD`, `1.234,50 د.ج`. Arabic uses Western digits (0-9), like
  receipts and barcodes.

### Checks

```bash
flutter analyze
flutter test                                       # unit, i18n, language switch
flutter test test/inspector --dart-define=SHOTS=docs/redesign/after --dart-define=STRICT=true
```

The i18n test checks that all languages have the same keys and placeholders,
that every key used in the code exists, and that no widget shows a hard-coded
string. The inspector renders every screen and dialog in each language at
1440, 1280, 1024 and 900 px wide. It fails on any layout overflow or a wrong
text direction, and writes screenshots and `report.json`.
