import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/error_reporter.dart';
import '../../core/i18n/formatters.dart';
import '../../core/i18n/labels.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import '../api/desktop_api.dart';
import '../documents/company_branding.dart';
import '../documents/document_service.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({
    super.key,
    required this.warehouseId,
    required this.warehouseName,
    this.companyName = '',
  });

  final String warehouseId;
  final String warehouseName;
  final String companyName;

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  List<OrderResult> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await ref
          .read(desktopApiProvider)
          .orders(warehouseId: widget.warehouseId);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = toApiException(error).message;
        _loading = false;
      });
    }
  }

  Future<void> _createOrder() async {
    final order = await showDialog<OrderResult>(
      context: context,
      builder: (_) => _OrderComposer(warehouseId: widget.warehouseId),
    );
    if (order != null) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('orders.sent', namedArgs: {'code': ltr(order.code)}),
            ),
          ),
        );
      }
    }
  }

  int _itemCount(OrderResult order) =>
      order.lines.fold<int>(0, (sum, line) => sum + line.quantity);

  Future<void> _openDetails(OrderResult order) async {
    final print = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _OrderDetailsDialog(order: order, tone: _statusTone(order.status)),
    );
    if (print == true) await _printOrder(order);
  }

  /// The boutique orders from the wholesaler: the wholesaler (company
  /// settings) is the issuer, the boutique the customer. Contact only.
  Future<void> _printOrder(OrderResult order) async {
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
          type: DocumentType.bonCommande,
          reference: order.code,
          date: order.createdAt,
          company: branding.company,
          logo: branding.logo,
          warehouseName: widget.warehouseName,
          customer: DocumentCustomer(name: widget.companyName),
          lines: [
            for (final line in order.lines)
              DocumentLine(
                title: line.title,
                sku: line.sku,
                quantity: line.quantity,
                unitPrice: line.unitPrice,
                totalPrice: line.totalPrice,
              ),
          ],
          subtotal: order.totalAmount,
          discount: 0,
          tax: 0,
          total: order.totalAmount,
          currency: branding.company.currency,
        ),
      ),
    );
  }

  Future<void> _printList() {
    final t = DocumentStrings.get;
    return ErrorReporter.guard(
      fallback: context.tr('errors.print'),
      context: 'print',
      () async => DocumentService.printList(
        ListDocument(
          // The company logo heads the list, as on invoices.
          logo: (await readCompanyBranding(
            ref,
            fallbackName: widget.companyName,
          )).logo,
          kind: 'orders',
          companyName: widget.companyName,
          warehouseName: widget.warehouseName,
          headers: [
            t('list.order'),
            t('list.date'),
            t('list.status'),
            t('list.items'),
            t('list.by'),
            t('list.total'),
          ],
          numericColumns: const {3, 5},
          rows: [
            for (final order in _orders)
              [
                order.code,
                DocumentService.dateTime(order.createdAt),
                DocumentService.code('orderStatus', order.status),
                '${_itemCount(order)}',
                order.createdByName ?? '—',
                DocumentService.money(order.totalAmount),
              ],
          ],
          totals: [
            (
              t('list.total'),
              DocumentService.money(
                _orders.fold<double>(0, (sum, o) => sum + o.totalAmount),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Tone _statusTone(String status) => switch (status) {
    'COMPLETED' || 'DELIVERED' => Tone.success,
    'CANCELLED' => Tone.danger,
    'APPROVED' || 'PROCESSING' || 'SHIPPED' => Tone.brand,
    _ => Tone.warning,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: context.tr('orders.title'),
          subtitle: _loading || _error != null
              ? widget.warehouseName
              : context.tr(
                  'orders.count',
                  namedArgs: {'count': Fmt.integer(context, _orders.length)},
                ),
          actions: [
            OutlinedButton.icon(
              key: const ValueKey('orders.printList'),
              onPressed: _loading || _orders.isEmpty ? null : _printList,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text(context.tr('common.printList')),
            ),
            IconButton.outlined(
              tooltip: context.tr('common.refresh'),
              onPressed: _loading ? null : _load,
              style: IconButton.styleFrom(
                side: const BorderSide(color: AppColors.line),
              ),
              icon: const Icon(Icons.refresh_rounded),
            ),
            FilledButton.icon(
              key: const ValueKey('orders.new'),
              onPressed: _createOrder,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.tr('orders.new')),
            ),
          ],
        ),
        Expanded(
          child: Panel(padding: EdgeInsets.zero, child: _buildBody()),
        ),
      ],
    );
  }

  Widget _buildBody() {
    final text = Theme.of(context).textTheme;
    if (_loading) return const LoadingList();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_orders.isEmpty) {
      return EmptyState(
        icon: Icons.local_shipping_outlined,
        title: context.tr('orders.empty'),
        message: context.tr('orders.emptyHint'),
      );
    }
    return AppTable(
      rowKeys: [for (final order in _orders) ValueKey('order-row-${order.id}')],
      onRowTap: (index) => _openDetails(_orders[index]),
      columns: [
        TableColumn(context.tr('orders.code'), flex: 3),
        TableColumn(context.tr('orders.created'), flex: 3),
        TableColumn(context.tr('orders.status'), flex: 3),
        TableColumn(
          context.tr('orders.items'),
          flex: 2,
          numeric: true,
          minWidth: 720,
        ),
        TableColumn(context.tr('orders.total'), flex: 3, numeric: true),
        TableColumn(context.tr('orders.by'), flex: 3, minWidth: 900),
      ],
      rows: [
        for (final order in _orders)
          [
            Text(ltr(order.code), style: text.labelLarge),
            Text(
              Fmt.dateTime(context, order.createdAt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
            StatusPill(
              orderStatusLabel(context, order.status),
              tone: _statusTone(order.status),
            ),
            Text(Fmt.integer(context, _itemCount(order))),
            Text(Fmt.money(context, order.totalAmount), style: text.labelLarge),
            Text(
              order.createdByName ?? context.tr('common.none'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
      ],
    );
  }
}

class _OrderComposer extends ConsumerStatefulWidget {
  const _OrderComposer({required this.warehouseId});

  final String warehouseId;

  @override
  ConsumerState<_OrderComposer> createState() => _OrderComposerState();
}

class _OrderComposerState extends ConsumerState<_OrderComposer> {
  /// Same key for every retry of this order, so a send that timed out but
  /// reached the server is not recorded twice.
  String _orderRef = const Uuid().v4();

  /// The last send got no clear answer: the order may exist server-side.
  bool _uncertain = false;

  /// Editing after an uncertain send makes a different order: new key.
  void _touch() {
    if (_uncertain) {
      _orderRef = const Uuid().v4();
      _uncertain = false;
      _error = null;
    }
  }

  final _search = TextEditingController();
  final List<CartLine> _lines = [];
  List<Product> _products = [];
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final products = await ref
          .read(desktopApiProvider)
          .catalog(warehouseId: widget.warehouseId, search: _search.text);
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = toApiException(error).message;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  /// What the main warehouse can still supply; null when unknown (the API
  /// still validates on send).
  int? _available(Product product) => product.sourceStock;

  void _showLimit(Product product, int max) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'orders.mainStockLimit',
              namedArgs: {'count': '$max', 'name': product.title},
            ),
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _add(Product product) {
    final index = _lines.indexWhere((line) => line.product.id == product.id);
    final current = index >= 0 ? _lines[index].quantity : 0;
    final max = _available(product);
    if (max != null && current >= max) {
      _showLimit(product, max);
      return;
    }
    setState(() {
      _touch();
      if (index >= 0) {
        _lines[index] = _lines[index].copyWith(
          quantity: _lines[index].quantity + 1,
        );
      } else {
        _lines.add(CartLine(product: product));
      }
    });
  }

  void _setQuantity(CartLine line, int quantity) {
    setState(() {
      _touch();
      final index = _lines.indexOf(line);
      if (index < 0) return;
      final max = _available(line.product);
      if (max != null && quantity > max) quantity = max;
      if (quantity <= 0) {
        _lines.removeAt(index);
      } else {
        _lines[index] = line.copyWith(quantity: quantity);
      }
    });
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final order = await ref
          .read(desktopApiProvider)
          .createOrder(
            clientReference: _orderRef,
            warehouseId: widget.warehouseId,
            lines: _lines,
          );
      if (!mounted) return;
      Navigator.of(context).pop(order);
    } catch (error) {
      final noAnswer =
          error is DioException &&
          (error.response == null || (error.response!.statusCode ?? 0) >= 500);
      // Main-warehouse stock moved since the list loaded: show fresh numbers.
      if (!noAnswer && toApiException(error).code == 'INSUFFICIENT_STOCK') {
        unawaited(_load());
      }
      if (mounted) {
        setState(() {
          _submitting = false;
          _uncertain = noAnswer;
          _error = noAnswer
              ? context.tr('errors.orderMaybeRecorded')
              : toApiException(error).message;
        });
      }
    }
  }

  double get _total =>
      _lines.fold(0, (sum, line) => sum + line.product.price * line.quantity);

  int get _count => _lines.fold(0, (sum, line) => sum + line.quantity);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(Space.xl),
      child: SizedBox(
        width: (size.width - 48).clamp(320, 1040),
        height: (size.height - 48).clamp(320, 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Space.xl,
                Space.lg,
                Space.sm,
                Space.lg,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(
                      context.tr('orders.composerTitle'),
                      style: text.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('common.close'),
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildCatalog(text)),
                  const VerticalDivider(width: 1, color: AppColors.line),
                  SizedBox(width: 360, child: _buildLines(text)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalog(TextTheme text) {
    Widget body;
    if (_loading) {
      body = const LoadingList(rows: 7);
    } else if (_loadError != null) {
      body = ErrorState(message: _loadError!, onRetry: _load);
    } else if (_products.isEmpty) {
      body = EmptyState(
        icon: Icons.search_off_rounded,
        title: context.tr('orders.composerNoProducts'),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
        itemCount: _products.length,
        separatorBuilder: (_, _) => const SizedBox(height: Space.xs),
        itemBuilder: (context, index) {
          final product = _products[index];
          final inOrder = _lines
              .where((line) => line.product.id == product.id)
              .fold(0, (sum, line) => sum + line.quantity);
          final available = _available(product);
          final soldOut = available != null && available <= 0;
          return Material(
            color: inOrder > 0 ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: soldOut ? null : () => _add(product),
              child: Opacity(
                opacity: soldOut ? 0.55 : 1,
                child: Padding(
                  padding: const EdgeInsets.all(Space.sm),
                  child: Row(
                    children: [
                      ProductThumb(imageUrl: product.imageUrl),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelLarge,
                            ),
                            Text(
                              '${ltr(product.sku)} · ${Fmt.money(context, product.price)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (available != null) ...[
                        StatusPill(
                          key: ValueKey('order-main-stock-${product.id}'),
                          soldOut
                              ? context.tr('orders.mainStockOut')
                              : context.tr(
                                  'orders.mainStock',
                                  namedArgs: {
                                    'count': Fmt.integer(context, available),
                                  },
                                ),
                          tone: soldOut
                              ? Tone.danger
                              : (available <= 5 ? Tone.warning : Tone.success),
                        ),
                        const SizedBox(width: Space.xs),
                      ],
                      if (inOrder > 0) ...[
                        StatusPill('×$inOrder', tone: Tone.brand),
                        const SizedBox(width: Space.xs),
                      ],
                      IconButton(
                        key: ValueKey('order-add-${product.id}'),
                        tooltip: context.tr(
                          'orders.add',
                          namedArgs: {'name': product.title},
                        ),
                        color: AppColors.primary,
                        onPressed: soldOut ? null : () => _add(product),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(Space.md),
          child: TextField(
            controller: _search,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.tr('orders.composerSearch'),
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _buildLines(TextTheme text) {
    return Container(
      color: AppColors.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: SectionLabel(
              context.tr('orders.composerLines'),
              trailing: StatusPill(
                context.plural('sell.items', _count),
                tone: _count == 0 ? Tone.neutral : Tone.brand,
              ),
            ),
          ),
          Expanded(
            child: _lines.isEmpty
                ? EmptyState(
                    icon: Icons.add_shopping_cart_rounded,
                    title: context.tr('orders.composerEmpty'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: Space.md),
                    itemCount: _lines.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Space.xs),
                    itemBuilder: (context, index) {
                      final line = _lines[index];
                      return Container(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          Space.md,
                          Space.xs,
                          Space.xs,
                          Space.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: Border.all(color: AppColors.line),
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
                                  Text(
                                    Fmt.money(
                                      context,
                                      line.product.price * line.quantity,
                                    ),
                                    style: text.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            QuantityField(
                              key: ValueKey('order-qty-${line.product.id}'),
                              fieldKey: ValueKey(
                                'order-qty-field-${line.product.id}',
                              ),
                              value: line.quantity,
                              max: _available(line.product),
                              onLimit: (max) => _showLimit(line.product, max),
                              onChanged: (n) => _setQuantity(line, n),
                              onRemove: () => _setQuantity(line, 0),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('orders.estimated'),
                        style: text.bodyMedium!.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                    Text(
                      Fmt.money(context, _total),
                      style: text.titleLarge!.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: Space.sm),
                  InlineMessage(_error!),
                ],
                const SizedBox(height: Space.md),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    key: const ValueKey('orders.send'),
                    onPressed: _lines.isEmpty || _submitting ? null : _submit,
                    icon: _submitting
                        ? const ButtonSpinner(color: AppColors.inkMuted)
                        : const DirIcon(Icons.send_rounded, size: 18),
                    label: Text(context.tr('orders.send')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDetailsDialog extends StatelessWidget {
  const _OrderDetailsDialog({required this.order, required this.tone});

  final OrderResult order;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppDialog(
      width: 760,
      icon: Icons.local_shipping_rounded,
      title: context.tr(
        'orders.detailsTitle',
        namedArgs: {'code': ltr(order.code)},
      ),
      subtitle: Fmt.dateTime(context, order.createdAt),
      body: Column(
        key: const ValueKey('order-details'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusPill(
              orderStatusLabel(context, order.status),
              tone: tone,
            ),
          ),
          const SizedBox(height: Space.md),
          if (order.createdByName != null)
            DetailRow(
              label: context.tr('orders.createdBy'),
              value: order.createdByName!,
            ),
          if (order.updatedByName != null)
            DetailRow(
              label: context.tr('orders.updatedBy'),
              value: order.updatedByName!,
            ),
          const SizedBox(height: Space.lg),
          Text(context.tr('orders.products'), style: text.titleSmall),
          const SizedBox(height: Space.sm),
          MiniTable(
            columns: [
              TableColumn(context.tr('orders.colProduct'), flex: 5),
              TableColumn(
                context.tr('orders.colOrdered'),
                flex: 2,
                numeric: true,
              ),
              TableColumn(
                context.tr('orders.colReceived'),
                flex: 2,
                numeric: true,
              ),
              TableColumn(context.tr('orders.colUnit'), flex: 2, numeric: true),
              TableColumn(
                context.tr('orders.colTotal'),
                flex: 2,
                numeric: true,
              ),
            ],
            rows: [
              for (final line in order.lines)
                [
                  '${line.title}\n${ltr(line.sku)}',
                  '${line.quantity}',
                  '${line.receivedQuantity}',
                  Fmt.money(context, line.unitPrice),
                  Fmt.money(context, line.totalPrice),
                ],
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('orders.total'),
                  style: text.titleMedium,
                ),
              ),
              Text(
                Fmt.money(context, order.totalAmount),
                style: text.titleMedium!.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
      secondary: TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: Text(context.tr('common.close')),
      ),
      primary: FilledButton.icon(
        key: const ValueKey('order-details.print'),
        onPressed: () => Navigator.of(context).pop(true),
        icon: const Icon(Icons.print_rounded, size: 18),
        label: Text(context.tr('orders.printOrder')),
      ),
    );
  }
}
