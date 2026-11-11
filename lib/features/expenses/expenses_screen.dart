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

/// Categories accepted by the API; labels live in `expenseCategory.*`.
const expenseCategories = [
  'RENT',
  'SALARIES',
  'UTILITIES',
  'SUPPLIES',
  'MAINTENANCE',
  'TRANSPORT',
  'MARKETING',
  'TAXES',
  'OTHER',
];

const _expensePayments = ['CASH', 'CARD', 'CREDIT', 'TRANSFER', 'OTHER'];

const _periods = {
  'month': 'charges.month',
  'quarter': 'charges.quarter',
  'year': 'charges.year',
  'all': 'charges.allTime',
};

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({
    super.key,
    required this.warehouseId,
    this.warehouseName = '',
    this.companyName = '',
  });

  final String warehouseId;
  final String warehouseName;
  final String companyName;

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  List<ExpenseRecord> _items = [];
  ExpenseSummaryResult _summary = const ExpenseSummaryResult(
    total: 0,
    count: 0,
  );
  bool _loading = true;
  String? _error;
  String _period = 'month';
  String? _category;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ({DateTime? from, DateTime? to}) get _range {
    final now = DateTime.now();
    switch (_period) {
      case 'month':
        return (from: DateTime(now.year, now.month, 1), to: now);
      case 'quarter':
        return (from: now.subtract(const Duration(days: 90)), to: now);
      case 'year':
        return (from: DateTime(now.year, 1, 1), to: now);
      default:
        return (from: null, to: null);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final range = _range;
    try {
      final api = ref.read(desktopApiProvider);
      final results = await Future.wait([
        api.expenses(
          warehouseId: widget.warehouseId,
          from: range.from,
          to: range.to,
        ),
        api.expenseSummary(
          warehouseId: widget.warehouseId,
          from: range.from,
          to: range.to,
        ),
      ]);
      if (!mounted) return;
      final list =
          results[0] as ({List<ExpenseRecord> items, double total, int count});
      final summary = results[1] as ExpenseSummaryResult;
      setState(() {
        final filtered = _category == null
            ? list.items
            : list.items.where((item) => item.category == _category).toList();
        _items = filtered;
        _summary = summary;
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

  Future<void> _openForm() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => ExpenseFormDialog(warehouseId: widget.warehouseId),
    );
    if (created == true) await _load();
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
        kind: 'charges',
        companyName: widget.companyName,
        warehouseName: widget.warehouseName,
        filters: [
          t('list.period.$_period'),
          if (_category != null)
            '${t('list.category')} : ${DocumentService.code('expenseCategory', _category)}',
        ],
        headers: [
          t('list.date'),
          t('list.label'),
          t('list.category'),
          t('list.reference'),
          t('list.payment'),
          t('list.amount'),
        ],
        numericColumns: const {5},
        rows: [
          for (final item in _items)
            [
              DocumentService.date(item.spentAt),
              item.label,
              DocumentService.code('expenseCategory', item.category),
              item.reference ?? '—',
              DocumentService.code('payment', item.paymentMethod),
              DocumentService.money(item.amount),
            ],
        ],
        totals: [
          (
            t('list.total'),
            DocumentService.money(
              _items.fold<double>(0, (sum, item) => sum + item.amount),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryTotals = <String, double>{};
    for (final item in _items) {
      categoryTotals[item.category] =
          (categoryTotals[item.category] ?? 0) + item.amount;
    }
    final topCategory = categoryTotals.entries.isEmpty
        ? null
        : (categoryTotals.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first;
    final ready = !_loading && _error == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: context.tr('charges.title'),
          subtitle: context.tr(_periods[_period]!),
          actions: [
            OutlinedButton.icon(
              key: const ValueKey('charges.printList'),
              onPressed: _loading || _items.isEmpty ? null : _printList,
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
              key: const ValueKey('charges.new'),
              onPressed: _openForm,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.tr('charges.record')),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: context.tr('charges.total'),
                value: ready ? Fmt.money(context, _summary.total) : '…',
                icon: Icons.account_balance_wallet_outlined,
                tone: Tone.brand,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: StatTile(
                label: context.tr('charges.entries'),
                value: ready ? Fmt.integer(context, _summary.count) : '…',
                icon: Icons.receipt_outlined,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: StatTile(
                label: context.tr('charges.top'),
                value: !ready || topCategory == null
                    ? context.tr('common.none')
                    : expenseCategoryLabel(context, topCategory.key),
                icon: Icons.category_outlined,
                tone: topCategory == null ? Tone.neutral : Tone.warning,
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
                  child: Wrap(
                    spacing: Space.md,
                    runSpacing: Space.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceBar<String>(
                        value: _period,
                        keyPrefix: 'period-',
                        options: [
                          for (final entry in _periods.entries)
                            (entry.key, context.tr(entry.value)),
                        ],
                        onChanged: (value) {
                          setState(() => _period = value);
                          _load();
                        },
                      ),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String?>(
                          initialValue: _category,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: context.tr('charges.category'),
                            isDense: true,
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(context.tr('charges.allCategories')),
                            ),
                            for (final category in expenseCategories)
                              DropdownMenuItem<String?>(
                                value: category,
                                child: Text(
                                  expenseCategoryLabel(context, category),
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() => _category = value);
                            _load();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    final text = Theme.of(context).textTheme;
    if (_loading) return const LoadingList();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_items.isEmpty) {
      return EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: context.tr('charges.empty'),
        message: context.tr('charges.emptyHint'),
      );
    }
    return AppTable(
      columns: [
        TableColumn(context.tr('charges.date'), flex: 2),
        TableColumn(context.tr('charges.label'), flex: 4),
        TableColumn(context.tr('charges.category'), flex: 3),
        TableColumn(context.tr('charges.reference'), flex: 2, minWidth: 820),
        TableColumn(context.tr('charges.payment'), flex: 2, minWidth: 700),
        TableColumn(context.tr('charges.amount'), flex: 3, numeric: true),
      ],
      rows: [
        for (final item in _items)
          [
            Text(Fmt.date(context, item.spentAt), style: text.bodySmall),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelLarge,
            ),
            StatusPill(expenseCategoryLabel(context, item.category)),
            Text(
              item.reference == null
                  ? context.tr('common.none')
                  : ltr(item.reference!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(paymentLabel(context, item.paymentMethod)),
            Text(Fmt.money(context, item.amount), style: text.labelLarge),
          ],
      ],
    );
  }
}

class ExpenseFormDialog extends ConsumerStatefulWidget {
  const ExpenseFormDialog({super.key, required this.warehouseId});

  final String warehouseId;

  @override
  ConsumerState<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<ExpenseFormDialog> {
  final _label = TextEditingController();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  String _category = 'OTHER';
  String _paymentMethod = 'CASH';
  DateTime _spentAt = DateTime.now();
  bool _saving = false;
  String? _labelError;
  String? _amountError;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    setState(() {
      _error = null;
      _labelError = _label.text.trim().isEmpty
          ? context.tr('errors.labelRequired')
          : null;
      _amountError = amount == null || amount <= 0
          ? context.tr('errors.amountInvalid')
          : null;
    });
    if (_labelError != null || _amountError != null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(desktopApiProvider)
          .createExpense(
            warehouseId: widget.warehouseId,
            label: _label.text.trim(),
            category: _category,
            amount: amount!,
            spentAt: _spentAt,
            paymentMethod: _paymentMethod,
            reference: _reference.text,
            note: _note.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = toApiException(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _spentAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _spentAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: Space.lg);
    return AppDialog(
      width: 560,
      icon: Icons.account_balance_wallet_rounded,
      title: context.tr('charges.formTitle'),
      onClose: _saving ? () {} : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('charge.label'),
            controller: _label,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.tr('charges.formLabel'),
              hintText: context.tr('charges.formLabelHint'),
              errorText: _labelError,
            ),
            onChanged: (_) {
              if (_labelError != null) setState(() => _labelError = null);
            },
          ),
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('charge.amount'),
                  controller: _amount,

                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: context.tr('charges.formAmount'),
                    suffixText: context.tr('common.currency'),
                    errorText: _amountError,
                  ),
                  onChanged: (_) {
                    if (_amountError != null) {
                      setState(() => _amountError = null);
                    }
                  },
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('charges.category'),
                  ),
                  items: [
                    for (final category in expenseCategories)
                      DropdownMenuItem(
                        value: category,
                        child: Text(expenseCategoryLabel(context, category)),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _category = value ?? 'OTHER'),
                ),
              ),
            ],
          ),
          gap,
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('charges.payment'),
                  ),
                  items: [
                    for (final method in _expensePayments)
                      DropdownMenuItem(
                        value: method,
                        child: Text(paymentLabel(context, method)),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _paymentMethod = value ?? 'CASH'),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.md),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: context.tr('charges.date'),
                      suffixIcon: const Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                      ),
                    ),
                    child: Text(Fmt.date(context, _spentAt)),
                  ),
                ),
              ),
            ],
          ),
          gap,
          TextField(
            controller: _reference,
            decoration: InputDecoration(
              labelText: context.tr('charges.formReference'),
            ),
          ),
          gap,
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.tr('charges.formNote'),
            ),
          ),
          if (_error != null) ...[gap, InlineMessage(_error!)],
        ],
      ),
      secondary: TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        child: Text(context.tr('common.cancel')),
      ),
      primary: FilledButton(
        key: const ValueKey('charge.save'),
        onPressed: _saving ? null : _save,
        child: _saving
            ? const ButtonSpinner(color: AppColors.inkMuted)
            : Text(context.tr('charges.save')),
      ),
    );
  }
}
