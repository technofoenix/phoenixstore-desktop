import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:phoenixstore_desktop/core/models/models.dart';
import 'package:phoenixstore_desktop/core/storage/session_store.dart';
import 'package:phoenixstore_desktop/features/api/desktop_api.dart';

/// What the fake API returns for every data endpoint. The shell context
/// always loads unless [failContext] is set, so each tab can be shown in
/// each state.
enum DataMode { loaded, empty, error, loading }

/// The server cannot be reached (what a till sees when the network drops).
DioException _offline() => DioException(
  requestOptions: RequestOptions(path: '/api/v1/desktop'),
  type: DioExceptionType.connectionError,
);

Product fakeProduct(
  int i, {
  required String title,
  required double price,
  required int stock,
  int? sourceStock,
  String family = 'Épicerie',
  String category = 'Huiles',
}) => Product(
  id: 'p$i',
  sku: 'SKU-${1000 + i}',
  title: title,
  barcode: '61300000${100 + i}',
  price: price,
  currency: 'DZD',
  stock: stock,
  // Main warehouse: a few products low or out, the rest plentiful.
  sourceStock: sourceStock ?? (i % 7 == 0 ? 0 : (i % 5 == 0 ? 3 : 120 + i)),
  imageUrl: null,
  images: const [],
  subCategoryName: '$category ${i.isEven ? 'premium' : 'classique'}',
  categoryName: category,
  familyName: family,
);

final fakeProducts = <Product>[
  fakeProduct(1, title: 'Huile Elio 1L', price: 650, stock: 42),
  fakeProduct(
    2,
    title: 'Semoule extra Safina 5kg',
    price: 1150,
    stock: 18,
    category: 'Semoule',
  ),
  fakeProduct(
    3,
    title: 'Café Bonal 250g',
    price: 420,
    stock: 3,
    category: 'Café',
  ),
  fakeProduct(
    4,
    title: 'Lait Candia 1L',
    price: 135,
    stock: 0,
    family: 'Frais',
    category: 'Lait',
  ),
  fakeProduct(
    5,
    title: 'Sucre blanc 1kg',
    price: 110,
    stock: 75,
    category: 'Sucre',
  ),
  fakeProduct(
    6,
    title: 'Thé Kasbah vert 500g',
    price: 380,
    stock: 9,
    category: 'Thé',
  ),
  fakeProduct(
    7,
    title: 'Eau minérale Ifri 1.5L',
    price: 45,
    stock: 120,
    family: 'Boissons',
    category: 'Eau',
  ),
  fakeProduct(
    8,
    title: 'Jus Rouiba orange 1L',
    price: 210,
    stock: 26,
    family: 'Boissons',
    category: 'Jus',
  ),
];

SaleResult fakeSale(int i, {String status = 'PAID', double balance = 0}) =>
    SaleResult(
      id: 's$i',
      reference: 'VT-2026-${(1040 + i).toString()}',
      subtotal: 2400.0 + i * 150,
      discount: 0,
      tax: 0,
      total: 2400.0 + i * 150,
      currency: 'DZD',
      paymentMethod: status == 'PAID' ? (i.isEven ? 'CASH' : 'CARD') : 'CREDIT',
      customerName: _customers[i % _customers.length],
      warehouseName: 'Boutique Bab Ezzouar',
      soldAt: DateTime(2026, 11, 8, 9 + i, 15),
      lines: [
        SaleLineResult(
          title: 'Huile Elio 1L',
          sku: 'SKU-1001',
          quantity: 2,
          unitPrice: 650,
          totalPrice: 1300,
        ),
        SaleLineResult(
          title: 'Semoule extra Safina 5kg',
          sku: 'SKU-1002',
          quantity: 1,
          unitPrice: 1100.0 + i * 150,
          totalPrice: 1100.0 + i * 150,
        ),
      ],
      amountPaid: 2400.0 + i * 150 - balance,
      balanceDue: balance,
      paymentStatus: status,
      dueDate: status == 'PAID' ? null : DateTime(2026, 12, 8),
      createdByName: 'Amina Haddad',
      payments: [
        if (status != 'UNPAID')
          SalePaymentResult(
            id: 'pay$i',
            amount: 2400.0 + i * 150 - balance,
            currency: 'DZD',
            paymentMethod: status == 'PAID' ? 'CASH' : 'CASH',
            paidAt: DateTime(2026, 11, 8, 9 + i, 15),
            createdByName: 'Amina Haddad',
          ),
      ],
    );

class _NoStorage implements SessionStorage {
  final _data = <String, String>{};
  @override
  Future<void> delete(String key) async => _data.remove(key);
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

const _customers = [
  null,
  'Karim Benali',
  'Nadia Cherif',
  'Karim Benali',
  'Yacine Mansouri',
];

class FakeDesktopApi extends DesktopApi {
  FakeDesktopApi({this.mode = DataMode.loaded, this.failContext = false})
    : super(Dio(), SessionStore(_NoStorage()));

  final DataMode mode;
  final bool failContext;

  Future<T> _answer<T>(T loaded, T empty) {
    switch (mode) {
      case DataMode.loaded:
        return Future.value(loaded);
      case DataMode.empty:
        return Future.value(empty);
      case DataMode.error:
        return Future.error(_offline());
      case DataMode.loading:
        return Completer<T>().future;
    }
  }

  @override
  Future<DesktopContext> context({String? warehouseId}) {
    if (failContext) {
      return Future.error(_offline());
    }
    return Future.value(
      DesktopContext(
        userId: 'u1',
        fullName: 'Amina Haddad',
        role: 'CLIENT',
        warehouses: const [
          WarehouseOption(
            id: 'w1',
            name: 'Boutique Bab Ezzouar',
            code: 'BZ',
            companyName: 'Superette El Nour',
          ),
          WarehouseOption(
            id: 'w2',
            name: 'Boutique Hydra',
            code: 'HY',
            companyName: 'Superette El Nour',
          ),
        ],
        context: PosContextInfo(
          clientProfileId: 'c1',
          tenantId: 't1',
          warehouseId: warehouseId ?? 'w1',
          warehouseName: warehouseId == 'w2'
              ? 'Boutique Hydra'
              : 'Boutique Bab Ezzouar',
          companyName: 'Superette El Nour',
        ),
      ),
    );
  }

  @override
  Future<List<Product>> catalog({String? warehouseId, String? search}) =>
      _answer(fakeProducts, const <Product>[]);

  @override
  Future<Product> lookupBarcode(String barcode, {String? warehouseId}) =>
      Future.value(fakeProducts.first);

  @override
  Future<SaleResult> createSale({
    required String clientReference,
    required String warehouseId,
    required List<CartLine> lines,
    required String paymentMethod,
    required double discount,
    required double taxRate,
    String? customerName,
    DocumentCustomer? customer,
    String? note,
    double? amountPaid,
    String? initialPaymentMethod,
    DateTime? dueDate,
  }) => Future.value(fakeSale(1));

  @override
  Future<SaleResult> updateSaleCustomer({
    required String saleId,
    required DocumentCustomer customer,
    String? warehouseId,
  }) => Future.value(fakeSale(1));

  @override
  Future<CompanySettings> company() => Future.value(
    const CompanySettings(
      name: 'Phoenix Store',
      legalName: 'SARL Phoenix Distribution',
      phone: '0550 12 34 56',
      email: 'contact@phoenix.dz',
      address: '12 rue des Palmiers',
      city: 'Alger',
      postalCode: '16000',
      country: 'Algérie',
      nif: '000216001234567',
      nis: '000216010012345',
      rc: '16/00-1234567B21',
      ai: '16019876543',
    ),
  );

  @override
  Future<Uint8List?> downloadBytes(String url) => Future.value(null);

  @override
  Future<SaleResult> recordSalePayment({
    required String saleId,
    required double amount,
    required String paymentMethod,
    String? reference,
    String? note,
  }) => Future.value(fakeSale(2));

  @override
  Future<List<StockItem>> stock({
    String? warehouseId,
    String? search,
    bool lowStock = false,
    int page = 1,
  }) => _answer([
    for (final p in fakeProducts)
      StockItem(
        product: p,
        quantity: p.stock,
        reorderLevel: 10,
        updatedAt: DateTime(2026, 11, 7, 18),
      ),
  ], const <StockItem>[]);

  @override
  Future<List<OrderResult>> orders({String? warehouseId}) => _answer([
    for (final (i, status) in [
      'PENDING',
      'APPROVED',
      'PROCESSING',
      'COMPLETED',
      'CANCELLED',
    ].indexed)
      OrderResult(
        id: 'o$i',
        code: 'CMD-2026-0${210 + i}',
        status: status,
        totalAmount: 18500.0 + i * 4200,
        createdAt: DateTime(2026, 11, 1 + i, 10),
        createdByName: 'Amina Haddad',
        lines: [
          OrderLineResult(
            title: 'Huile Elio 1L',
            sku: 'SKU-1001',
            quantity: 24,
            receivedQuantity: status == 'COMPLETED' ? 24 : 0,
            unitPrice: 600,
            totalPrice: 14400,
          ),
          OrderLineResult(
            title: 'Café Bonal 250g',
            sku: 'SKU-1003',
            quantity: 10 + i,
            receivedQuantity: status == 'COMPLETED' ? 10 + i : 0,
            unitPrice: 410,
            totalPrice: 410.0 * (10 + i),
          ),
        ],
      ),
  ], const <OrderResult>[]);

  @override
  Future<OrderResult> createOrder({
    required String clientReference,
    required String warehouseId,
    required List<CartLine> lines,
  }) => Future.value(
    OrderResult(
      id: 'o9',
      code: 'CMD-2026-0299',
      status: 'PENDING',
      totalAmount: 1000,
      createdAt: DateTime(2026, 11, 8),
      lines: const [],
    ),
  );

  @override
  Future<List<SaleResult>> sales({
    String? warehouseId,
    int page = 1,
    int pageSize = 50,
  }) => _answer([
    fakeSale(1),
    fakeSale(2, status: 'PARTIAL', balance: 1200),
    fakeSale(3),
    fakeSale(4, status: 'UNPAID', balance: 3000),
    fakeSale(5),
  ], const <SaleResult>[]);

  @override
  Future<({List<ExpenseRecord> items, double total, int count})> expenses({
    required String warehouseId,
    DateTime? from,
    DateTime? to,
  }) {
    final items = <ExpenseRecord>[
      ExpenseRecord(
        id: 'e1',
        label: 'Loyer novembre',
        category: 'RENT',
        amount: 45000,
        currency: 'DZD',
        spentAt: DateTime(2026, 11, 1),
        warehouseName: 'Boutique Bab Ezzouar',
        paymentMethod: 'TRANSFER',
        reference: 'VIR-2231',
      ),
      ExpenseRecord(
        id: 'e2',
        label: 'Facture Sonelgaz',
        category: 'UTILITIES',
        amount: 8600,
        currency: 'DZD',
        spentAt: DateTime(2026, 11, 3),
        warehouseName: 'Boutique Bab Ezzouar',
        paymentMethod: 'CASH',
      ),
      ExpenseRecord(
        id: 'e3',
        label: 'Sacs et emballages',
        category: 'SUPPLIES',
        amount: 3200,
        currency: 'DZD',
        spentAt: DateTime(2026, 11, 5),
        warehouseName: 'Boutique Bab Ezzouar',
        paymentMethod: 'CASH',
      ),
    ];
    return _answer(
      (items: items, total: 56800.0, count: 3),
      (items: const <ExpenseRecord>[], total: 0.0, count: 0),
    );
  }

  @override
  Future<ExpenseSummaryResult> expenseSummary({
    required String warehouseId,
    DateTime? from,
    DateTime? to,
  }) => _answer(
    const ExpenseSummaryResult(total: 56800, count: 3),
    const ExpenseSummaryResult(total: 0, count: 0),
  );

  @override
  Future<ExpenseRecord> createExpense({
    required String warehouseId,
    required String label,
    required String category,
    required double amount,
    required DateTime spentAt,
    required String paymentMethod,
    String? reference,
    String? note,
  }) => Future.value(
    ExpenseRecord(
      id: 'e9',
      label: label,
      category: category,
      amount: amount,
      currency: 'DZD',
      spentAt: spentAt,
      warehouseName: '',
    ),
  );
}
