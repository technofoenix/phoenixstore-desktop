import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/session_store.dart';

class DesktopApi {
  DesktopApi(this._dio, this._store);

  final Dio _dio;
  final SessionStore _store;

  Map<String, dynamic> _data(Response response) =>
      Map<String, dynamic>.from((response.data as Map)['data'] as Map);

  Future<DesktopContext> context({String? warehouseId}) async {
    final response = await _dio.get(
      '/api/v1/desktop/context',
      queryParameters: {'warehouseId': ?warehouseId},
    );
    return DesktopContext.fromJson(_data(response));
  }

  Future<List<Product>> catalog({String? warehouseId, String? search}) async {
    final response = await _dio.get(
      '/api/v1/desktop/catalog',
      queryParameters: {
        'warehouseId': ?warehouseId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final rows = (response.data as Map)['data'] as List;
    return rows
        .map((row) => Product.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<Product> lookupBarcode(String barcode, {String? warehouseId}) async {
    final response = await _dio.get(
      '/api/v1/desktop/products/barcode/${Uri.encodeComponent(barcode)}',
      queryParameters: {'warehouseId': ?warehouseId},
    );
    return Product.fromJson(_data(response));
  }

  /// [clientReference] is the ticket's idempotency key: send the same value
  /// when retrying, and the API returns the already-recorded sale.
  Future<SaleResult> createSale({
    required String clientReference,
    required String warehouseId,
    required List<CartLine> lines,
    required String paymentMethod,
    required double discount,

    /// TVA rate in percent; the API derives the amount.
    required double taxRate,
    String? customerName,
    DocumentCustomer? customer,
    String? note,
    double? amountPaid,
    String? initialPaymentMethod,
    DateTime? dueDate,
  }) async {
    final response = await _dio.post(
      '/api/v1/desktop/sales',
      data: {
        'warehouseId': warehouseId,
        'paymentMethod': paymentMethod,
        if (customerName != null && customerName.trim().isNotEmpty)
          'customerName': customerName.trim(),
        if (customer != null) 'customer': customer.toDetailsJson(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'discount': discount,
        'taxRate': taxRate,
        'amountPaid': ?amountPaid,
        'initialPaymentMethod': ?initialPaymentMethod,
        'dueDate': ?dueDate?.toUtc().toIso8601String(),
        'deviceId': await _store.deviceId(),
        'clientReference': clientReference,
        'lines': lines
            .map(
              (line) => {
                'productId': line.product.id,
                'quantity': line.quantity,
                'unitPrice': line.product.price,
              },
            )
            .toList(),
      },
    );
    return SaleResult.fromJson(_data(response));
  }

  /// Records the end-customer details printed on a sale's facture.
  Future<SaleResult> updateSaleCustomer({
    required String saleId,
    required DocumentCustomer customer,
    String? warehouseId,
  }) async {
    final clean = customer.normalized;
    final response = await _dio.patch(
      '/api/v1/desktop/sales/$saleId/customer',
      queryParameters: {'warehouseId': ?warehouseId},
      data: {'customerName': clean.name, ...clean.toDetailsJson()},
    );
    return SaleResult.fromJson(_data(response));
  }

  /// Company settings printed as the seller on documents.
  Future<CompanySettings> company() async {
    final response = await _dio.get('/api/v1/desktop/company');
    return CompanySettings.fromJson(_data(response));
  }

  /// Raw bytes of an uploaded file (the company logo), or null.
  Future<Uint8List?> downloadBytes(String url) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      return data == null || data.isEmpty ? null : Uint8List.fromList(data);
    } catch (_) {
      return null;
    }
  }

  Future<SaleResult> recordSalePayment({
    required String saleId,
    required double amount,
    required String paymentMethod,
    String? reference,
    String? note,
  }) async {
    final response = await _dio.post(
      '/api/v1/desktop/sales/$saleId/payments',
      data: {
        'amount': amount,
        'paymentMethod': paymentMethod,
        if (reference != null && reference.trim().isNotEmpty)
          'reference': reference.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return SaleResult.fromJson(_data(response));
  }

  Future<List<StockItem>> stock({
    String? warehouseId,
    String? search,
    bool lowStock = false,
    int page = 1,
  }) async {
    final response = await _dio.get(
      '/api/v1/desktop/stock',
      queryParameters: {
        'page': page,
        'pageSize': 100,
        'warehouseId': ?warehouseId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (lowStock) 'lowStock': true,
      },
    );
    final data = _data(response);
    final rows = (data['items'] as List?) ?? const [];
    return rows
        .map((row) => StockItem.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Every stock line of the boutique (the API pages by 100).
  Future<List<StockItem>> allStock({
    String? warehouseId,
    String? search,
    bool lowStock = false,
  }) => _collect(
    (page) => stock(
      warehouseId: warehouseId,
      search: search,
      lowStock: lowStock,
      page: page,
    ),
  );

  Future<List<OrderResult>> orders({String? warehouseId}) async {
    final response = await _dio.get(
      '/api/v1/desktop/orders',
      queryParameters: {'warehouseId': ?warehouseId},
    );
    final rows = (response.data as Map)['data'] as List? ?? const [];
    return rows
        .map(
          (row) => OrderResult.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  /// Same idempotency contract as [createSale].
  Future<OrderResult> createOrder({
    required String clientReference,
    required String warehouseId,
    required List<CartLine> lines,
  }) async {
    final response = await _dio.post(
      '/api/v1/desktop/orders',
      queryParameters: {'warehouseId': warehouseId},
      data: {
        'clientReference': clientReference,
        'items': lines
            .map(
              (line) => {
                'productId': line.product.id,
                'quantity': line.quantity,
              },
            )
            .toList(),
      },
    );
    return OrderResult.fromJson(_data(response));
  }

  Future<List<SaleResult>> sales({
    String? warehouseId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _dio.get(
      '/api/v1/desktop/sales',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        'warehouseId': ?warehouseId,
      },
    );
    final data = _data(response);
    final rows = (data['items'] as List?) ?? const [];
    return rows
        .map(
          (row) => SaleResult.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  /// Every sale of the boutique, newest first (used for the client list).
  Future<List<SaleResult>> allSales({String? warehouseId}) => _collect(
    (page) => sales(warehouseId: warehouseId, page: page, pageSize: 100),
  );

  /// Reads pages of 100 until a short page; stops after 50 pages (5 000 rows).
  Future<List<T>> _collect<T>(Future<List<T>> Function(int page) fetch) async {
    final all = <T>[];
    for (var page = 1; page <= 50; page++) {
      final rows = await fetch(page);
      all.addAll(rows);
      if (rows.length < 100) break;
    }
    return all;
  }

  Future<({List<ExpenseRecord> items, double total, int count})> expenses({
    required String warehouseId,
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _dio.get(
      '/api/v1/desktop/expenses',
      queryParameters: {
        'warehouseId': warehouseId,
        'pageSize': 50,
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
      },
    );
    final data = _data(response);
    final rows = (data['items'] as List?) ?? const [];
    return (
      items: rows
          .map(
            (row) =>
                ExpenseRecord.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
      total: double.tryParse('${data['totalAmount'] ?? 0}') ?? 0,
      count: (data['total'] as num?)?.toInt() ?? 0,
    );
  }

  Future<ExpenseSummaryResult> expenseSummary({
    required String warehouseId,
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _dio.get(
      '/api/v1/desktop/expenses/summary',
      queryParameters: {
        'warehouseId': warehouseId,
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
      },
    );
    return ExpenseSummaryResult.fromJson(_data(response));
  }

  Future<ExpenseRecord> createExpense({
    required String warehouseId,
    required String label,
    required String category,
    required double amount,
    required DateTime spentAt,
    required String paymentMethod,
    String? reference,
    String? note,
  }) async {
    final response = await _dio.post(
      '/api/v1/desktop/expenses',
      queryParameters: {'warehouseId': warehouseId},
      data: {
        'label': label,
        'category': category,
        'amount': amount,
        'currency': 'DZD',
        'spentAt': spentAt.toUtc().toIso8601String(),
        'paymentMethod': paymentMethod,
        if (reference != null && reference.trim().isNotEmpty)
          'reference': reference.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return ExpenseRecord.fromJson(_data(response));
  }
}

final desktopApiProvider = Provider<DesktopApi>(
  (ref) => DesktopApi(ref.watch(dioProvider), ref.watch(sessionStoreProvider)),
);
