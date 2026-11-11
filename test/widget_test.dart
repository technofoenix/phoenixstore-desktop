import 'package:flutter_test/flutter_test.dart';

import 'package:phoenixstore_desktop/core/config/server_config.dart';
import 'package:phoenixstore_desktop/core/models/models.dart';
import 'package:phoenixstore_desktop/features/documents/document_service.dart';

void main() {
  test('document references use the type prefix', () {
    final date = DateTime(2026, 11, 6, 14, 30, 5);
    expect(
      DocumentService.referenceFor(DocumentType.facture, date),
      'FA-20261106-143005',
    );
    expect(
      DocumentService.referenceFor(DocumentType.bonLivraison, date),
      'BL-20261106-143005',
    );
  });

  test('sale payload maps totals and lines', () {
    final sale = SaleResult.fromJson({
      'id': 'sale-1',
      'reference': 'SALE-0001',
      'subtotal': '1000.00',
      'discount': '50',
      'tax': '20',
      'total': '970.00',
      'currency': 'DZD',
      'paymentMethod': 'CASH',
      'customerName': 'Boutique client',
      'soldAt': '2026-11-06T12:00:00.000Z',
      'warehouse': {'name': 'Boutique Centre'},
      'lines': [
        {
          'quantity': 2,
          'unitPrice': '500.00',
          'totalPrice': '1000.00',
          'product': {'sku': 'SKU-1', 'title': 'Widget'},
        },
      ],
    });

    expect(sale.total, 970);
    expect(sale.warehouseName, 'Boutique Centre');
    expect(sale.lines.single.title, 'Widget');
  });

  test('server URL normalization accepts pasted API prefixes', () {
    expect(
      ServerConfig.normalize('192.168.100.9:4000/'),
      'http://192.168.100.9:4000',
    );
    expect(
      ServerConfig.normalize('http://localhost:4000/api/v1/'),
      'http://localhost:4000',
    );
    expect(ServerConfig.normalize(''), '');
  });

  test('cart line totals respect quantity', () {
    const product = Product(
      id: 'p1',
      sku: 'SKU-1',
      title: 'Widget',
      barcode: '123',
      price: 250,
      currency: 'DZD',
      stock: 5,
    );
    final line = CartLine(product: product, quantity: 3);
    expect(line.total, 750);
  });

  test('every list kind builds a French PDF', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await DocumentStrings.load();
    for (final kind in ['sales', 'clients', 'stock', 'orders', 'charges']) {
      expect(DocumentStrings.get('list.$kind'), isNot('list.$kind'));
      expect(DocumentStrings.get('list.file.$kind'), isNot('list.file.$kind'));
      final doc = DocumentService.buildList(
        ListDocument(
          kind: kind,
          companyName: 'Superette El Nour',
          warehouseName: 'Boutique Bab Ezzouar',
          headers: ['A', 'B', 'C'],
          rows: [
            ['1', 'Huile Elio 1L', DocumentService.money(650)],
          ],
          numericColumns: const {2},
          filters: const ['Famille : Épicerie'],
          totals: [('Total', DocumentService.money(650))],
        ),
        DateTime(2026, 11, 8),
      );
      final bytes = await doc.save();
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    }
  });
}
