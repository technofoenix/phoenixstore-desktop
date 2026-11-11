import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'sale_details_dialog.dart';

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({
    super.key,
    required this.warehouseId,
    required this.warehouseName,
    required this.companyName,
    this.onStartSale,
  });

  final String warehouseId;
  final String warehouseName;
  final String companyName;
  final VoidCallback? onStartSale;

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  List<SaleResult> _sales = [];
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
      final sales = await ref
          .read(desktopApiProvider)
          .sales(warehouseId: widget.warehouseId);
      if (!mounted) return;
      setState(() {
        _sales = sales;
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

  Future<void> _print(SaleResult sale) async {
    final updated = await printSaleInvoice(
      context,
      ref,
      sale,
      companyName: widget.companyName,
      warehouseName: widget.warehouseName,
      warehouseId: widget.warehouseId,
    );
    // Customer details may have changed: refresh the list.
    if (updated != null && updated.customer != sale.customer && mounted) {
      await _load();
    }
  }

  Future<void> _recordPayment(SaleResult sale) async {
    final result = await showDialog<({double amount, String method})>(
      context: context,
      builder: (_) => RecordPaymentDialog(sale: sale),
    );
    if (result == null) return;
    try {
      await ref
          .read(desktopApiProvider)
          .recordSalePayment(
            saleId: sale.id,
            amount: result.amount,
            paymentMethod: result.method,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'history.payDone',
                namedArgs: {'reference': ltr(sale.reference)},
              ),
            ),
          ),
        );
      }
      await _load();
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
  }

  Future<void> _openDetails(SaleResult sale) async {
    final action = await showSaleDetails(context, sale);
    switch (action) {
      case SaleAction.print:
        await _print(sale);
      case SaleAction.recordPayment:
        await _recordPayment(sale);
      case null:
        break;
    }
  }

  Future<void> _printList() async {
    final t = DocumentStrings.get;
    // The company logo heads the list, as on invoices.
    final branding = await readCompanyBranding(
      ref,
      fallbackName: widget.companyName,
    );
    return DocumentService.printList(
      ListDocument(
        logo: branding.logo,
        kind: 'sales',
        companyName: widget.companyName,
        warehouseName: widget.warehouseName,
        headers: [
          t('colReference'),
          t('list.date'),
          t('list.customer'),
          t('list.payment'),
          t('list.status'),
          t('list.items'),
          t('list.balance'),
          t('list.total'),
        ],
        numericColumns: const {5, 6, 7},
        rows: [
          for (final sale in _sales)
            [
              sale.reference,
              DocumentService.dateTime(sale.soldAt),
              (sale.customerName ?? '').trim().isEmpty
                  ? t('walkIn')
                  : sale.customerName!,
              DocumentService.code('payment', sale.paymentMethod),
              DocumentService.code('paymentStatus', sale.paymentStatus),
              '${sale.lines.fold<int>(0, (sum, l) => sum + l.quantity)}',
              DocumentService.money(sale.balanceDue),
              DocumentService.money(sale.total),
            ],
        ],
        totals: [
          (
            t('list.total'),
            DocumentService.money(
              _sales.fold<double>(0, (sum, s) => sum + s.total),
            ),
          ),
          (
            t('list.balance'),
            DocumentService.money(
              _sales.fold<double>(0, (sum, s) => sum + s.balanceDue),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: context.tr('history.title'),
          subtitle: _loading || _error != null
              ? widget.warehouseName
              : context.tr(
                  'history.count',
                  namedArgs: {'count': Fmt.integer(context, _sales.length)},
                ),
          actions: [
            OutlinedButton.icon(
              key: const ValueKey('history.printList'),
              onPressed: _loading || _sales.isEmpty ? null : _printList,
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
    if (_sales.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: context.tr('history.empty'),
        message: context.tr('history.emptyHint'),
        action: widget.onStartSale == null
            ? null
            : FilledButton.icon(
                onPressed: widget.onStartSale,
                icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                label: Text(context.tr('history.goSell')),
              ),
      );
    }

    return AppTable(
      rowKeys: [for (final sale in _sales) ValueKey('sale-row-${sale.id}')],
      onRowTap: (index) => _openDetails(_sales[index]),
      columns: [
        TableColumn(context.tr('history.reference'), flex: 3),
        TableColumn(context.tr('history.date'), flex: 3, minWidth: 720),
        TableColumn(context.tr('history.customer'), flex: 3),
        TableColumn(context.tr('history.payment'), flex: 2, minWidth: 940),
        TableColumn(context.tr('history.status'), flex: 3),
        TableColumn(
          context.tr('history.balance'),
          flex: 3,
          numeric: true,
          minWidth: 640,
        ),
        TableColumn(
          context.tr('history.items'),
          flex: 1,
          numeric: true,
          minWidth: 1040,
        ),
        TableColumn(context.tr('history.total'), flex: 3, numeric: true),
        const TableColumn('', width: 120, numeric: true),
      ],
      rows: [
        for (final sale in _sales)
          [
            Text(ltr(sale.reference), style: text.labelLarge),
            Text(
              Fmt.dateTime(context, sale.soldAt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
            Text(
              customerLabel(context, sale.customerName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (sale.customerName ?? '').trim().isEmpty
                  ? text.bodyMedium!.copyWith(color: AppColors.inkMuted)
                  : text.bodyMedium,
            ),
            Text(paymentLabel(context, sale.paymentMethod)),
            StatusPill(
              paymentStatusLabel(context, sale.paymentStatus),
              tone: saleStatusTone(sale),
            ),
            Text(
              sale.isFullyPaid
                  ? context.tr('common.none')
                  : Fmt.money(context, sale.balanceDue),
              style: text.labelLarge!.copyWith(
                color: sale.isFullyPaid ? AppColors.inkMuted : AppColors.danger,
              ),
            ),
            Text(
              Fmt.integer(
                context,
                sale.lines.fold<int>(0, (sum, l) => sum + l.quantity),
              ),
            ),
            Text(Fmt.money(context, sale.total), style: text.labelLarge),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!sale.isFullyPaid)
                  IconButton(
                    key: ValueKey('history.pay-${sale.id}'),
                    tooltip: context.tr('history.recordPayment'),
                    color: AppColors.primary,
                    onPressed: () => _recordPayment(sale),
                    icon: const Icon(Icons.payments_outlined, size: 20),
                  ),
                IconButton(
                  tooltip: context.tr('history.printInvoice'),
                  onPressed: () => _print(sale),
                  icon: const Icon(Icons.print_outlined, size: 20),
                ),
              ],
            ),
          ],
      ],
    );
  }
}

/// Records a payment against a credit sale. Pops `(amount, method)`.
class RecordPaymentDialog extends StatefulWidget {
  const RecordPaymentDialog({super.key, required this.sale});

  final SaleResult sale;

  @override
  State<RecordPaymentDialog> createState() => RecordPaymentDialogState();
}

class RecordPaymentDialogState extends State<RecordPaymentDialog> {
  late final _amount = TextEditingController(
    text: widget.sale.balanceDue.toStringAsFixed(2),
  );
  String _method = 'CASH';
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = context.tr('errors.amountInvalid'));
      return;
    }
    Navigator.of(context).pop((amount: amount, method: _method));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sale = widget.sale;
    return AppDialog(
      width: 460,
      icon: Icons.payments_rounded,
      title: context.tr('history.payTitle'),
      subtitle: context.tr(
        'history.paySale',
        namedArgs: {'reference': ltr(sale.reference)},
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('history.payBalance'),
                    style: text.bodyMedium!.copyWith(color: AppColors.warning),
                  ),
                ),
                Text(
                  Fmt.money(context, sale.balanceDue),
                  style: text.titleMedium!.copyWith(color: AppColors.warning),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          TextField(
            key: const ValueKey('pay.amount'),
            controller: _amount,
            autofocus: true,

            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: context.tr('history.payAmount'),
              suffixText: context.tr('common.currency'),
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Space.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ActionChip(
              avatar: const Icon(Icons.done_all_rounded, size: 16),
              label: Text(context.tr('history.payFull')),
              onPressed: () => setState(() {
                _amount.text = sale.balanceDue.toStringAsFixed(2);
                _error = null;
              }),
            ),
          ),
          const SizedBox(height: Space.lg),
          Text(
            context.tr('history.payMethod'),
            style: text.labelMedium!.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: Space.xs),
          ChoiceBar<String>(
            value: _method,
            options: [
              for (final method in const ['CASH', 'CARD', 'TRANSFER'])
                (method, paymentLabel(context, method)),
            ],
            onChanged: (value) => setState(() => _method = value),
          ),
        ],
      ),
      secondary: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.tr('common.cancel')),
      ),
      primary: FilledButton(
        key: const ValueKey('pay.submit'),
        onPressed: _submit,
        child: Text(context.tr('history.paySubmit')),
      ),
    );
  }
}
