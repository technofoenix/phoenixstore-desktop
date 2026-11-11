import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/models/models.dart';
import 'amount_in_words.dart';

/// Fonts embedded in every PDF. The PDF default (Helvetica) only covers
/// Latin-1: Arabic product or client names, "—", "·" and similar characters
/// printed as empty boxes. Inter covers Latin text and punctuation; IBM Plex
/// Sans Arabic is the fallback for Arabic script (the same fonts as the app).
class DocumentFonts {
  static pw.ThemeData? _theme;
  static pw.Font? _arabic;
  static pw.Font? _arabicBold;
  static pw.Font? _latin;
  static bool _tried = false;

  /// Style for text containing Arabic: the Arabic font must be the primary
  /// font (not a fallback) for letters to be joined and ordered correctly.
  static pw.TextStyle arabicStyle(pw.TextStyle base, {bool bold = false}) {
    final font = bold ? _arabicBold : _arabic;
    if (font == null) return base;
    return base.copyWith(
      font: font,
      fontBold: _arabicBold,
      fontFallback: [?_latin],
    );
  }

  /// Theme for `pw.Document(theme: ...)`; null until [load] succeeded, in
  /// which case the PDF default font is used.
  static pw.ThemeData? get theme => _theme;

  static Future<void> load([AssetBundle? bundle]) async {
    if (_tried) return;
    _tried = true;
    try {
      final b = bundle ?? rootBundle;
      Future<pw.Font> font(String file) async =>
          pw.Font.ttf(await b.load('assets/fonts/$file'));
      final arabic = await font('IBMPlexSansArabic-Regular.ttf');
      final arabicBold = await font('IBMPlexSansArabic-Bold.ttf');
      final latin = await font('Inter-Regular.ttf');
      _arabic = arabic;
      _arabicBold = arabicBold;
      _latin = latin;
      _theme = pw.ThemeData.withFont(
        base: latin,
        bold: await font('Inter-Bold.ttf'),
        italic: await font('Inter-Regular.ttf'),
        boldItalic: await font('Inter-Bold.ttf'),
        fontFallback: [arabic, arabicBold],
      );
    } catch (_) {
      _theme = null;
    }
  }
}

/// Wording of printed documents, read from `lib/locale/documents.json`.
/// Documents stay in French whatever the screen language (commercial
/// documents for Algerian customers); the file can be edited without code.
class DocumentStrings {
  static const path = 'lib/locale/documents.json';
  static Map<String, dynamic> _values = const {};

  static Future<void> load([AssetBundle? bundle]) async {
    // Every document build path loads the strings first; fonts ride along.
    await DocumentFonts.load(bundle);
    if (_values.isNotEmpty) return;
    try {
      final raw = await (bundle ?? rootBundle).loadString(path);
      _values = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      _values = const {};
    }
  }

  /// `get('type.facture')`, `get('page', {'page': '1', 'pages': '2'})`.
  static String get(String key, [Map<String, String> args = const {}]) {
    Object? node = _values;
    for (final part in key.split('.')) {
      node = node is Map ? node[part] : null;
    }
    var value = node is String ? node : key;
    args.forEach((name, arg) => value = value.replaceAll('{$name}', arg));
    return value;
  }
}

enum DocumentType {
  bonCommande('BC'),
  facture('FA'),
  factureProforma('FP'),
  bonLivraison('BL');

  const DocumentType(this.prefix);

  final String prefix;

  /// Printed (French) title.
  String get title => DocumentStrings.get('type.$name');

  bool get isInvoiceLike =>
      this == DocumentType.facture || this == DocumentType.factureProforma;

  /// Only the facture carries fiscal identifiers and the stamp block; the
  /// other documents show contact details only.
  bool get showFiscal => this == DocumentType.facture;

  /// A delivery note lists quantities only.
  bool get showPrices => this != DocumentType.bonLivraison;
}

class DocumentLine {
  const DocumentLine({
    required this.title,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  final String title;
  final String sku;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
}

class DocumentData {
  const DocumentData({
    required this.type,
    required this.reference,
    required this.date,
    required this.company,
    this.logo,
    required this.warehouseName,
    this.customer,
    required this.lines,
    required this.subtotal,
    required this.discount,
    this.taxRate = 0,
    required this.tax,
    required this.total,
    required this.currency,
    this.paymentMethod,
    this.note,
  });

  final DocumentType type;
  final String reference;
  final DateTime date;

  /// The seller (tenant company settings).
  final CompanySettings company;

  /// PNG/JPEG bytes of the company logo.
  final Uint8List? logo;
  final String warehouseName;

  /// The buyer. Fiscal identifiers are printed on the facture only.
  final DocumentCustomer? customer;
  final List<DocumentLine> lines;
  final double subtotal;
  final double discount;

  /// TVA rate (%) printed beside the amount, e.g. "TVA (19 %)".
  final double taxRate;
  final double tax;
  final double total;
  final String currency;
  final String? paymentMethod;
  final String? note;
}

/// A printable list (sales, clients, stock, orders, charges).
class ListDocument {
  const ListDocument({
    required this.kind,
    required this.companyName,
    required this.warehouseName,
    required this.headers,
    required this.rows,
    this.numericColumns = const {},
    this.filters = const [],
    this.totals = const [],
    this.logo,
  });

  /// PNG/JPEG bytes of the company logo, printed beside the company name.
  final Uint8List? logo;

  /// `sales`, `clients`, `stock`, `orders` or `charges` (title and file name).
  final String kind;
  final String companyName;
  final String warehouseName;
  final List<String> headers;
  final List<List<String>> rows;
  final Set<int> numericColumns;

  /// Active filters, already worded in French.
  final List<String> filters;

  /// Label / value lines printed under the table.
  final List<(String, String)> totals;
}

class DocumentService {
  static final _money = NumberFormat('#,##0.00');

  /// Amount as printed on documents.
  static String money(num value) => _money.format(value);

  static String date(DateTime value) => DateFormat('dd/MM/yyyy').format(value);

  static String dateTime(DateTime value) =>
      DateFormat('dd/MM/yyyy HH:mm').format(value);

  /// French label of a server code (`payment`, `paymentStatus`, ...).
  static String code(String group, String? value) {
    if (value == null || value.isEmpty) return '—';
    final label = DocumentStrings.get('$group.$value');
    return label == '$group.$value' ? value : label;
  }

  static Future<void> printList(ListDocument list) async {
    await DocumentStrings.load();
    final now = DateTime.now();
    final document = buildList(list, now);
    await Printing.layoutPdf(
      name:
          '${DocumentStrings.get('list.file.${list.kind}')}-${DateFormat('yyyyMMdd-HHmmss').format(now)}.pdf',
      onLayout: (_) => document.save(),
    );
  }

  /// Rows of a printed list: shaded header repeated on every page, light
  /// row separators, zebra rows, numbers right-aligned and never wrapped.
  /// Text columns share the remaining width by their typical content length.
  static pw.Widget _listTable(ListDocument list) {
    final columns = list.headers.length;
    final numeric = list.numericColumns;

    // Width of each text column follows its typical (not longest) content so
    // one long title does not squeeze every other column.
    int typicalLength(int col) {
      final lengths = [
        for (final row in list.rows)
          if (col < row.length) row[col].length,
      ]..sort();
      final typical = lengths.isEmpty
          ? 0
          : lengths[(lengths.length * 0.8).floor().clamp(
              0,
              lengths.length - 1,
            )];
      return [
        typical,
        list.headers[col].length,
      ].reduce((a, b) => a > b ? a : b);
    }

    // Codes (references, SKUs, dates) are short and have no spaces: they get
    // exactly their width and never wrap.
    bool isCode(int col) =>
        list.rows.isNotEmpty &&
        list.rows.every(
          (row) =>
              col >= row.length ||
              (row[col].length <= 20 && !row[col].trim().contains(' ')),
        );
    final fixed = {
      for (var i = 0; i < columns; i++)
        if (numeric.contains(i) || isCode(i)) i,
    };

    final widths = <int, pw.TableColumnWidth>{
      for (var i = 0; i < columns; i++)
        i: fixed.contains(i)
            ? const pw.IntrinsicColumnWidth()
            : pw.FlexColumnWidth(typicalLength(i).clamp(4, 40).toDouble()),
    };

    pw.Widget cell(String text, int col, {bool header = false}) {
      final style = pw.TextStyle(
        fontSize: header ? 8 : 8.5,
        fontWeight: header ? pw.FontWeight.bold : null,
        color: header ? _muted : _ink,
      );
      final arabic = _arabic.hasMatch(text);
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Text(
          text,
          // Arabic names read right to left, shaped by the Arabic font.
          textDirection: arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          textAlign: numeric.contains(col)
              ? pw.TextAlign.right
              : pw.TextAlign.left,
          softWrap: !fixed.contains(col),
          style: arabic
              ? DocumentFonts.arabicStyle(style, bold: header)
              : style,
        ),
      );
    }

    return pw.Table(
      columnWidths: widths,
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      border: pw.TableBorder(
        top: pw.BorderSide(color: _line, width: 0.75),
        bottom: pw.BorderSide(color: _line, width: 0.75),
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
      ),
      children: [
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(color: _headerFill),
          children: [
            for (var i = 0; i < columns; i++)
              cell(list.headers[i].toUpperCase(), i, header: true),
          ],
        ),
        for (var r = 0; r < list.rows.length; r++)
          pw.TableRow(
            decoration: r.isOdd ? pw.BoxDecoration(color: _zebra) : null,
            children: [
              for (var i = 0; i < columns; i++)
                cell(i < list.rows[r].length ? list.rows[r][i] : '', i),
            ],
          ),
      ],
    );
  }

  /// The PDF of a list (strings must be loaded).
  static pw.Document buildList(ListDocument list, DateTime now) {
    final t = DocumentStrings.get;
    final wide = list.headers.length > 6;
    final document = pw.Document(theme: DocumentFonts.theme);
    pw.ImageProvider? logo;
    if (list.logo != null) {
      try {
        logo = pw.MemoryImage(list.logo!);
      } catch (_) {
        logo = null;
      }
    }
    document.addPage(
      pw.MultiPage(
        pageFormat: wide ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logo != null) ...[
                    pw.Container(
                      width: 90,
                      height: 46,
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Image(logo, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 12),
                  ],
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _text(
                        list.companyName,
                        pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        bold: true,
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(t('boutique', {'name': list.warehouseName})),
                      pw.Text(
                        t('list.printedOn', {'date': dateTime(now)}),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    t('list.${list.kind}'),
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red800,
                    ),
                  ),
                  pw.Text(t('list.rows', {'count': '${list.rows.length}'})),
                ],
              ),
            ],
          ),
          if (list.filters.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              t('list.filters', {'filters': list.filters.join(' · ')}),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.grey400),
          _listTable(list),
          if (list.totals.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.SizedBox(
                  width: 240,
                  child: pw.Column(
                    children: [
                      for (final (label, value) in list.totals)
                        _totalRow(label, value, bold: true),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            t('page', {
              'page': '${context.pageNumber}',
              'pages': '${context.pagesCount}',
            }),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
      ),
    );
    return document;
  }

  static String referenceFor(DocumentType type, DateTime date) {
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(date);
    return '${type.prefix}-$stamp';
  }

  static Future<void> print(DocumentData data) async {
    await DocumentStrings.load();
    final document = buildDocument(data);
    await Printing.layoutPdf(
      name: '${data.reference}.pdf',
      onLayout: (_) => document.save(),
    );
  }

  // Palette shared with the backoffice documents (orderDocumentDefinition.ts).
  static final _accent = PdfColor.fromHex('#0f766e');
  static final _accentSoft = PdfColor.fromHex('#f0fdfa');
  static final _ink = PdfColor.fromHex('#111827');
  static final _muted = PdfColor.fromHex('#6b7280');
  static final _line = PdfColor.fromHex('#e5e7eb');
  static final _headerFill = PdfColor.fromHex('#f3f4f6');
  static final _arabic = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]',
  );
  static final _zebra = PdfColor.fromHex('#f9fafb');
  static final _danger = PdfColor.fromHex('#b91c1c');

  static bool _has(String? value) => value != null && value.trim().isNotEmpty;

  /// "19", "9,5" (French decimal comma, as on the rest of the document).

  static String _rate(double rate) => rate == rate.roundToDouble()
      ? rate.toStringAsFixed(0)
      : rate
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceAll('.', ',');

  static String _amount(double value, String currency) =>
      '${money(value)} $currency';

  static List<String> _companyAddressLines(CompanySettings company) => [
    company.address,
    [company.postalCode, company.city].where(_has).join(' '),
    company.country,
  ].whereType<String>().where(_has).toList();

  static List<(String, String?)> _fiscalPairs({
    String? nif,
    String? nis,
    String? rc,
    String? ai,
  }) {
    final t = DocumentStrings.get;
    return [(t('nif'), nif), (t('nis'), nis), (t('rc'), rc), (t('ai'), ai)];
  }

  static List<pw.Widget> _labelRows(List<(String, String?)> fields) => [
    for (final (label, value) in fields)
      if (_has(value))
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1.5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 58,
                child: pw.Text(
                  label,
                  style: pw.TextStyle(fontSize: 8, color: _muted),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  value!.trim(),
                  style: pw.TextStyle(fontSize: 8.5, color: _ink),
                ),
              ),
            ],
          ),
        ),
  ];

  /// Text that may be Arabic (product, client or company names): Arabic is
  /// set right to left with the Arabic font as primary so letters join.
  static pw.Widget _text(String text, pw.TextStyle style, {bool bold = false}) {
    final arabic = _arabic.hasMatch(text);
    return pw.Text(
      text,
      textDirection: arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      style: arabic ? DocumentFonts.arabicStyle(style, bold: bold) : style,
    );
  }

  static pw.Widget _partyCard(
    String title,
    String name,
    List<pw.Widget> rows,
    List<pw.Widget> fiscalRows,
  ) => pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _line, width: 0.75),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: _accentSoft,
          padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 4),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _accent,
              letterSpacing: 1,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _text(
                name,
                pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
                bold: true,
              ),
              pw.SizedBox(height: 3),
              ...rows,
              if (fiscalRows.isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Container(height: 0.5, color: _line),
                pw.SizedBox(height: 3),
                ...fiscalRows,
              ],
            ],
          ),
        ),
      ],
    ),
  );

  static pw.Widget _cell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
    bool header = false,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: header ? 8 : 9,
        fontWeight: bold || header ? pw.FontWeight.bold : null,
        color: header ? PdfColors.white : _ink,
      ),
    ),
  );

  static pw.Widget _itemTable(DocumentData data) {
    final t = DocumentStrings.get;
    final prices = data.type.showPrices;
    final header = pw.TableRow(
      decoration: pw.BoxDecoration(color: _accent),
      children: [
        _cell(t('colIndex'), align: pw.TextAlign.center, header: true),
        _cell(t('colTitle'), header: true),
        _cell(t('colQuantity'), align: pw.TextAlign.right, header: true),
        if (prices) ...[
          _cell(t('colUnitPrice'), align: pw.TextAlign.right, header: true),
          _cell(t('colAmount'), align: pw.TextAlign.right, header: true),
        ],
      ],
    );
    final rows = <pw.TableRow>[
      for (final (index, line) in data.lines.indexed)
        pw.TableRow(
          decoration: index.isOdd ? pw.BoxDecoration(color: _zebra) : null,
          children: [
            _cell('${index + 1}', align: pw.TextAlign.center),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 5,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _text(line.title, pw.TextStyle(fontSize: 9, color: _ink)),
                  if (_has(line.sku))
                    pw.Text(
                      t('skuPrefix', {'sku': line.sku}),
                      style: pw.TextStyle(fontSize: 7.5, color: _muted),
                    ),
                ],
              ),
            ),
            _cell('${line.quantity}', align: pw.TextAlign.right),
            if (prices) ...[
              _cell(
                _amount(line.unitPrice, data.currency),
                align: pw.TextAlign.right,
              ),
              _cell(
                _amount(line.totalPrice, data.currency),
                align: pw.TextAlign.right,
                bold: true,
              ),
            ],
          ],
        ),
    ];
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
        bottom: pw.BorderSide(color: _line, width: 0.5),
      ),
      columnWidths: prices
          ? const {
              0: pw.FixedColumnWidth(24),
              1: pw.FlexColumnWidth(),
              2: pw.FixedColumnWidth(40),
              3: pw.FixedColumnWidth(92),
              4: pw.FixedColumnWidth(96),
            }
          : const {
              0: pw.FixedColumnWidth(24),
              1: pw.FlexColumnWidth(),
              2: pw.FixedColumnWidth(60),
            },
      children: [
        header,
        if (rows.isEmpty)
          pw.TableRow(
            children: [
              pw.SizedBox(),
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Text(
                  t('noLines'),
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: _muted,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              pw.SizedBox(),
              if (prices) ...[pw.SizedBox(), pw.SizedBox()],
            ],
          ),
        ...rows,
      ],
    );
  }

  static pw.Widget _totals(DocumentData data) {
    final t = DocumentStrings.get;
    pw.Widget row(String label, String value, {PdfColor? color}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _muted)),
              pw.Text(
                value,
                style: pw.TextStyle(fontSize: 9, color: color ?? _ink),
              ),
            ],
          ),
        );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.SizedBox(
          width: 240,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              row(t('totalHt'), _amount(data.subtotal, data.currency)),
              if (data.discount > 0)
                row(
                  t('discount'),
                  '- ${_amount(data.discount, data.currency)}',
                  color: _danger,
                ),
              if (data.tax > 0)
                row(
                  data.taxRate > 0
                      ? '${t('tax')} (${_rate(data.taxRate)} %)'
                      : t('tax'),
                  _amount(data.tax, data.currency),
                ),
              pw.Container(
                color: _accent,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 7,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      t('netToPay'),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      _amount(data.total, data.currency),
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _labelled(String label, String value) => pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(
          text: label,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _muted),
        ),
        pw.TextSpan(
          text: value,
          style: pw.TextStyle(color: _ink),
        ),
      ],
      style: const pw.TextStyle(fontSize: 8.5),
    ),
  );

  static pw.Widget _stamp() => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Column(
        children: [
          pw.Text(
            DocumentStrings.get('stamp'),
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _muted,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            width: 210,
            height: 84,
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: _line, width: 0.75),
            ),
          ),
        ],
      ),
    ],
  );

  /// The PDF of a commercial document (strings must be loaded).
  static pw.Document buildDocument(DocumentData data) {
    final t = DocumentStrings.get;
    final type = data.type;
    final company = data.company;
    final customer = data.customer?.normalized ?? const DocumentCustomer();
    final document = pw.Document(
      theme: DocumentFonts.theme,
      title: '${type.title} ${data.reference}',
      author: company.name,
      creator: company.name,
    );

    pw.ImageProvider? logo;
    if (data.logo != null) {
      try {
        logo = pw.MemoryImage(data.logo!);
      } catch (_) {
        logo = null;
      }
    }

    final contactLine = [
      company.phone,
      company.email,
      company.website,
    ].where(_has).join('  ·  ');

    final metaRows = <(String, String)>[
      (t('number', {'reference': ''}).trim(), data.reference),
      (t('date'), dateTime(data.date)),
      (
        t('boutique', {'name': ''}).replaceAll(':', '').trim(),
        data.warehouseName,
      ),
      if (data.paymentMethod != null)
        (t('paymentLabel'), code('payment', data.paymentMethod)),
    ];

    final titleCard = pw.SizedBox(
      width: 190,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            type.title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: _accent,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _line, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(62),
              1: pw.FlexColumnWidth(),
            },
            children: [
              for (final (index, (label, value)) in metaRows.indexed)
                pw.TableRow(
                  decoration: index == 0
                      ? pw.BoxDecoration(color: _accentSoft)
                      : null,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.fromLTRB(6, 3, 4, 3),
                      child: pw.Text(
                        label,
                        style: pw.TextStyle(fontSize: 8, color: _muted),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.fromLTRB(4, 3, 6, 3),
                      child: pw.Text(
                        value,
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: index == 0 ? 9.5 : 8.5,
                          fontWeight: index == 0 ? pw.FontWeight.bold : null,
                          color: _ink,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    final header = pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logo != null) ...[
          pw.Container(
            width: 96,
            height: 72,
            alignment: pw.Alignment.topLeft,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 12),
        ],
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _text(
                  company.name,
                  pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                  bold: true,
                ),
                if (_has(company.legalName))
                  pw.Text(
                    company.legalName!,
                    style: pw.TextStyle(fontSize: 9, color: _muted),
                  ),
                pw.SizedBox(height: 6),
                for (final line in _companyAddressLines(company))
                  pw.Text(
                    line,
                    style: pw.TextStyle(fontSize: 8.5, color: _ink),
                  ),
                if (_has(contactLine)) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    contactLine,
                    style: pw.TextStyle(fontSize: 8.5, color: _ink),
                  ),
                ],
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        titleCard,
      ],
    );

    final emitter = _partyCard(
      t('emitter'),
      _has(company.legalName) ? company.legalName! : company.name,
      _labelRows([
        (t('address'), _companyAddressLines(company).join(', ')),
        (t('phone'), company.phone),
        (t('email'), company.email),
      ]),
      type.showFiscal
          ? _labelRows(
              _fiscalPairs(
                nif: company.nif,
                nis: company.nis,
                rc: company.rc,
                ai: company.ai,
              ),
            )
          : const [],
    );

    final buyer = _partyCard(
      type == DocumentType.bonLivraison ? t('recipient') : t('customer'),
      customer.hasName ? customer.name! : t('walkIn'),
      _labelRows([
        (t('address'), customer.address),
        (t('phone'), customer.phone),
        (t('email'), customer.email),
      ]),
      type.showFiscal
          ? _labelRows(
              _fiscalPairs(
                nif: customer.nif,
                nis: customer.nis,
                rc: customer.rc,
                ai: customer.ai,
              ),
            )
          : const [],
    );

    // A table row gives both cards the same height.
    final parties = pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(),
        1: pw.FixedColumnWidth(14),
        2: pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.full,
          children: [emitter, pw.SizedBox(), buyer],
        ),
      ],
    );

    final footerIdentity = [
      company.name,
      company.phone,
      company.email,
    ].where(_has).join('  ·  ');
    final footerFiscal = type.showFiscal
        ? _fiscalPairs(
                nif: company.nif,
                nis: company.nis,
                rc: company.rc,
                ai: company.ai,
              )
              .where((pair) => _has(pair.$2))
              .map((pair) => '${pair.$1} : ${pair.$2}')
              .join('  ·  ')
        : '';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 28),
        build: (context) => [
          header,
          pw.SizedBox(height: 14),
          pw.Container(height: 2, color: _accent),
          pw.SizedBox(height: 20),
          parties,
          pw.SizedBox(height: 18),
          _itemTable(data),
          if (type.showPrices) ...[pw.SizedBox(height: 10), _totals(data)],
          if (type.isInvoiceLike) ...[
            pw.SizedBox(height: 16),
            pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: type == DocumentType.facture
                        ? t('amountInWords')
                        : t('amountInWordsProforma'),
                    style: pw.TextStyle(color: _muted),
                  ),
                  pw.TextSpan(
                    text: amountInWordsFr(data.total, data.currency),
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                ],
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            if (_has(company.paymentTerms)) ...[
              pw.SizedBox(height: 10),
              _labelled(t('paymentTerms'), company.paymentTerms!.trim()),
            ],
            if (_has(company.bankName) || _has(company.bankAccount)) ...[
              pw.SizedBox(height: 3),
              _labelled(
                t('bank'),
                [company.bankName, company.bankAccount].where(_has).join(' - '),
              ),
            ],
          ],
          if (_has(data.note)) ...[
            pw.SizedBox(height: 10),
            _labelled('${t('note')} : ', data.note!.trim()),
          ],
          if (type.showFiscal) ...[pw.SizedBox(height: 24), _stamp()],
          if (_has(company.invoiceFooter)) ...[
            pw.SizedBox(height: 24),
            pw.Center(
              child: pw.Text(
                company.invoiceFooter!.trim(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 8,
                  color: _muted,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
        footer: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(height: 0.5, color: _line),
            pw.SizedBox(height: 6),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _text(
                        footerIdentity,
                        pw.TextStyle(fontSize: 7.5, color: _muted),
                      ),
                      if (footerFiscal.isNotEmpty)
                        pw.Text(
                          footerFiscal,
                          style: pw.TextStyle(fontSize: 7, color: _muted),
                        ),
                    ],
                  ),
                ),
                pw.Text(
                  t('page', {
                    'page': '${context.pageNumber}',
                    'pages': '${context.pagesCount}',
                  }),
                  style: pw.TextStyle(fontSize: 7.5, color: _muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return document;
  }

  static pw.Widget _totalRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: bold ? 12 : 9,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }
}
