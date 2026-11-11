import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/formatters.dart';
import '../../core/i18n/labels.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import '../api/desktop_api.dart';
import '../documents/company_branding.dart';
import '../documents/document_service.dart';
import '../sales/sale_details_dialog.dart';
import '../sales/sales_history_screen.dart';

/// A boutique customer, built from the names written on sales (the API has
/// no customer record for boutique buyers). Walk-in sales are left out.
class ClientSummary {
  ClientSummary(this.name);

  final String name;
  final List<SaleResult> sales = [];

  int get count => sales.length;
  double get total => sales.fold(0, (sum, s) => sum + s.total);
  double get paid => sales.fold(0, (sum, s) => sum + s.amountPaid);
  double get balance => sales.fold(0, (sum, s) => sum + s.balanceDue);
  DateTime get lastPurchase =>
      sales.map((s) => s.soldAt).reduce((a, b) => a.isAfter(b) ? a : b);

  /// Groups sales by customer name, ignoring case and extra spaces.
  static List<ClientSummary> fromSales(List<SaleResult> sales) {
    final byKey = <String, ClientSummary>{};
    for (final sale in sales) {
      final name = (sale.customerName ?? '').trim().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      if (name.isEmpty) continue;
      byKey
          .putIfAbsent(name.toLowerCase(), () => ClientSummary(name))
          .sales
          .add(sale);
    }
    final list = byKey.values.toList()
      ..sort((a, b) => b.lastPurchase.compareTo(a.lastPurchase));
    for (final client in list) {
      client.sales.sort((a, b) => b.soldAt.compareTo(a.soldAt));
    }
    return list;
  }
}

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({
    super.key,
    required this.warehouseId,
    required this.warehouseName,
    required this.companyName,
  });

  final String warehouseId;
  final String warehouseName;
  final String companyName;

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _search = TextEditingController();
  List<ClientSummary> _clients = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sales = await ref
          .read(desktopApiProvider)
          .allSales(warehouseId: widget.warehouseId);
      if (!mounted) return;
      setState(() {
        _clients = ClientSummary.fromSales(sales);
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

  List<ClientSummary> get _visible {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _clients;
    return _clients
        .where((client) => client.name.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _openClient(ClientSummary client) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ClientDialog(
        client: client,
        companyName: widget.companyName,
        warehouseName: widget.warehouseName,
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _printList() async {
    final t = DocumentStrings.get;
    final clients = _visible;
    // The company logo heads the list, as on invoices.
    final branding = await readCompanyBranding(
      ref,
      fallbackName: widget.companyName,
    );
    return DocumentService.printList(
      ListDocument(
        logo: branding.logo,
        kind: 'clients',
        companyName: widget.companyName,
        warehouseName: widget.warehouseName,
        filters: [
          if (_search.text.trim().isNotEmpty)
            t('list.search', {'text': _search.text.trim()}),
        ],
        headers: [
          t('list.customer'),
          t('list.salesCount'),
          t('list.lastPurchase'),
          t('list.total'),
          t('list.paid'),
          t('list.balance'),
        ],
        numericColumns: const {1, 3, 4, 5},
        rows: [
          for (final client in clients)
            [
              client.name,
              '${client.count}',
              DocumentService.date(client.lastPurchase),
              DocumentService.money(client.total),
              DocumentService.money(client.paid),
              DocumentService.money(client.balance),
            ],
        ],
        totals: [
          (
            t('list.total'),
            DocumentService.money(
              clients.fold<double>(0, (sum, c) => sum + c.total),
            ),
          ),
          (
            t('list.balance'),
            DocumentService.money(
              clients.fold<double>(0, (sum, c) => sum + c.balance),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_loading && _error == null;
    final clients = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: context.tr('clients.title'),
          subtitle: ready
              ? context.tr(
                  'clients.count',
                  namedArgs: {'count': Fmt.integer(context, _clients.length)},
                )
              : widget.warehouseName,
          actions: [
            OutlinedButton.icon(
              key: const ValueKey('clients.printList'),
              onPressed: !ready || clients.isEmpty ? null : _printList,
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
          ],
        ),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: context.tr('clients.clients'),
                value: ready ? Fmt.integer(context, _clients.length) : '…',
                icon: Icons.people_alt_outlined,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: StatTile(
                label: context.tr('clients.sold'),
                value: ready
                    ? Fmt.money(
                        context,
                        _clients.fold<double>(0, (sum, c) => sum + c.total),
                      )
                    : '…',
                icon: Icons.shopping_bag_outlined,
                tone: Tone.brand,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: StatTile(
                label: context.tr('clients.owed'),
                value: ready
                    ? Fmt.money(
                        context,
                        _clients.fold<double>(0, (sum, c) => sum + c.balance),
                      )
                    : '…',
                icon: Icons.schedule_rounded,
                tone: Tone.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        Expanded(
          child: Panel(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SizedBox(
                      width: 360,
                      child: TextField(
                        key: const ValueKey('clients.search'),
                        controller: _search,
                        decoration: InputDecoration(
                          labelText: context.tr('clients.search'),
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                ),
                const Divider(),
                Expanded(child: _buildBody(clients)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(List<ClientSummary> clients) {
    final text = Theme.of(context).textTheme;
    if (_loading) return const LoadingList();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (clients.isEmpty) {
      final searching = _search.text.trim().isNotEmpty;
      return EmptyState(
        icon: searching ? Icons.search_off_rounded : Icons.people_alt_outlined,
        title: context.tr(searching ? 'clients.noMatch' : 'clients.empty'),
        message: context.tr(
          searching ? 'clients.noMatchHint' : 'clients.emptyHint',
        ),
      );
    }
    return AppTable(
      rowKeys: [
        for (final client in clients) ValueKey('client-row-${client.name}'),
      ],
      onRowTap: (index) => _openClient(clients[index]),
      columns: [
        TableColumn(context.tr('clients.colName'), flex: 4),
        TableColumn(context.tr('clients.colSales'), flex: 1, numeric: true),
        TableColumn(context.tr('clients.colTotal'), flex: 3, numeric: true),
        TableColumn(
          context.tr('clients.colPaid'),
          flex: 3,
          numeric: true,
          minWidth: 900,
        ),
        TableColumn(context.tr('clients.colBalance'), flex: 3, numeric: true),
        TableColumn(context.tr('clients.colLast'), flex: 3, minWidth: 720),
      ],
      rows: [
        for (final client in clients)
          [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.surfaceMuted,
                  child: Text(
                    client.name.characters.first.toUpperCase(),
                    style: text.labelMedium,
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    client.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge,
                  ),
                ),
              ],
            ),
            Text(Fmt.integer(context, client.count)),
            Text(Fmt.money(context, client.total), style: text.labelLarge),
            Text(Fmt.money(context, client.paid)),
            client.balance > 0
                ? StatusPill(
                    Fmt.money(context, client.balance),
                    tone: Tone.danger,
                  )
                : Text(
                    context.tr('common.none'),
                    style: text.bodyMedium!.copyWith(color: AppColors.inkMuted),
                  ),
            Text(
              Fmt.date(context, client.lastPurchase),
              maxLines: 1,
              style: text.bodySmall,
            ),
          ],
      ],
    );
  }
}

/// One client: totals and every sale, each opening its details.
class _ClientDialog extends ConsumerStatefulWidget {
  const _ClientDialog({
    required this.client,
    required this.companyName,
    required this.warehouseName,
  });

  final ClientSummary client;
  final String companyName;
  final String warehouseName;

  @override
  ConsumerState<_ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends ConsumerState<_ClientDialog> {
  bool _changed = false;

  Future<void> _openSale(SaleResult sale) async {
    final action = await showSaleDetails(context, sale);
    if (!mounted) return;
    switch (action) {
      case SaleAction.print:
        final updated = await printSaleInvoice(
          context,
          ref,
          sale,
          companyName: widget.companyName,
          warehouseName: widget.warehouseName,
        );
        if (updated != null && updated.customer != sale.customer) {
          _changed = true;
        }
      case SaleAction.recordPayment:
        final result = await showDialog<({double amount, String method})>(
          context: context,
          builder: (_) => RecordPaymentDialog(sale: sale),
        );
        if (result == null || !mounted) return;
        try {
          await ref
              .read(desktopApiProvider)
              .recordSalePayment(
                saleId: sale.id,
                amount: result.amount,
                paymentMethod: result.method,
              );
          _changed = true;
          if (mounted) Navigator.of(context).pop(true);
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(toApiException(error).message),
                backgroundColor: AppColors.danger,
              ),
            );
          }
        }
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final client = widget.client;
    Widget figure(String label, num value, Tone tone) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: toneColors(tone).bg,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: text.bodySmall!.copyWith(color: toneColors(tone).fg),
            ),
            const SizedBox(height: 2),
            Text(
              Fmt.money(context, value),
              style: text.titleMedium!.copyWith(color: toneColors(tone).fg),
            ),
          ],
        ),
      ),
    );

    return AppDialog(
      width: 720,
      icon: Icons.person_rounded,
      title: client.name,
      subtitle: context.tr(
        'clients.detailsSubtitle',
        namedArgs: {
          'count': Fmt.integer(context, client.count),
          'date': Fmt.date(context, client.lastPurchase),
        },
      ),
      onClose: () => Navigator.of(context).pop(_changed),
      body: Column(
        key: const ValueKey('client-details'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              figure(
                context.tr('clients.colTotal'),
                client.total,
                Tone.neutral,
              ),
              const SizedBox(width: Space.sm),
              figure(context.tr('clients.colPaid'), client.paid, Tone.success),
              const SizedBox(width: Space.sm),
              figure(
                context.tr('clients.colBalance'),
                client.balance,
                client.balance > 0 ? Tone.danger : Tone.neutral,
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Text(context.tr('clients.sales'), style: text.titleSmall),
          const SizedBox(height: Space.sm),
          for (final sale in client.sales)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Material(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(Radii.md),
                child: InkWell(
                  key: ValueKey('client-sale-${sale.id}'),
                  borderRadius: BorderRadius.circular(Radii.md),
                  onTap: () => _openSale(sale),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.md,
                      vertical: Space.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ltr(sale.reference), style: text.labelLarge),
                              Text(
                                Fmt.dateTime(context, sale.soldAt),
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: StatusPill(
                              paymentStatusLabel(context, sale.paymentStatus),
                              tone: saleStatusTone(sale),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            Fmt.money(context, sale.total),
                            textAlign: TextAlign.end,
                            style: text.labelLarge,
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        const DirIcon(
                          Icons.chevron_right_rounded,
                          color: AppColors.inkMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      secondary: TextButton(
        onPressed: () => Navigator.of(context).pop(_changed),
        child: Text(context.tr('common.close')),
      ),
    );
  }
}
