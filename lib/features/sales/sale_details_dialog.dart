import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/formatters.dart';
import '../../core/i18n/labels.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import '../../core/errors/error_reporter.dart';
import '../api/desktop_api.dart';
import '../documents/company_branding.dart';
import '../documents/customer_info_dialog.dart';
import '../documents/document_service.dart';
import 'cart_controller.dart' show formatRate;

/// The document lines of a recorded sale.
List<DocumentLine> saleDocumentLines(SaleResult sale) => [
  for (final line in sale.lines)
    DocumentLine(
      title: line.title,
      sku: line.sku,
      quantity: line.quantity,
      unitPrice: line.unitPrice,
      totalPrice: line.totalPrice,
    ),
];

/// Prints the invoice (facture) of a recorded sale.
///
/// A facture needs the customer's details and fiscal identifiers: the dialog
/// asks for them (prefilled from the sale), saves them on the sale so a
/// reprint matches, then prints. Returns the updated sale, or null when the
/// user cancelled or saving failed.
Future<SaleResult?> printSaleInvoice(
  BuildContext context,
  WidgetRef ref,
  SaleResult sale, {
  required String companyName,
  required String warehouseName,
  String? warehouseId,
}) async {
  final customer = await showCustomerInfoDialog(
    context,
    initial: sale.customer,
  );
  if (customer == null || !context.mounted) return null;

  var current = sale;
  if (customer != sale.customer) {
    final updated = await ErrorReporter.guard(
      () => ref
          .read(desktopApiProvider)
          .updateSaleCustomer(
            saleId: sale.id,
            customer: customer,
            warehouseId: warehouseId,
          ),
      fallback: context.tr('invoiceCustomer.saveError'),
      context: 'sale-customer',
    );
    if (updated == null || !context.mounted) return null;
    current = updated;
  }

  final fallbackError = context.tr('errors.print');
  final branding = await readCompanyBranding(ref, fallbackName: companyName);
  await ErrorReporter.guard(
    fallback: fallbackError,
    context: 'print',
    () => DocumentService.print(
      DocumentData(
        type: DocumentType.facture,
        reference: current.reference,
        date: current.soldAt,
        company: branding.company,
        logo: branding.logo,
        warehouseName: current.warehouseName.isEmpty
            ? warehouseName
            : current.warehouseName,
        customer: current.customer.copyWith(
          name: current.customerName ?? customer.name,
        ),
        lines: saleDocumentLines(current),
        subtotal: current.subtotal,
        discount: current.discount,
        taxRate: current.taxRate,
        tax: current.tax,
        total: current.total,
        currency: current.currency,
        paymentMethod: current.paymentMethod,
      ),
    ),
  );
  return current;
}

/// What the user chose in the sale details dialog.
enum SaleAction { print, recordPayment }

Tone saleStatusTone(SaleResult sale) => sale.isFullyPaid
    ? Tone.success
    : sale.paymentStatus == 'UNPAID'
    ? Tone.danger
    : Tone.warning;

String customerLabel(BuildContext context, String? name) =>
    (name ?? '').trim().isEmpty ? context.tr('common.walkIn') : name!.trim();

Future<SaleAction?> showSaleDetails(BuildContext context, SaleResult sale) =>
    showDialog<SaleAction>(
      context: context,
      builder: (_) => SaleDetailsDialog(sale: sale),
    );

/// Everything about one sale: products, totals and payments received.
class SaleDetailsDialog extends StatelessWidget {
  const SaleDetailsDialog({super.key, required this.sale});

  final SaleResult sale;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget total(String label, num value, {bool strong = false, Tone? tone}) {
      final color = tone == null ? null : toneColors(tone).fg;
      final style = (strong ? text.titleMedium : text.bodyMedium)!.copyWith(
        color: color,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            Text(Fmt.money(context, value), style: style),
          ],
        ),
      );
    }

    return AppDialog(
      width: 760,
      icon: Icons.receipt_long_rounded,
      title: context.tr(
        'history.detailsTitle',
        namedArgs: {'reference': ltr(sale.reference)},
      ),
      subtitle: Fmt.dateTime(context, sale.soldAt),
      body: Column(
        key: const ValueKey('sale-details'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              StatusPill(
                paymentStatusLabel(context, sale.paymentStatus),
                tone: saleStatusTone(sale),
              ),
              StatusPill(paymentLabel(context, sale.paymentMethod)),
            ],
          ),
          const SizedBox(height: Space.md),
          DetailRow(
            label: context.tr('history.customer'),
            value: customerLabel(context, sale.customerName),
          ),
          if (sale.createdByName != null)
            DetailRow(
              label: context.tr('history.soldBy'),
              value: sale.createdByName!,
            ),
          if (sale.dueDate != null)
            DetailRow(
              label: context.tr('history.dueDate'),
              value: Fmt.date(context, sale.dueDate!),
            ),
          const SizedBox(height: Space.lg),
          Text(context.tr('history.products'), style: text.titleSmall),
          const SizedBox(height: Space.sm),
          MiniTable(
            columns: [
              TableColumn(context.tr('history.colProduct'), flex: 5),
              TableColumn(context.tr('history.colQty'), flex: 1, numeric: true),
              TableColumn(
                context.tr('history.colUnit'),
                flex: 2,
                numeric: true,
              ),
              TableColumn(
                context.tr('history.colTotal'),
                flex: 2,
                numeric: true,
              ),
            ],
            rows: [
              for (final line in sale.lines)
                [
                  '${line.title}\n${ltr(line.sku)}',
                  '${line.quantity}',
                  Fmt.money(context, line.unitPrice),
                  Fmt.money(context, line.totalPrice),
                ],
            ],
          ),
          const SizedBox(height: Space.md),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                children: [
                  total(context.tr('sell.subtotal'), sale.subtotal),
                  if (sale.discount != 0)
                    total(context.tr('sell.discount'), -sale.discount),
                  if (sale.tax != 0)
                    total(
                      sale.taxRate > 0
                          ? context.tr(
                              'sell.taxLine',
                              namedArgs: {'rate': formatRate(sale.taxRate)},
                            )
                          : context.tr('sell.tax'),
                      sale.tax,
                    ),
                  const Divider(),
                  total(context.tr('sell.total'), sale.total, strong: true),
                  total(context.tr('history.paid'), sale.amountPaid),
                  if (!sale.isFullyPaid)
                    total(
                      context.tr('history.balance'),
                      sale.balanceDue,
                      strong: true,
                      tone: Tone.danger,
                    ),
                ],
              ),
            ),
          ),
          if (sale.payments.isNotEmpty) ...[
            const SizedBox(height: Space.lg),
            Text(context.tr('history.payments'), style: text.titleSmall),
            const SizedBox(height: Space.sm),
            MiniTable(
              columns: [
                TableColumn(context.tr('history.soldAt'), flex: 3),
                TableColumn(context.tr('history.colMethod'), flex: 2),
                TableColumn(context.tr('history.colBy'), flex: 3),
                TableColumn(
                  context.tr('history.colAmount'),
                  flex: 2,
                  numeric: true,
                ),
              ],
              rows: [
                for (final payment in sale.payments)
                  [
                    Fmt.dateTime(context, payment.paidAt),
                    paymentLabel(context, payment.paymentMethod),
                    payment.createdByName ?? context.tr('common.none'),
                    Fmt.money(context, payment.amount),
                  ],
              ],
            ),
          ],
        ],
      ),
      secondary: sale.isFullyPaid
          ? TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('common.close')),
            )
          : OutlinedButton.icon(
              key: const ValueKey('sale-details.pay'),
              onPressed: () =>
                  Navigator.of(context).pop(SaleAction.recordPayment),
              icon: const Icon(
                Icons.payments_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              label: Text(context.tr('history.recordPayment')),
            ),
      primary: FilledButton.icon(
        key: const ValueKey('sale-details.print'),
        onPressed: () => Navigator.of(context).pop(SaleAction.print),
        icon: const Icon(Icons.print_rounded, size: 18),
        label: Text(context.tr('history.printInvoice')),
      ),
    );
  }
}
