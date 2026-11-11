import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_reporter.dart';
import '../../core/i18n/formatters.dart';
import '../../core/i18n/labels.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import '../api/desktop_api.dart';
import '../documents/company_branding.dart';
import '../documents/customer_info_dialog.dart';
import '../documents/document_service.dart';
import 'cart_controller.dart';
import 'sale_details_dialog.dart';

const _paymentMethods = ['CASH', 'CARD', 'CREDIT', 'TRANSFER'];

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({
    super.key,
    required this.warehouseId,
    required this.warehouseName,
    required this.companyName,
  });

  final String warehouseId;
  final String warehouseName;
  final String companyName;

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _ScanFeedback {
  const _ScanFeedback(this.message, this.tone);

  final String message;
  final Tone tone;
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _barcode = TextEditingController();
  final _barcodeFocus = FocusNode();
  final _search = TextEditingController();
  // Seeded from the saved ticket in initState; edits go to [_cart].
  late final TextEditingController _customer;
  late final TextEditingController _discount;
  late final TextEditingController _taxRate;
  late final TextEditingController _amountPaid;

  List<Product> _products = [];
  bool _loadingProducts = true;
  String? _loadError;
  _ScanFeedback? _feedback;
  Timer? _feedbackTimer;
  Timer? _searchDebounce;
  String? _familyFilter;
  String? _categoryFilter;
  String _stockFilter = 'all';

  /// The ticket lives in [cartProvider], so it survives tab changes and
  /// restarts. Read with ref.watch in build, mutate through [_cart].
  CartController get _cart =>
      ref.read(cartProvider(widget.warehouseId).notifier);
  CartState get _ticket => ref.read(cartProvider(widget.warehouseId));

  @override
  void initState() {
    super.initState();
    final saved = _ticket;
    _customer = TextEditingController(text: saved.customerName);
    _discount = TextEditingController(text: saved.discountText);
    _taxRate = TextEditingController(text: saved.taxRateText);
    _amountPaid = TextEditingController(text: saved.amountPaidText);
    _loadProducts();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _barcodeFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _feedbackTimer?.cancel();
    _barcode.dispose();
    _barcodeFocus.dispose();
    _search.dispose();
    _customer.dispose();
    _discount.dispose();
    _taxRate.dispose();
    _amountPaid.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _loadError = null;
    });
    try {
      final products = await ref
          .read(desktopApiProvider)
          .catalog(warehouseId: widget.warehouseId, search: _search.text);
      if (!mounted) return;
      setState(() {
        _products = products;
        if (_familyFilter != null &&
            !products.any((product) => product.familyName == _familyFilter)) {
          _familyFilter = null;
        }
        if (_categoryFilter != null &&
            !products.any(
              (product) => product.categoryName == _categoryFilter,
            )) {
          _categoryFilter = null;
        }
        _loadingProducts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = toApiException(error).message;
        _loadingProducts = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadProducts);
  }

  List<String> get _familyOptions {
    final values = _products
        .map((product) => product.familyName)
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  List<String> get _categoryOptions {
    final values = _products
        .where(
          (product) =>
              _familyFilter == null || product.familyName == _familyFilter,
        )
        .map((product) => product.categoryName)
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  List<Product> get _filteredProducts => _products.where((product) {
    if (_familyFilter != null && product.familyName != _familyFilter) {
      return false;
    }
    if (_categoryFilter != null && product.categoryName != _categoryFilter) {
      return false;
    }
    if (_stockFilter == 'in' && product.stock <= 0) return false;
    if (_stockFilter == 'out' && product.stock > 0) return false;
    return true;
  }).toList();

  bool get _hasFilters =>
      _familyFilter != null || _categoryFilter != null || _stockFilter != 'all';

  void _clearFilters() {
    setState(() {
      _familyFilter = null;
      _categoryFilter = null;
      _stockFilter = 'all';
    });
  }

  void _refocusScanner() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _barcodeFocus.requestFocus();
    });
  }

  void _showFeedback(String message, Tone tone) {
    _feedbackTimer?.cancel();
    setState(() => _feedback = _ScanFeedback(message, tone));
    _feedbackTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _feedback = null);
    });
  }

  /// Adds one unit. Returns a warning when stock does not allow it.
  String? _addProduct(Product product) {
    final result = _cart.add(product);
    final warning = switch (result) {
      AddResult.added || AddResult.locked => null,
      AddResult.outOfStock => context.tr(
        'sell.outOfStock',
        namedArgs: {'name': product.title},
      ),
      AddResult.stockLimit => context.tr(
        'sell.onlyLeft',
        namedArgs: {'count': '${product.stock}', 'name': product.title},
      ),
    };
    if (warning != null) {
      _showFeedback(warning, Tone.warning);
    } else {
      _feedbackTimer?.cancel();
      setState(() => _feedback = null);
    }
    _refocusScanner();
    return warning;
  }

  Future<void> _scan() async {
    final code = _barcode.text.trim();
    _barcode.clear();
    if (code.isEmpty) {
      _refocusScanner();
      return;
    }
    try {
      final product = await ref
          .read(desktopApiProvider)
          .lookupBarcode(code, warehouseId: widget.warehouseId);
      if (!mounted) return;
      final warning = _addProduct(product);
      if (warning != null) {
        _showFeedback(warning, Tone.warning);
      } else {
        _showFeedback(
          context.tr('sell.added', namedArgs: {'name': product.title}),
          Tone.success,
        );
      }
    } catch (error) {
      _showFeedback(toApiException(error).message, Tone.danger);
    }
    _refocusScanner();
  }

  List<DocumentLine> _documentLines(CartState ticket) => ticket.lines
      .map(
        (line) => DocumentLine(
          title: line.product.title,
          sku: line.product.sku,
          quantity: line.quantity,
          unitPrice: line.product.price,
          totalPrice: line.total,
        ),
      )
      .toList();

  /// No server answer (timeout, dropped connection) or a server crash: the
  /// sale may have been recorded. Anything else is a clean rejection.
  static bool _isUncertain(Object error) {
    if (error is! DioException) return false;
    final status = error.response?.statusCode;
    return status == null || status >= 500;
  }

  Future<void> _checkout() async {
    // Locks the ticket; the same checkoutRef is reused on every retry.
    final ticket = _cart.beginCheckout();
    if (ticket == null) return;
    try {
      final sale = await ref
          .read(desktopApiProvider)
          .createSale(
            clientReference: ticket.checkoutRef,
            warehouseId: widget.warehouseId,
            lines: ticket.lines,
            paymentMethod: ticket.paymentMethod,
            discount: ticket.discount,
            taxRate: ticket.taxRate,
            customerName: ticket.customerName,
            customer: ticket.hasCustomerDetails ? ticket.customerDetails : null,
            amountPaid: ticket.isCredit ? ticket.amountPaid : null,
            initialPaymentMethod: ticket.isCredit ? 'CASH' : null,
            dueDate: ticket.isCredit ? ticket.dueDate : null,
          );
      _cart.checkoutSucceeded();
      if (!mounted) return;
      setState(() {
        _customer.clear();
        _discount.text = '0';
        // The new ticket starts with the company's default TVA rate.
        _taxRate.text = _ticket.taxRateText;
        _amountPaid.text = '0';
        _feedback = null;
      });
      await _showSaleCompleted(sale);
    } catch (error) {
      final uncertain = _isUncertain(error);
      if (uncertain) {
        _cart.checkoutUncertain();
      } else {
        _cart.checkoutRejected();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uncertain
                  ? context.tr('errors.saleMaybeRecorded')
                  : toApiException(error).message,
            ),
            backgroundColor: uncertain ? AppColors.warning : AppColors.danger,
            duration: Duration(seconds: uncertain ? 8 : 4),
          ),
        );
      }
    } finally {
      _refocusScanner();
    }
  }

  Future<void> _showSaleCompleted(SaleResult sale) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final text = Theme.of(dialogContext).textTheme;
        return AppDialog(
          width: 440,
          title: dialogContext.tr('sell.completedTitle'),
          subtitle: ltr(sale.reference),
          body: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.successSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 34,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: Space.lg),
              Text(
                Fmt.money(dialogContext, sale.total),
                style: text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.xs),
              StatusPill(
                paymentLabel(dialogContext, sale.paymentMethod),
                tone: Tone.neutral,
              ),
              if (sale.paymentStatus != 'PAID') ...[
                const SizedBox(height: Space.md),
                InlineMessage(
                  dialogContext.tr(
                    'sell.completedPaid',
                    namedArgs: {
                      'paid': Fmt.money(dialogContext, sale.amountPaid),
                      'balance': Fmt.money(dialogContext, sale.balanceDue),
                    },
                  ),
                  tone: Tone.warning,
                ),
              ],
            ],
          ),
          secondary: TextButton(
            key: const ValueKey('sale.new'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.tr('sell.newSale')),
          ),
          primary: FilledButton.icon(
            key: const ValueKey('sale.print'),
            autofocus: true,
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _printSale(sale);
            },
            icon: const Icon(Icons.print_rounded, size: 18),
            label: Text(dialogContext.tr('sell.printInvoice')),
          ),
        );
      },
    );
  }

  Future<void> _printSale(SaleResult sale) => printSaleInvoice(
    context,
    ref,
    sale,
    companyName: widget.companyName,
    warehouseName: widget.warehouseName,
    warehouseId: widget.warehouseId,
  );

  Future<void> _printCart(DocumentType type) async {
    var ticket = _ticket;
    if (ticket.isEmpty) return;
    if (type.showFiscal) {
      // A facture needs the customer's details and fiscal identifiers.
      final customer = await showCustomerInfoDialog(
        context,
        initial: ticket.customer,
      );
      if (customer == null || !mounted) return;
      _cart.setInvoiceCustomer(customer);
      _customer.text = customer.normalized.name ?? '';
      ticket = _ticket;
    }
    final now = DateTime.now();
    final reference = DocumentService.referenceFor(type, now);
    final fallbackError = context.tr('errors.print');
    final branding = await readCompanyBranding(
      ref,
      fallbackName: widget.companyName,
    );
    await ErrorReporter.guard(
      fallback: fallbackError,
      context: 'print',
      () => DocumentService.print(
        DocumentData(
          type: type,
          reference: reference,
          date: now,
          company: branding.company,
          logo: branding.logo,
          warehouseName: widget.warehouseName,
          customer: ticket.customer,
          lines: _documentLines(ticket),
          subtotal: ticket.subtotal,
          discount: ticket.discount,
          taxRate: ticket.taxRate,
          tax: ticket.tax,
          total: ticket.total,
          currency: ticket.lines.first.product.currency,
          paymentMethod: ticket.paymentMethod,
        ),
      ),
    );
    _refocusScanner();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _ticket.dueDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null && mounted) _cart.setDueDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final ticket = ref.watch(cartProvider(widget.warehouseId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: context.tr('sell.title'),
          subtitle: widget.warehouseName,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final ticketWidth = (constraints.maxWidth * 0.38).clamp(
                320.0,
                420.0,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildCatalogColumn(ticket)),
                  const SizedBox(width: Space.lg),
                  SizedBox(width: ticketWidth, child: _buildTicket(ticket)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCatalogColumn(CartState ticket) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      key: const ValueKey('sell.scanner'),
                      controller: _barcode,
                      focusNode: _barcodeFocus,
                      autofocus: true,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: context.tr('sell.scanner'),
                        hintText: context.tr('sell.scannerHint'),
                        prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                      ),
                      onSubmitted: (_) => _scan(),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      key: const ValueKey('sell.search'),
                      controller: _search,
                      decoration: InputDecoration(
                        labelText: context.tr('sell.search'),
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterMenu(
                    label: context.tr('sell.family'),
                    allLabel: context.tr('sell.allFamilies'),
                    value: _familyFilter,
                    options: _familyOptions,
                    onChanged: (value) => setState(() {
                      _familyFilter = value;
                      _categoryFilter = null;
                    }),
                  ),
                  FilterMenu(
                    label: context.tr('sell.category'),
                    allLabel: context.tr('sell.allCategories'),
                    value: _categoryFilter,
                    options: _categoryOptions,
                    onChanged: (value) =>
                        setState(() => _categoryFilter = value),
                  ),
                  ChoiceBar<String>(
                    value: _stockFilter,
                    keyPrefix: 'stock-',
                    options: [
                      ('all', context.tr('sell.stockAll')),
                      ('in', context.tr('sell.stockIn')),
                      ('out', context.tr('sell.stockOut')),
                    ],
                    onChanged: (value) => setState(() => _stockFilter = value),
                  ),
                  if (_hasFilters)
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                      label: Text(context.tr('sell.clearFilters')),
                    ),
                  if (!_loadingProducts && _loadError == null)
                    Text(
                      context.tr(
                        'sell.shown',
                        namedArgs: {
                          'shown': Fmt.integer(
                            context,
                            _filteredProducts.length,
                          ),
                          'total': Fmt.integer(context, _products.length),
                        },
                      ),
                      style: text.labelMedium!.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          child: _feedback == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: InlineMessage(
                    _feedback!.message,
                    tone: _feedback!.tone,
                  ),
                ),
        ),
        const SizedBox(height: Space.md),
        Expanded(child: _buildCatalog(ticket)),
      ],
    );
  }

  Widget _buildCatalog(CartState ticket) {
    if (_loadingProducts) return const LoadingGrid();
    if (_loadError != null) {
      return Panel(
        padding: EdgeInsets.zero,
        child: ErrorState(message: _loadError!, onRetry: _loadProducts),
      );
    }
    if (_products.isEmpty) {
      return Panel(
        padding: EdgeInsets.zero,
        child: _search.text.trim().isEmpty
            ? EmptyState(
                icon: Icons.inventory_2_outlined,
                title: context.tr('sell.noProducts'),
                message: context.tr('sell.noProductsHint'),
              )
            : EmptyState(
                icon: Icons.search_off_rounded,
                title: context.tr('sell.noMatch'),
                message: context.tr('sell.noMatchHint'),
              ),
      );
    }
    final filtered = _filteredProducts;
    if (filtered.isEmpty) {
      return Panel(
        padding: EdgeInsets.zero,
        child: EmptyState(
          icon: Icons.filter_alt_off_rounded,
          title: context.tr('sell.noMatch'),
          message: context.tr('sell.noMatchHint'),
          action: OutlinedButton(
            onPressed: _clearFilters,
            child: Text(context.tr('sell.clearFilters')),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 210).floor().clamp(1, 6);
        return GridView.builder(
          padding: const EdgeInsets.only(top: 2, bottom: Space.sm),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 196,
            crossAxisSpacing: Space.md,
            mainAxisSpacing: Space.md,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final product = filtered[index];
            final inTicket = ticket.quantityOf(product.id);
            return _ProductCard(
              key: ValueKey('product-${product.id}'),
              product: product,
              inTicket: inTicket,
              onTap: () => _addProduct(product),
            );
          },
        );
      },
    );
  }

  Widget _buildTicket(CartState ticket) {
    final text = Theme.of(context).textTheme;
    final isCredit = ticket.isCredit;
    final busy = ticket.submitting;

    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _customer,
          enabled: !busy,
          onChanged: _cart.setCustomer,
          decoration: InputDecoration(
            labelText: context.tr('sell.customer'),
            prefixIcon: const Icon(Icons.person_outline_rounded),
            isDense: true,
          ),
        ),
        const SizedBox(height: Space.md),
        Text(
          context.tr('sell.payment'),
          style: text.labelMedium!.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: Space.xs),
        _PaymentPicker(
          value: ticket.paymentMethod,
          onChanged: _cart.setPaymentMethod,
        ),
        if (isCredit) ...[
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: _amountPaid,
                  label: context.tr('sell.downPayment'),
                  onChanged: () => _cart.setAmountPaid(_amountPaid.text),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDueDate,
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(
                    ticket.dueDate == null
                        ? context.tr('sell.dueDate')
                        : Fmt.date(context, ticket.dueDate!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          _TotalRow(
            label: context.tr('sell.remaining'),
            value: Fmt.money(
              context,
              (ticket.total - ticket.amountPaid).clamp(0, double.infinity),
            ),
            tone: Tone.warning,
          ),
        ],
        const SizedBox(height: Space.xs),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const ValueKey('sell.adjustments'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: Space.sm),
            dense: true,
            initiallyExpanded: ticket.discount != 0,
            title: Text(context.tr('sell.adjustments'), style: text.labelLarge),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _NumberField(
                      controller: _discount,
                      label: context.tr('sell.discount'),
                      onChanged: () => _cart.setDiscount(_discount.text),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: _NumberField(
                      key: const ValueKey('sell.taxRate'),
                      controller: _taxRate,
                      label: context.tr('sell.taxRate'),
                      suffix: '%',
                      onChanged: () => _cart.setTaxRate(_taxRate.text),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final footer = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TotalRow(
          label: context.tr('sell.subtotal'),
          value: Fmt.money(context, ticket.subtotal),
        ),
        if (ticket.discount != 0)
          _TotalRow(
            label: context.tr('sell.discount'),
            value: '− ${Fmt.money(context, ticket.discount)}',
          ),
        if (ticket.tax != 0)
          _TotalRow(
            label: context.tr(
              'sell.taxLine',
              namedArgs: {'rate': formatRate(ticket.taxRate)},
            ),
            value: Fmt.money(context, ticket.tax),
          ),
        const SizedBox(height: Space.xs),
        Row(
          children: [
            Expanded(
              child: Text(context.tr('sell.total'), style: text.titleMedium),
            ),
            Text(
              Fmt.money(context, ticket.total),
              style: text.headlineSmall!.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  key: const ValueKey('sell.complete'),
                  onPressed: ticket.isEmpty || busy ? null : _checkout,
                  child: busy
                      ? const ButtonSpinner(color: AppColors.inkMuted)
                      : Text(
                          ticket.isEmpty
                              ? context.tr('sell.completeShort')
                              : context.tr(
                                  'sell.complete',
                                  namedArgs: {
                                    'total': Fmt.money(context, ticket.total),
                                  },
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ),
            const SizedBox(width: Space.sm),
            MenuAnchor(
              menuChildren: [
                for (final type in DocumentType.values)
                  MenuItemButton(
                    leadingIcon: const Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 18,
                    ),
                    onPressed: ticket.isEmpty ? null : () => _printCart(type),
                    child: Text(context.tr('documentType.${type.name}')),
                  ),
              ],
              builder: (context, controller, _) => SizedBox(
                width: 52,
                height: 52,
                child: IconButton.outlined(
                  key: const ValueKey('sell.documents'),
                  tooltip: context.tr('sell.documents'),
                  style: IconButton.styleFrom(
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                  ),
                  onPressed: ticket.isEmpty
                      ? null
                      : () => controller.isOpen
                            ? controller.close()
                            : controller.open(),
                  icon: const Icon(Icons.print_outlined),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Panel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Space.lg,
                Space.md,
                Space.lg,
                Space.md,
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_rounded, size: 20),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      context.tr('sell.ticket'),
                      style: text.titleMedium,
                    ),
                  ),
                  StatusPill(
                    context.plural('sell.items', ticket.itemCount),
                    tone: ticket.itemCount == 0 ? Tone.neutral : Tone.brand,
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(child: _buildLines(ticket)),
            const Divider(),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (constraints.maxHeight * 0.32).clamp(
                  96.0,
                  double.infinity,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.md,
                  Space.lg,
                  0,
                ),
                child: fields,
              ),
            ),
            const Divider(),
            Padding(padding: const EdgeInsets.all(Space.lg), child: footer),
          ],
        ),
      ),
    );
  }

  Widget _buildLines(CartState ticket) {
    final text = Theme.of(context).textTheme;
    if (ticket.isEmpty) {
      return EmptyState(
        icon: Icons.qr_code_scanner_rounded,
        title: context.tr('sell.emptyTicket'),
        message: context.tr('sell.emptyTicketHint'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      itemCount: ticket.lines.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.xs),
      itemBuilder: (context, index) {
        final line = ticket.lines[index];
        return Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Space.md,
            Space.sm,
            Space.xs,
            Space.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(Fmt.money(context, line.total), style: text.bodySmall),
                  ],
                ),
              ),
              QuantityField(
                key: ValueKey('qty-${line.product.id}'),
                fieldKey: ValueKey('qty-field-${line.product.id}'),
                value: line.quantity,
                max: line.product.stock,
                onChanged: (n) => _cart.setQuantity(line.product.id, n),
                onRemove: () => _cart.remove(line.product.id),
                onLimit: (max) => _showFeedback(
                  context.tr(
                    'sell.onlyLeft',
                    namedArgs: {'count': '$max', 'name': line.product.title},
                  ),
                  Tone.warning,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    super.key,
    required this.product,
    required this.inTicket,
    required this.onTap,
  });

  final Product product;
  final int inTicket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final outOfStock = product.stock <= 0;
    final low = !outOfStock && product.stock <= 5;
    final selected = inTicket > 0;

    return HoverLift(
      enabled: !outOfStock,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: outOfStock ? null : onTap,
          mouseCursor: outOfStock
              ? SystemMouseCursors.forbidden
              : SystemMouseCursors.click,
          child: Opacity(
            opacity: outOfStock ? 0.55 : 1,
            child: Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ProductThumb(
                        imageUrl: product.imageUrl,
                        width: double.infinity,
                        height: 76,
                      ),
                      if (selected)
                        PositionedDirectional(
                          top: 6,
                          end: 6,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 26),
                            height: 26,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(Radii.pill),
                            ),
                            child: Text(
                              '$inTicket',
                              style: text.labelMedium!.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(ltr(product.sku), style: text.bodySmall),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          Fmt.money(context, product.price),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall!.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.xs),
                      StatusPill(
                        outOfStock
                            ? context.tr('sell.soldOut')
                            : context.tr(
                                'sell.left',
                                namedArgs: {'count': '${product.stock}'},
                              ),
                        tone: outOfStock
                            ? Tone.danger
                            : low
                            ? Tone.warning
                            : Tone.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Payment method as four large toggles: one row on a wide ticket, two
/// rows on a narrow one, so labels are never cut.
class _PaymentPicker extends StatelessWidget {
  const _PaymentPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _icons = {
    'CASH': Icons.payments_outlined,
    'CARD': Icons.credit_card_rounded,
    'CREDIT': Icons.schedule_rounded,
    'TRANSFER': Icons.swap_horiz_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth >= 380 ? 4 : 2;
        final width = (constraints.maxWidth - Space.sm * (perRow - 1)) / perRow;
        return Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final method in _paymentMethods)
              SizedBox(
                width: width,
                height: 44,
                child: Material(
                  key: ValueKey('pay-$method'),
                  color: method == value ? AppColors.ink : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    side: BorderSide(
                      color: method == value ? AppColors.ink : AppColors.line,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(method),
                    child: Semantics(
                      selected: method == value,
                      button: true,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _icons[method],
                            size: 16,
                            color: method == value
                                ? Colors.white
                                : AppColors.inkMuted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              paymentLabel(context, method),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelMedium!.copyWith(
                                color: method == value
                                    ? Colors.white
                                    : AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;
  final String? suffix;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),

    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      suffixText: suffix,
    ),
    onChanged: (_) => onChanged(),
  );
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final Tone? tone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = tone == null ? AppColors.inkMuted : toneColors(tone!).fg;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: text.bodyMedium!.copyWith(color: color)),
          ),
          Text(value, style: text.labelLarge!.copyWith(color: color)),
        ],
      ),
    );
  }
}
