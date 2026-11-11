import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/formatters.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import '../api/desktop_api.dart';
import '../documents/company_branding.dart';
import '../documents/document_service.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({
    super.key,
    required this.warehouseId,
    required this.warehouseName,
    required this.companyName,
  });

  final String warehouseId;
  final String warehouseName;
  final String companyName;

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  final _search = TextEditingController();
  List<StockItem> _items = [];

  /// Catalogue entries by product id: they carry family, category and
  /// sub-category, which the stock endpoint does not return.
  Map<String, Product> _catalog = const {};
  bool _loading = true;
  bool _lowStock = false;
  String? _error;
  Timer? _debounce;
  String? _family;
  String? _category;
  String? _subCategory;

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
      _error = null;
    });
    final api = ref.read(desktopApiProvider);
    try {
      final catalogFuture = _catalog.isEmpty
          ? api
                .catalog(warehouseId: widget.warehouseId)
                .then<List<Product>?>((rows) => rows)
                .catchError((Object _) => null)
          : Future<List<Product>?>.value(null);
      final items = await api.allStock(
        warehouseId: widget.warehouseId,
        search: _search.text,
        lowStock: _lowStock,
      );
      final catalog = await catalogFuture;
      if (!mounted) return;
      setState(() {
        _items = items;
        if (catalog != null) {
          _catalog = {for (final product in catalog) product.id: product};
        }
        _dropStaleFilters();
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

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  String? _familyOf(StockItem item) =>
      item.product.familyName ?? _catalog[item.product.id]?.familyName;

  String? _categoryOf(StockItem item) =>
      item.product.categoryName ?? _catalog[item.product.id]?.categoryName;

  String? _subCategoryOf(StockItem item) =>
      item.product.subCategoryName ??
      _catalog[item.product.id]?.subCategoryName;

  List<String> _options(
    String? Function(StockItem) read,
    bool Function(StockItem) keep,
  ) {
    final values = _items
        .where(keep)
        .map(read)
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  List<String> get _familyOptions => _options(_familyOf, (_) => true);

  List<String> get _categoryOptions => _options(
    _categoryOf,
    (item) => _family == null || _familyOf(item) == _family,
  );

  List<String> get _subCategoryOptions => _options(
    _subCategoryOf,
    (item) =>
        (_family == null || _familyOf(item) == _family) &&
        (_category == null || _categoryOf(item) == _category),
  );

  void _dropStaleFilters() {
    if (_family != null && !_familyOptions.contains(_family)) _family = null;
    if (_category != null && !_categoryOptions.contains(_category)) {
      _category = null;
    }
    if (_subCategory != null && !_subCategoryOptions.contains(_subCategory)) {
      _subCategory = null;
    }
  }

  bool get _hasTreeFilter =>
      _family != null || _category != null || _subCategory != null;

  List<StockItem> get _visible => _items
      .where(
        (item) =>
            (_family == null || _familyOf(item) == _family) &&
            (_category == null || _categoryOf(item) == _category) &&
            (_subCategory == null || _subCategoryOf(item) == _subCategory),
      )
      .toList();

  Future<void> _printStatement() async {
    final t = DocumentStrings.get;
    final items = _visible;
    final filters = [
      if (_family != null) '${t('list.family')} : $_family',
      if (_category != null) '${t('list.category')} : $_category',
      if (_subCategory != null) '${t('list.subCategory')} : $_subCategory',
      if (_lowStock) t('list.lowOnly'),
      if (_search.text.trim().isNotEmpty)
        t('list.search', {'text': _search.text.trim()}),
    ];
    final total = items.fold<double>(
      0,
      (sum, item) => sum + item.product.price * item.quantity,
    );
    // The company logo heads the list, as on invoices.
    final branding = await readCompanyBranding(
      ref,
      fallbackName: widget.companyName,
    );
    return DocumentService.printList(
      ListDocument(
        logo: branding.logo,
        kind: 'stock',
        companyName: widget.companyName,
        warehouseName: widget.warehouseName,
        filters: filters,
        headers: [
          t('colReference'),
          t('colTitle'),
          t('list.family'),
          t('list.category'),
          t('list.subCategory'),
          t('colQuantity'),
          t('colThreshold'),
          t('colUnitPrice'),
          t('colValue'),
        ],
        numericColumns: const {5, 6, 7, 8},
        rows: [
          for (final item in items)
            [
              item.product.sku,
              item.product.title,
              _familyOf(item) ?? '—',
              _categoryOf(item) ?? '—',
              _subCategoryOf(item) ?? '—',
              '${item.quantity}',
              '${item.reorderLevel}',
              DocumentService.money(item.product.price),
              DocumentService.money(item.product.price * item.quantity),
            ],
        ],
        totals: [(t('list.stockValue'), '${DocumentService.money(total)} DZD')],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final visible = _visible;
    final totalValue = visible.fold<double>(
      0,
      (sum, item) => sum + item.product.price * item.quantity,
    );
    final lowCount = visible.where((item) => item.isLowStock).length;
    final ready = !_loading && _error == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: context.tr('stock.title'),
          subtitle: widget.warehouseName,
          actions: [
            IconButton.outlined(
              tooltip: context.tr('common.refresh'),
              onPressed: _loading ? null : _load,
              style: IconButton.styleFrom(
                side: const BorderSide(color: AppColors.line),
              ),
              icon: const Icon(Icons.refresh_rounded),
            ),
            FilledButton.icon(
              key: const ValueKey('stock.print'),
              onPressed: visible.isEmpty ? null : _printStatement,
              icon: const Icon(Icons.print_rounded, size: 18),
              label: Text(context.tr('stock.print')),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: context.tr('stock.products'),
                value: ready ? Fmt.integer(context, visible.length) : '…',
                icon: Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: StatTile(
                label: context.tr('stock.low'),
                value: ready ? Fmt.integer(context, lowCount) : '…',
                icon: Icons.trending_down_rounded,
                tone: lowCount > 0 && ready ? Tone.warning : Tone.neutral,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: StatTile(
                label: context.tr('stock.value'),
                value: ready ? Fmt.money(context, totalValue) : '…',
                icon: Icons.savings_outlined,
                tone: Tone.brand,
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
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 280,
                        child: TextField(
                          controller: _search,
                          decoration: InputDecoration(
                            labelText: context.tr('stock.search'),
                            prefixIcon: const Icon(Icons.search_rounded),
                            isDense: true,
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      FilterMenu(
                        key: const ValueKey('stock.family'),
                        label: context.tr('stock.family'),
                        allLabel: context.tr('stock.allFamilies'),
                        value: _family,
                        options: _familyOptions,
                        onChanged: (value) => setState(() {
                          _family = value;
                          _category = null;
                          _subCategory = null;
                        }),
                      ),
                      FilterMenu(
                        key: const ValueKey('stock.category'),
                        label: context.tr('stock.category'),
                        allLabel: context.tr('stock.allCategories'),
                        value: _category,
                        options: _categoryOptions,
                        onChanged: (value) => setState(() {
                          _category = value;
                          _subCategory = null;
                        }),
                      ),
                      FilterMenu(
                        key: const ValueKey('stock.subCategory'),
                        label: context.tr('stock.subCategory'),
                        allLabel: context.tr('stock.allSubCategories'),
                        value: _subCategory,
                        options: _subCategoryOptions,
                        onChanged: (value) =>
                            setState(() => _subCategory = value),
                      ),
                      FilterChip(
                        key: const ValueKey('stock.low'),
                        label: Text(context.tr('stock.lowOnly')),
                        selected: _lowStock,
                        onSelected: (value) {
                          setState(() => _lowStock = value);
                          _load();
                        },
                      ),
                      if (_hasTreeFilter)
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _family = null;
                            _category = null;
                            _subCategory = null;
                          }),
                          icon: const Icon(
                            Icons.filter_alt_off_rounded,
                            size: 18,
                          ),
                          label: Text(context.tr('stock.clearFilters')),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(child: _buildBody(text, visible)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(TextTheme text, List<StockItem> visible) {
    if (_loading) return const LoadingList();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (visible.isEmpty) {
      final filtered =
          _lowStock || _search.text.trim().isNotEmpty || _hasTreeFilter;
      return EmptyState(
        icon: filtered ? Icons.search_off_rounded : Icons.inventory_2_outlined,
        title: context.tr(filtered ? 'stock.noMatch' : 'stock.empty'),
        message: context.tr(filtered ? 'stock.noMatchHint' : 'stock.emptyHint'),
      );
    }
    return AppTable(
      columns: [
        TableColumn(context.tr('stock.colProduct'), flex: 6),
        TableColumn(context.tr('stock.colQuantity'), flex: 3),
        TableColumn(context.tr('stock.colMin'), flex: 2, minWidth: 700),
        TableColumn(context.tr('stock.colValue'), flex: 3, numeric: true),
      ],
      rows: [
        for (final item in visible)
          [
            Row(
              children: [
                ProductThumb(
                  imageUrl: item.product.imageUrl,
                  width: 40,
                  height: 40,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge,
                      ),
                      Text(
                        [
                          ltr(item.product.sku),
                          Fmt.money(context, item.product.price),
                          ?_subCategoryOf(item) ?? _categoryOf(item),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            StatusPill(
              context.tr(
                'stock.inStock',
                namedArgs: {'count': Fmt.integer(context, item.quantity)},
              ),
              tone: item.quantity <= 0
                  ? Tone.danger
                  : item.isLowStock
                  ? Tone.warning
                  : Tone.success,
            ),
            Text(
              context.tr(
                'stock.min',
                namedArgs: {'count': Fmt.integer(context, item.reorderLevel)},
              ),
              style: text.bodySmall,
            ),
            Text(
              Fmt.money(context, item.product.price * item.quantity),
              style: text.labelLarge,
            ),
          ],
      ],
    );
  }
}
