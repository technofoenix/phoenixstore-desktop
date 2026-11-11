import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/models.dart';

/// Loaded once in `main()` and injected with `overrideWithValue`, so the cart
/// can restore itself synchronously.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

String _newRef() => const Uuid().v4();

double _parseAmount(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.')) ?? 0;

double _round2(double value) => (value * 100).roundToDouble() / 100;

/// Text shown in the TVA field for a rate (19.0 → "19", 9.5 → "9.5").
String formatRate(double rate) =>
    rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : '$rate';

/// The company's default TVA rate (%), from the desktop context. New and
/// cleared tickets start with it; the cashier can change it per ticket.
class DefaultTaxRate extends Notifier<double> {
  @override
  double build() => 0;

  void set(double rate) => state = rate.clamp(0, 100).toDouble();
}

final defaultTaxRateProvider = NotifierProvider<DefaultTaxRate, double>(
  DefaultTaxRate.new,
);

/// The open ticket of one boutique.
///
/// [checkoutRef] is the idempotency key sent to the API as `clientReference`.
/// It stays the same across retries of the same ticket, so a checkout that
/// timed out but was committed server-side is returned, not recorded twice.
class CartState {
  const CartState({
    this.lines = const [],
    this.customerName = '',
    this.customerDetails = const DocumentCustomer(),
    this.discountText = '0',
    this.taxRateText = '0',
    this.amountPaidText = '0',
    this.paymentMethod = 'CASH',
    this.dueDate,
    required this.checkoutRef,
    this.submitting = false,
    this.lastAttemptFailed = false,
  });

  final List<CartLine> lines;
  final String customerName;

  /// Address, phone and fiscal IDs entered for a facture (name excluded:
  /// [customerName] is the source of truth).
  final DocumentCustomer customerDetails;
  final String discountText;

  /// TVA rate in percent, as typed.
  final String taxRateText;
  final String amountPaidText;
  final String paymentMethod;
  final DateTime? dueDate;
  final String checkoutRef;

  /// A checkout request is in flight; the ticket is locked.
  final bool submitting;

  /// The last checkout failed without a server answer; it may or may not have
  /// been recorded. Editing the ticket after that mints a new [checkoutRef].
  final bool lastAttemptFailed;

  bool get isEmpty => lines.isEmpty;

  /// The customer printed on documents and sent with the sale.
  DocumentCustomer get customer => customerDetails.copyWith(name: customerName);
  bool get hasCustomerDetails =>
      customerDetails.toDetailsJson().values.any((value) => value != null);
  bool get isCredit => paymentMethod == 'CREDIT';
  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);
  double get subtotal => lines.fold(0, (sum, line) => sum + line.total);
  double get discount => _parseAmount(discountText);
  double get taxRate => _parseAmount(taxRateText).clamp(0, 100).toDouble();

  /// Amount the TVA rate is applied to: subtotal after discount.
  double get taxBase =>
      (subtotal - discount).clamp(0, double.infinity).toDouble();

  /// Same rule as the API: base × rate / 100, rounded to cents.
  double get tax => _round2(taxBase * taxRate / 100);
  double get amountPaid => _parseAmount(amountPaidText);
  double get total => _round2(taxBase + tax);

  int quantityOf(String productId) => lines
      .where((line) => line.product.id == productId)
      .fold(0, (sum, line) => sum + line.quantity);

  CartState copyWith({
    List<CartLine>? lines,
    String? customerName,
    DocumentCustomer? customerDetails,
    String? discountText,
    String? taxRateText,
    String? amountPaidText,
    String? paymentMethod,
    DateTime? Function()? dueDate,
    String? checkoutRef,
    bool? submitting,
    bool? lastAttemptFailed,
  }) => CartState(
    lines: lines ?? this.lines,
    customerName: customerName ?? this.customerName,
    customerDetails: customerDetails ?? this.customerDetails,
    discountText: discountText ?? this.discountText,
    taxRateText: taxRateText ?? this.taxRateText,
    amountPaidText: amountPaidText ?? this.amountPaidText,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    dueDate: dueDate != null ? dueDate() : this.dueDate,
    checkoutRef: checkoutRef ?? this.checkoutRef,
    submitting: submitting ?? this.submitting,
    lastAttemptFailed: lastAttemptFailed ?? this.lastAttemptFailed,
  );

  Map<String, dynamic> toJson() => {
    'lines': lines.map((line) => line.toJson()).toList(),
    'customerName': customerName,
    'customerDetails': customerDetails.toDetailsJson(),
    'discountText': discountText,
    'taxRateText': taxRateText,
    'amountPaidText': amountPaidText,
    'paymentMethod': paymentMethod,
    'dueDate': dueDate?.toIso8601String(),
    'checkoutRef': checkoutRef,
    'lastAttemptFailed': lastAttemptFailed,
  };

  /// Tolerant reader: a corrupt line is skipped, a corrupt cart is dropped.
  factory CartState.fromJson(
    Map<String, dynamic> json, {
    String defaultRateText = '0',
  }) {
    final lines = <CartLine>[];
    for (final raw in (json['lines'] as List?) ?? const []) {
      try {
        final line = CartLine.fromJson(Map<String, dynamic>.from(raw as Map));
        if (line.quantity > 0) lines.add(line);
      } catch (_) {
        // Skip a line that no longer parses.
      }
    }
    final ref = json['checkoutRef'] as String?;
    return CartState(
      lines: lines,
      customerName: json['customerName'] as String? ?? '',
      customerDetails: json['customerDetails'] is Map
          ? DocumentCustomer.fromJson(
              Map<String, dynamic>.from(json['customerDetails'] as Map),
            )
          : const DocumentCustomer(),
      discountText: json['discountText'] as String? ?? '0',
      // Tickets saved before TVA became a rate stored an amount ('taxText');
      // it cannot be turned into a rate, so they get the default instead.
      taxRateText: json['taxRateText'] as String? ?? defaultRateText,
      amountPaidText: json['amountPaidText'] as String? ?? '0',
      paymentMethod: json['paymentMethod'] as String? ?? 'CASH',
      dueDate: DateTime.tryParse(json['dueDate'] as String? ?? ''),
      checkoutRef: ref != null && ref.isNotEmpty ? ref : _newRef(),
      lastAttemptFailed: json['lastAttemptFailed'] as bool? ?? false,
    );
  }
}

/// Outcome of [CartController.add].
enum AddResult { added, outOfStock, stockLimit, locked }

class CartController extends Notifier<CartState> {
  CartController(this.warehouseId);

  final String warehouseId;

  static const keyPrefix = 'cart.';
  String get _key => '$keyPrefix$warehouseId';

  Timer? _saveTimer;

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  /// An empty ticket with the company's default TVA rate.
  CartState _fresh() => CartState(
    checkoutRef: _newRef(),
    taxRateText: formatRate(ref.read(defaultTaxRateProvider)),
  );

  @override
  CartState build() {
    ref.onDispose(() {
      _saveTimer?.cancel();
      _saveTimer = null;
    });
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        return CartState.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
          defaultRateText: formatRate(ref.read(defaultTaxRateProvider)),
        );
      } catch (_) {
        // Corrupt cart: start fresh.
      }
    }
    return _fresh();
  }

  /// Applies an edit unless a checkout is in flight. After a failed attempt the
  /// edited ticket gets a new reference: its content no longer matches what may
  /// already be recorded under the old one.
  bool _edit(CartState Function(CartState current) change) {
    if (state.submitting) return false;
    var next = change(state);
    if (state.lastAttemptFailed) {
      next = next.copyWith(checkoutRef: _newRef(), lastAttemptFailed: false);
    }
    state = next;
    _scheduleSave();
    return true;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), flush);
  }

  /// Writes the cart now (also called by the debounce timer).
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final current = state;
    if (current.isEmpty &&
        current.customerName.isEmpty &&
        !current.hasCustomerDetails &&
        !current.lastAttemptFailed) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, jsonEncode(current.toJson()));
    }
  }

  AddResult add(Product product) {
    if (state.submitting) return AddResult.locked;
    if (product.stock <= 0) return AddResult.outOfStock;
    final index = state.lines.indexWhere((l) => l.product.id == product.id);
    if (index >= 0 && state.lines[index].quantity >= product.stock) {
      return AddResult.stockLimit;
    }
    _edit((s) {
      final lines = List.of(s.lines);
      if (index >= 0) {
        lines[index] = lines[index].copyWith(
          quantity: lines[index].quantity + 1,
        );
      } else {
        lines.add(CartLine(product: product));
      }
      return s.copyWith(lines: lines);
    });
    return AddResult.added;
  }

  void setQuantity(String productId, int quantity) {
    if (quantity <= 0) return remove(productId);
    _edit(
      (s) => s.copyWith(
        lines: [
          for (final line in s.lines)
            line.product.id == productId
                ? line.copyWith(quantity: quantity)
                : line,
        ],
      ),
    );
  }

  void remove(String productId) => _edit(
    (s) => s.copyWith(
      lines: s.lines.where((line) => line.product.id != productId).toList(),
    ),
  );

  void setCustomer(String value) =>
      _edit((s) => s.copyWith(customerName: value));

  /// Stores the facture customer (name + details) on the ticket.
  void setInvoiceCustomer(DocumentCustomer customer) {
    final clean = customer.normalized;
    _edit(
      (s) => s.copyWith(
        customerName: clean.name ?? '',
        customerDetails: DocumentCustomer(
          address: clean.address,
          phone: clean.phone,
          email: clean.email,
          nif: clean.nif,
          nis: clean.nis,
          rc: clean.rc,
          ai: clean.ai,
        ),
      ),
    );
  }

  void setDiscount(String value) =>
      _edit((s) => s.copyWith(discountText: value));
  void setTaxRate(String value) => _edit((s) => s.copyWith(taxRateText: value));
  void setAmountPaid(String value) =>
      _edit((s) => s.copyWith(amountPaidText: value));
  void setPaymentMethod(String value) =>
      _edit((s) => s.copyWith(paymentMethod: value));
  void setDueDate(DateTime? value) =>
      _edit((s) => s.copyWith(dueDate: () => value));

  /// Locks the ticket and returns the snapshot to send. Null when empty or
  /// already submitting.
  CartState? beginCheckout() {
    if (state.submitting || state.isEmpty) return null;
    state = state.copyWith(submitting: true);
    return state;
  }

  /// The server answered with an error (validation, stock…): nothing was
  /// recorded, so the same reference can be reused safely.
  void checkoutRejected() {
    state = state.copyWith(submitting: false, lastAttemptFailed: false);
    _scheduleSave();
  }

  /// No answer from the server: the sale may exist. Keep the reference so
  /// pressing Pay again returns it instead of creating a second one.
  void checkoutUncertain() {
    state = state.copyWith(submitting: false, lastAttemptFailed: true);
    unawaited(flush());
  }

  /// Sale recorded: empty ticket, fresh reference for the next one.
  void checkoutSucceeded() {
    state = _fresh();
    unawaited(flush());
  }
}

final cartProvider = NotifierProvider.family<CartController, CartState, String>(
  CartController.new,
);

/// Removes every saved ticket (called on sign-out).
Future<void> clearSavedCarts(SharedPreferences prefs) async {
  for (final key in prefs.getKeys().toList()) {
    if (key.startsWith(CartController.keyPrefix)) await prefs.remove(key);
  }
}
