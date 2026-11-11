double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

Map<String, dynamic> _asMap(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

class SessionUser {
  const SessionUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.phoneNumber,
    required this.mobilePermissions,
    required this.desktopPermissions,
    required this.mustChangePassword,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? phoneNumber;
  final List<String> mobilePermissions;
  final List<String> desktopPermissions;
  final bool mustChangePassword;

  bool can(String permission) =>
      desktopPermissions.isEmpty || desktopPermissions.contains(permission);

  factory SessionUser.fromMe(Map<String, dynamic> data) {
    final user = _asMap(data['user']);
    final mobile = ((data['mobilePermissions'] as List?) ?? const [])
        .map((e) => '$e')
        .toList();
    final desktopRaw = data['desktopPermissions'];
    return SessionUser(
      id: user['id'] as String,
      fullName: user['fullName'] as String? ?? '',
      email: user['email'] as String? ?? '',
      role: user['role'] as String? ?? 'CLIENT',
      phoneNumber: user['phoneNumber'] as String?,
      mobilePermissions: mobile,
      // Older API builds only returned the mobile scope; fall back so a
      // terminal is not locked out while the server is being upgraded.
      desktopPermissions: desktopRaw is List
          ? desktopRaw.map((e) => '$e').toList()
          : mobile,
      mustChangePassword: user['mustChangePassword'] as bool? ?? false,
    );
  }
}

class WarehouseOption {
  const WarehouseOption({
    required this.id,
    required this.name,
    required this.code,
    required this.companyName,
  });

  final String id;
  final String name;
  final String? code;
  final String? companyName;

  factory WarehouseOption.fromJson(Map<String, dynamic> json) =>
      WarehouseOption(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        code: json['code'] as String?,
        companyName: json['companyName'] as String?,
      );
}

class PosContextInfo {
  const PosContextInfo({
    required this.clientProfileId,
    required this.tenantId,
    required this.warehouseId,
    required this.warehouseName,
    required this.companyName,
  });

  final String clientProfileId;
  final String tenantId;
  final String warehouseId;
  final String warehouseName;
  final String? companyName;

  factory PosContextInfo.fromJson(Map<String, dynamic> json) => PosContextInfo(
    clientProfileId: json['clientProfileId'] as String? ?? '',
    tenantId: json['tenantId'] as String? ?? '',
    warehouseId: json['warehouseId'] as String? ?? '',
    warehouseName: json['warehouseName'] as String? ?? '',
    companyName: json['companyName'] as String?,
  );
}

class DesktopContext {
  const DesktopContext({
    required this.userId,
    required this.fullName,
    required this.role,
    required this.warehouses,
    this.context,
    this.defaultTaxRate = 0,
  });

  final String userId;
  final String fullName;
  final String role;
  final List<WarehouseOption> warehouses;
  final PosContextInfo? context;

  /// Company TVA rate (%) pre-filled on new tickets.
  final double defaultTaxRate;

  factory DesktopContext.fromJson(Map<String, dynamic> json) {
    final identity = _asMap(json['identity']);
    return DesktopContext(
      userId: identity['userId'] as String? ?? '',
      fullName: identity['fullName'] as String? ?? '',
      role: identity['role'] as String? ?? '',
      warehouses: ((json['warehouses'] as List?) ?? const [])
          .map((row) => WarehouseOption.fromJson(_asMap(row)))
          .toList(),
      context: json['context'] == null
          ? null
          : PosContextInfo.fromJson(_asMap(json['context'])),
      defaultTaxRate: json['settings'] == null
          ? 0
          : _asDouble(_asMap(json['settings'])['defaultTaxRate']),
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.title,
    required this.barcode,
    required this.price,
    required this.currency,
    required this.stock,
    this.sourceStock,
    this.imageUrl,
    this.images = const [],
    this.subCategoryName,
    this.categoryName,
    this.familyName,
  });

  final String id;
  final String sku;
  final String title;
  final String? barcode;
  final double price;
  final String currency;

  /// Stock in this boutique.
  final int stock;

  /// Stock left in the wholesaler's main warehouse, i.e. what can still be
  /// ordered. Null when the API does not report it (no main warehouse).
  final int? sourceStock;
  final String? imageUrl;
  final List<String> images;
  final String? subCategoryName;
  final String? categoryName;
  final String? familyName;

  factory Product.fromJson(Map<String, dynamic> json) {
    final gallery = ((json['images'] as List?) ?? const [])
        .map((row) => _asMap(row))
        .where((row) => (row['url'] as String?)?.isNotEmpty == true)
        .map((row) => row['url'] as String)
        .toList();
    final primary = json['imageUrl'] as String?;
    final subCategory = json['subCategory'] == null
        ? null
        : _asMap(json['subCategory']);
    final category = subCategory?['category'] == null
        ? null
        : _asMap(subCategory!['category']);
    final family = category?['family'] == null
        ? null
        : _asMap(category!['family']);
    return Product(
      id: json['id'] as String,
      sku: json['sku'] as String? ?? '',
      title: json['title'] as String? ?? '',
      barcode: json['barcode'] as String?,
      price: _asDouble(json['price']),
      currency: json['currency'] as String? ?? 'DZD',
      stock: (json['posStock'] as num?)?.toInt() ?? 0,
      sourceStock: (json['sourceStock'] as num?)?.toInt(),
      imageUrl: primary != null && primary.isNotEmpty
          ? primary
          : (gallery.isNotEmpty ? gallery.first : null),
      images: gallery,
      subCategoryName: subCategory?['name'] as String?,
      categoryName: category?['name'] as String?,
      familyName: family?['name'] as String?,
    );
  }
}

class CartLine {
  const CartLine({required this.product, this.quantity = 1});

  final Product product;
  final int quantity;

  double get total => product.price * quantity;

  CartLine copyWith({int? quantity}) =>
      CartLine(product: product, quantity: quantity ?? this.quantity);

  /// Snapshot of what the ticket and the receipt need. Keys follow the API
  /// catalog shape so [Product.fromJson] reads them back.
  Map<String, dynamic> toJson() => {
    'quantity': quantity,
    'product': {
      'id': product.id,
      'sku': product.sku,
      'title': product.title,
      'barcode': product.barcode,
      'price': product.price,
      'currency': product.currency,
      'posStock': product.stock,
      'imageUrl': product.imageUrl,
    },
  };

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
    product: Product.fromJson(_asMap(json['product'])),
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
  );
}

class SaleLineResult {
  const SaleLineResult({
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

  factory SaleLineResult.fromJson(Map<String, dynamic> json) {
    final product = json['product'] == null
        ? <String, dynamic>{}
        : _asMap(json['product']);
    return SaleLineResult(
      title: product['title'] as String? ?? '',
      sku: product['sku'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: _asDouble(json['unitPrice']),
      totalPrice: _asDouble(json['totalPrice']),
    );
  }
}

class SalePaymentResult {
  const SalePaymentResult({
    required this.id,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.paidAt,
    this.reference,
    this.note,
    this.createdByName,
  });

  final String id;
  final double amount;
  final String currency;
  final String paymentMethod;
  final DateTime paidAt;
  final String? reference;
  final String? note;
  final String? createdByName;

  factory SalePaymentResult.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdBy'] == null
        ? null
        : _asMap(json['createdBy']);
    return SalePaymentResult(
      id: json['id'] as String? ?? '',
      amount: _asDouble(json['amount']),
      currency: json['currency'] as String? ?? 'DZD',
      paymentMethod: json['paymentMethod'] as String? ?? 'CASH',
      paidAt:
          DateTime.tryParse(json['paidAt'] as String? ?? '') ?? DateTime.now(),
      reference: json['reference'] as String?,
      note: json['note'] as String?,
      createdByName: createdBy?['fullName'] as String?,
    );
  }
}

class SaleResult {
  const SaleResult({
    required this.id,
    required this.reference,
    required this.subtotal,
    required this.discount,
    this.taxRate = 0,
    required this.tax,
    required this.total,
    required this.currency,
    required this.paymentMethod,
    required this.customerName,
    required this.warehouseName,
    required this.soldAt,
    required this.lines,
    required this.amountPaid,
    required this.balanceDue,
    required this.paymentStatus,
    this.dueDate,
    this.createdByName,
    this.updatedByName,
    this.payments = const [],
    this.customer = const DocumentCustomer(),
  });

  final String id;
  final String reference;
  final double subtotal;
  final double discount;

  /// TVA rate (%) applied to (subtotal - discount); [tax] is the amount.
  final double taxRate;
  final double tax;
  final double total;
  final String currency;
  final String paymentMethod;
  final String? customerName;
  final String warehouseName;
  final DateTime soldAt;
  final List<SaleLineResult> lines;
  final double amountPaid;
  final double balanceDue;
  final String paymentStatus;
  final DateTime? dueDate;
  final String? createdByName;
  final String? updatedByName;
  final List<SalePaymentResult> payments;

  /// End-customer details printed on the facture (name = [customerName]).
  final DocumentCustomer customer;

  bool get isFullyPaid => paymentStatus == 'PAID' || balanceDue <= 0;

  factory SaleResult.fromJson(Map<String, dynamic> json) {
    final warehouse = json['warehouse'] == null
        ? <String, dynamic>{}
        : _asMap(json['warehouse']);
    final createdBy = json['createdBy'] == null
        ? null
        : _asMap(json['createdBy']);
    final updatedBy = json['updatedBy'] == null
        ? null
        : _asMap(json['updatedBy']);
    return SaleResult(
      id: json['id'] as String,
      reference: json['reference'] as String? ?? '',
      subtotal: _asDouble(json['subtotal']),
      discount: _asDouble(json['discount']),
      taxRate: _asDouble(json['taxRate']),
      tax: _asDouble(json['tax']),
      total: _asDouble(json['total']),
      currency: json['currency'] as String? ?? 'DZD',
      paymentMethod: json['paymentMethod'] as String? ?? 'CASH',
      customerName: json['customerName'] as String?,
      warehouseName: warehouse['name'] as String? ?? '',
      soldAt:
          DateTime.tryParse(json['soldAt'] as String? ?? '') ?? DateTime.now(),
      lines: ((json['lines'] as List?) ?? const [])
          .map((row) => SaleLineResult.fromJson(_asMap(row)))
          .toList(),
      amountPaid: _asDouble(json['amountPaid']),
      balanceDue: _asDouble(json['balanceDue']),
      paymentStatus: json['paymentStatus'] as String? ?? 'PAID',
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.tryParse(json['dueDate'] as String),
      createdByName: createdBy?['fullName'] as String?,
      updatedByName: updatedBy?['fullName'] as String?,
      payments: ((json['payments'] as List?) ?? const [])
          .map((row) => SalePaymentResult.fromJson(_asMap(row)))
          .toList(),
      customer: DocumentCustomer(
        name: json['customerName'] as String?,
        address: json['customerAddress'] as String?,
        phone: json['customerPhone'] as String?,
        email: json['customerEmail'] as String?,
        nif: json['customerNif'] as String?,
        nis: json['customerNis'] as String?,
        rc: json['customerRc'] as String?,
        ai: json['customerAi'] as String?,
      ),
    );
  }
}

/// Customer printed on a document: contact details plus the Algerian fiscal
/// identifiers (NIF/NIS/RC/AI) required on a facture.
class DocumentCustomer {
  const DocumentCustomer({
    this.name,
    this.address,
    this.phone,
    this.email,
    this.nif,
    this.nis,
    this.rc,
    this.ai,
  });

  final String? name;
  final String? address;
  final String? phone;
  final String? email;
  final String? nif;
  final String? nis;
  final String? rc;
  final String? ai;

  static String? _clean(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Same customer with every field trimmed (blank -> null).
  DocumentCustomer get normalized => DocumentCustomer(
    name: _clean(name),
    address: _clean(address),
    phone: _clean(phone),
    email: _clean(email),
    nif: _clean(nif),
    nis: _clean(nis),
    rc: _clean(rc),
    ai: _clean(ai),
  );

  bool get hasName => _clean(name) != null;

  /// Name, address and NIF are mandatory on a facture.
  bool get isCompleteForInvoice =>
      _clean(name) != null && _clean(address) != null && _clean(nif) != null;

  DocumentCustomer copyWith({String? name}) => DocumentCustomer(
    name: name ?? this.name,
    address: address,
    phone: phone,
    email: email,
    nif: nif,
    nis: nis,
    rc: rc,
    ai: ai,
  );

  /// Payload of the API `customer` object (the name travels separately).
  Map<String, dynamic> toDetailsJson() {
    final clean = normalized;
    return {
      'address': clean.address,
      'phone': clean.phone,
      'email': clean.email,
      'nif': clean.nif,
      'nis': clean.nis,
      'rc': clean.rc,
      'ai': clean.ai,
    };
  }

  Map<String, dynamic> toJson() => {'name': name, ...toDetailsJson()};

  factory DocumentCustomer.fromJson(Map<String, dynamic> json) =>
      DocumentCustomer(
        name: json['name'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        nif: json['nif'] as String?,
        nis: json['nis'] as String?,
        rc: json['rc'] as String?,
        ai: json['ai'] as String?,
      );

  @override
  bool operator ==(Object other) {
    if (other is! DocumentCustomer) return false;
    final a = normalized;
    final b = other.normalized;
    return a.name == b.name &&
        a.address == b.address &&
        a.phone == b.phone &&
        a.email == b.email &&
        a.nif == b.nif &&
        a.nis == b.nis &&
        a.rc == b.rc &&
        a.ai == b.ai;
  }

  @override
  int get hashCode {
    final c = normalized;
    return Object.hash(
      c.name,
      c.address,
      c.phone,
      c.email,
      c.nif,
      c.nis,
      c.rc,
      c.ai,
    );
  }
}

/// The tenant's company settings, printed as the seller on documents.
class CompanySettings {
  const CompanySettings({
    required this.name,
    this.legalName,
    this.phone,
    this.email,
    this.website,
    this.address,
    this.city,
    this.postalCode,
    this.country,
    this.nif,
    this.nis,
    this.rc,
    this.ai,
    this.bankName,
    this.bankAccount,
    this.currency = 'DZD',
    this.paymentTerms,
    this.invoiceFooter,
    this.logoUrl,
  });

  final String name;
  final String? legalName;
  final String? phone;
  final String? email;
  final String? website;
  final String? address;
  final String? city;
  final String? postalCode;
  final String? country;
  final String? nif;
  final String? nis;
  final String? rc;
  final String? ai;
  final String? bankName;
  final String? bankAccount;
  final String currency;
  final String? paymentTerms;
  final String? invoiceFooter;
  final String? logoUrl;

  factory CompanySettings.fromJson(Map<String, dynamic> json) =>
      CompanySettings(
        name: json['name'] as String? ?? '',
        legalName: json['legalName'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        website: json['website'] as String?,
        address: json['address'] as String?,
        city: json['city'] as String?,
        postalCode: json['postalCode'] as String?,
        country: json['country'] as String?,
        nif: json['nif'] as String?,
        nis: json['nis'] as String?,
        rc: json['rc'] as String?,
        ai: json['ai'] as String?,
        bankName: json['bankName'] as String?,
        bankAccount: json['bankAccount'] as String?,
        currency: json['currency'] as String? ?? 'DZD',
        paymentTerms: json['paymentTerms'] as String?,
        invoiceFooter: json['invoiceFooter'] as String?,
        logoUrl: json['logoUrl'] as String?,
      );
}

class StockItem {
  const StockItem({
    required this.product,
    required this.quantity,
    required this.reorderLevel,
    required this.updatedAt,
  });

  final Product product;
  final int quantity;
  final int reorderLevel;
  final DateTime updatedAt;

  bool get isLowStock => quantity <= reorderLevel;

  factory StockItem.fromJson(Map<String, dynamic> json) => StockItem(
    product: Product.fromJson(_asMap(json['product'])),
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    reorderLevel: (json['reorderLevel'] as num?)?.toInt() ?? 0,
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class OrderLineResult {
  const OrderLineResult({
    required this.title,
    required this.sku,
    required this.quantity,
    required this.receivedQuantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  final String title;
  final String sku;
  final int quantity;
  final int receivedQuantity;
  final double unitPrice;
  final double totalPrice;

  factory OrderLineResult.fromJson(Map<String, dynamic> json) {
    final product = json['product'] == null
        ? <String, dynamic>{}
        : _asMap(json['product']);
    return OrderLineResult(
      title: product['title'] as String? ?? '',
      sku: product['sku'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      receivedQuantity: (json['receivedQuantity'] as num?)?.toInt() ?? 0,
      unitPrice: _asDouble(json['unitPrice']),
      totalPrice: _asDouble(json['totalPrice']),
    );
  }
}

class OrderResult {
  const OrderResult({
    required this.id,
    required this.code,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    required this.lines,
    this.createdByName,
    this.updatedByName,
  });

  final String id;
  final String code;
  final String status;
  final double totalAmount;
  final DateTime createdAt;
  final List<OrderLineResult> lines;
  final String? createdByName;
  final String? updatedByName;

  factory OrderResult.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdBy'] == null
        ? null
        : _asMap(json['createdBy']);
    final updatedBy = json['updatedBy'] == null
        ? null
        : _asMap(json['updatedBy']);
    return OrderResult(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      totalAmount: _asDouble(json['totalAmount']),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      lines: ((json['lines'] as List?) ?? const [])
          .map((row) => OrderLineResult.fromJson(_asMap(row)))
          .toList(),
      createdByName: createdBy?['fullName'] as String?,
      updatedByName: updatedBy?['fullName'] as String?,
    );
  }
}

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.label,
    required this.category,
    required this.amount,
    required this.currency,
    required this.spentAt,
    required this.warehouseName,
    this.paymentMethod,
    this.reference,
    this.note,
  });

  final String id;
  final String label;
  final String category;
  final double amount;
  final String currency;
  final DateTime spentAt;
  final String warehouseName;
  final String? paymentMethod;
  final String? reference;
  final String? note;

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) {
    final warehouse = json['warehouse'] == null
        ? <String, dynamic>{}
        : _asMap(json['warehouse']);
    return ExpenseRecord(
      id: json['id'] as String,
      label: json['label'] as String? ?? '',
      category: json['category'] as String? ?? 'OTHER',
      amount: _asDouble(json['amount']),
      currency: json['currency'] as String? ?? 'DZD',
      spentAt:
          DateTime.tryParse(json['spentAt'] as String? ?? '') ?? DateTime.now(),
      warehouseName: warehouse['name'] as String? ?? '',
      paymentMethod: json['paymentMethod'] as String?,
      reference: json['reference'] as String?,
      note: json['note'] as String?,
    );
  }
}

class ExpenseSummaryResult {
  const ExpenseSummaryResult({required this.total, required this.count});

  final double total;
  final int count;

  factory ExpenseSummaryResult.fromJson(Map<String, dynamic> json) =>
      ExpenseSummaryResult(
        total: _asDouble(json['total']),
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}
