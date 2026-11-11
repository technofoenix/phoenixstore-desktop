import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phoenixstore_desktop/core/models/models.dart';
import 'package:phoenixstore_desktop/features/documents/amount_in_words.dart';
import 'package:phoenixstore_desktop/features/documents/document_service.dart';

const _company = CompanySettings(
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
  bankName: 'BNA',
  bankAccount: '00100123012345678901',
  paymentTerms: 'Paiement à réception',
  invoiceFooter: 'Merci pour votre confiance.',
);

const _customer = DocumentCustomer(
  name: 'SARL Client',
  address: 'Bab Ezzouar, Alger',
  phone: '0770 11 22 33',
  nif: '002016091234567',
  rc: '16/00-7654321B19',
);

DocumentData _data(DocumentType type) => DocumentData(
  type: type,
  reference: 'FA-0001',
  date: DateTime(2026, 11, 8, 10, 30),
  company: _company,
  warehouseName: 'Boutique centre',
  customer: _customer,
  lines: const [
    DocumentLine(
      title: 'Samsung Galaxy A55',
      sku: 'SKU-001',
      quantity: 2,
      unitPrice: 50000,
      totalPrice: 100000,
    ),
    DocumentLine(
      title: 'Chargeur 25W',
      sku: 'SKU-002',
      quantity: 3,
      unitPrice: 2500,
      totalPrice: 7500,
    ),
  ],
  subtotal: 107500,
  discount: 500,
  tax: 0,
  total: 107000,
  currency: 'DZD',
  paymentMethod: 'CASH',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => DocumentStrings.load());

  group('amountInWordsFr', () {
    test('spells French numbers with the traditional rules', () {
      expect(integerToFrenchWords(21), 'vingt et un');
      expect(integerToFrenchWords(71), 'soixante et onze');
      expect(integerToFrenchWords(80), 'quatre-vingts');
      expect(integerToFrenchWords(200000), 'deux cent mille');
      expect(integerToFrenchWords(2000000), 'deux millions');
    });

    test('writes the amount with its currency and centimes', () {
      expect(
        amountInWordsFr(107000, 'DZD'),
        'Cent sept mille dinars algériens',
      );
      expect(
        amountInWordsFr(1250.5, 'DZD'),
        'Mille deux cent cinquante dinars algériens et cinquante centimes',
      );
    });
  });

  group('document rules', () {
    test('only the facture carries fiscal identifiers and the stamp', () {
      expect(DocumentType.facture.showFiscal, isTrue);
      expect(DocumentType.factureProforma.showFiscal, isFalse);
      expect(DocumentType.bonCommande.showFiscal, isFalse);
      expect(DocumentType.bonLivraison.showFiscal, isFalse);
      expect(DocumentType.bonLivraison.showPrices, isFalse);
    });

    test('a facture customer needs name, address and NIF', () {
      expect(_customer.isCompleteForInvoice, isTrue);
      expect(
        const DocumentCustomer(name: 'X', address: 'Y').isCompleteForInvoice,
        isFalse,
      );
      expect(
        const DocumentCustomer(name: ' X ', nif: ''),
        const DocumentCustomer(name: 'X'),
      );
    });

    test('builds every document type', () async {
      final out = Platform.environment['DOCUMENT_PREVIEW_DIR'];
      for (final type in DocumentType.values) {
        final bytes = await DocumentService.buildDocument(_data(type)).save();
        expect(bytes, isNotEmpty);
        if (out != null) {
          File('$out/desktop-${type.name}.pdf').writeAsBytesSync(bytes);
        }
      }
    });
  });
}
