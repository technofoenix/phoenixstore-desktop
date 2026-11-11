import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoenixstore_desktop/core/models/models.dart';
import 'package:phoenixstore_desktop/features/sales/cart_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _warehouse = 'wh-1';

Product _product({String id = 'p1', int stock = 3, double price = 100}) =>
    Product(
      id: id,
      sku: 'SKU-$id',
      title: 'Product $id',
      barcode: '000$id',
      price: price,
      currency: 'DZD',
      stock: stock,
    );

Future<ProviderContainer> _container() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

CartController _cart(ProviderContainer c) =>
    c.read(cartProvider(_warehouse).notifier);
CartState _state(ProviderContainer c) => c.read(cartProvider(_warehouse));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('add respects stock and computes totals', () async {
    final c = await _container();
    final p = _product(stock: 2, price: 150);

    expect(_cart(c).add(p), AddResult.added);
    expect(_cart(c).add(p), AddResult.added);
    expect(_cart(c).add(p), AddResult.stockLimit);
    expect(_cart(c).add(_product(id: 'p2', stock: 0)), AddResult.outOfStock);

    _cart(c).setDiscount('50');
    _cart(c).setTaxRate('19');
    final s = _state(c);
    expect(s.itemCount, 2);
    expect(s.subtotal, 300);
    // TVA is a rate on the discounted base: 250 × 19 % = 47.50.
    expect(s.taxBase, 250);
    expect(s.tax, 47.5);
    expect(s.total, 297.5);
  });

  test('TVA rate: comma decimals, clamped to 0-100, never on a negative base', () async {
    final c = await _container();
    _cart(c).add(_product(price: 100));
    _cart(c).setTaxRate('9,5');
    expect(_state(c).tax, 9.5);
    _cart(c).setTaxRate('250');
    expect(_state(c).taxRate, 100);
    _cart(c).setTaxRate('19');
    _cart(c).setDiscount('500');
    expect(_state(c).taxBase, 0);
    expect(_state(c).tax, 0);
    expect(_state(c).total, 0);
  });

  test('new and cleared tickets start with the company default rate', () async {
    final c = await _container();
    c.read(defaultTaxRateProvider.notifier).set(19);
    expect(_state(c).taxRateText, '19');
    _cart(c).add(_product());
    _cart(c).setTaxRate('9');
    _cart(c).beginCheckout();
    _cart(c).checkoutSucceeded();
    expect(_state(c).taxRateText, '19');
  });

  test('a ticket saved with the old tax amount gets the default rate', () async {
    SharedPreferences.setMockInitialValues({
      'cart.$_warehouse': '{"lines":[],"taxText":"500","checkoutRef":"ref-old-1"}',
    });
    final c = await _container();
    c.read(defaultTaxRateProvider.notifier).set(19);
    expect(_state(c).taxRateText, '19');
    expect(_state(c).checkoutRef, 'ref-old-1');
  });

  test('ticket survives a restart (new container, same prefs)', () async {
    final first = await _container();
    _cart(first).add(_product());
    _cart(first).setCustomer('Amine');
    _cart(first).setPaymentMethod('CREDIT');
    final ref = _state(first).checkoutRef;
    await _cart(first).flush();

    final second = await _container();
    final restored = _state(second);
    expect(restored.lines.single.product.id, 'p1');
    expect(restored.customerName, 'Amine');
    expect(restored.paymentMethod, 'CREDIT');
    expect(restored.checkoutRef, ref);
  });

  test('invoice customer details survive a restart and clear on success', () async {
    final first = await _container();
    _cart(first).add(_product());
    _cart(first).setInvoiceCustomer(
      const DocumentCustomer(
        name: ' SARL Client ',
        address: 'Alger',
        nif: '0020160912345',
        rc: '',
      ),
    );
    var s = _state(first);
    expect(s.customerName, 'SARL Client');
    expect(s.customerDetails.nif, '0020160912345');
    expect(s.customerDetails.rc, isNull);
    expect(s.customer.isCompleteForInvoice, isTrue);
    await _cart(first).flush();

    final second = await _container();
    s = _state(second);
    expect(s.customerName, 'SARL Client');
    expect(s.customerDetails.address, 'Alger');
    expect(s.customerDetails.nif, '0020160912345');

    _cart(second).checkoutSucceeded();
    expect(_state(second).hasCustomerDetails, isFalse);
  });

  test('success clears the ticket and mints a new reference', () async {
    final c = await _container();
    _cart(c).add(_product());
    final ref = _state(c).checkoutRef;

    expect(_cart(c).beginCheckout(), isNotNull);
    _cart(c).checkoutSucceeded();

    expect(_state(c).isEmpty, isTrue);
    expect(_state(c).checkoutRef, isNot(ref));
  });

  test('retry after an uncertain failure reuses the reference', () async {
    final c = await _container();
    _cart(c).add(_product());
    final ref = _state(c).checkoutRef;

    _cart(c).beginCheckout();
    _cart(c).checkoutUncertain();

    final retry = _cart(c).beginCheckout();
    expect(retry?.checkoutRef, ref);
  });

  test('editing after an uncertain failure mints a new reference', () async {
    final c = await _container();
    _cart(c).add(_product());
    final ref = _state(c).checkoutRef;

    _cart(c).beginCheckout();
    _cart(c).checkoutUncertain();
    _cart(c).add(_product());

    expect(_state(c).checkoutRef, isNot(ref));
    expect(_state(c).lastAttemptFailed, isFalse);
  });

  test('a clean rejection keeps the reference for the next attempt', () async {
    final c = await _container();
    _cart(c).add(_product());
    final ref = _state(c).checkoutRef;

    _cart(c).beginCheckout();
    _cart(c).checkoutRejected();
    _cart(c).add(_product());

    expect(_state(c).checkoutRef, ref);
  });

  test('the ticket is locked while a checkout is in flight', () async {
    final c = await _container();
    _cart(c).add(_product());
    _cart(c).beginCheckout();

    expect(_cart(c).add(_product()), AddResult.locked);
    _cart(c).remove('p1');
    _cart(c).setDiscount('99');
    expect(_cart(c).beginCheckout(), isNull);

    final s = _state(c);
    expect(s.lines.single.quantity, 1);
    expect(s.discountText, '0');
  });

  test('carts are kept per boutique and cleared on sign-out', () async {
    final c = await _container();
    _cart(c).add(_product());
    c.read(cartProvider('wh-2').notifier).add(_product(id: 'p9'));
    await _cart(c).flush();
    await c.read(cartProvider('wh-2').notifier).flush();

    expect(_state(c).lines.single.product.id, 'p1');
    expect(c.read(cartProvider('wh-2')).lines.single.product.id, 'p9');

    final prefs = await SharedPreferences.getInstance();
    await clearSavedCarts(prefs);
    expect(prefs.getKeys().where((k) => k.startsWith('cart.')), isEmpty);
  });
}
