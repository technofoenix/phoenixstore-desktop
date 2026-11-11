import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import '../api/desktop_api.dart';
import '../auth/auth_controller.dart';
import '../clients/clients_screen.dart';
import '../expenses/expenses_screen.dart';
import '../orders/orders_screen.dart';
import '../sales/sales_history_screen.dart';
import '../sales/cart_controller.dart' show defaultTaxRateProvider;
import '../sales/sales_screen.dart';
import '../settings/settings_screen.dart';
import '../stock/stock_screen.dart';

class _Destination {
  const _Destination(this.labelKey, this.icon, this.selectedIcon);

  final String labelKey;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination(
    'nav.sell',
    Icons.point_of_sale_outlined,
    Icons.point_of_sale_rounded,
  ),
  _Destination(
    'nav.sales',
    Icons.receipt_long_outlined,
    Icons.receipt_long_rounded,
  ),
  _Destination(
    'nav.clients',
    Icons.people_alt_outlined,
    Icons.people_alt_rounded,
  ),
  _Destination(
    'nav.stock',
    Icons.inventory_2_outlined,
    Icons.inventory_2_rounded,
  ),
  _Destination(
    'nav.orders',
    Icons.local_shipping_outlined,
    Icons.local_shipping_rounded,
  ),
  _Destination(
    'nav.charges',
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet_rounded,
  ),
  _Destination('nav.settings', Icons.settings_outlined, Icons.settings_rounded),
];

const _settingsTab = 6;

class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  DesktopContext? _context;
  String? _warehouseId;
  String? _error;
  bool _loading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? warehouseId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(desktopApiProvider);
      final store = ref.read(sessionStoreProvider);
      final remembered = warehouseId ?? (await store.read())?.warehouseId;
      var context = await api.context(warehouseId: remembered);

      var selected = context.context?.warehouseId;
      if (selected == null && context.warehouses.isNotEmpty) {
        selected = context.warehouses.first.id;
        context = await api.context(warehouseId: selected);
      }
      if (selected != null) {
        await store.saveWarehouse(selected);
      }
      if (!mounted) return;
      // Before the sales screen builds a ticket, so new tickets get the rate.
      ref.read(defaultTaxRateProvider.notifier).set(context.defaultTaxRate);
      setState(() {
        _context = context;
        _warehouseId = selected;
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

  Future<void> _selectWarehouse(String? id) async {
    if (id == null || id == _warehouseId) return;
    await _load(warehouseId: id);
  }

  void _go(int tab) => setState(() => _tab = tab);

  void _signOut() => ref.read(authControllerProvider.notifier).logout();

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    for (var i = 0; i < _destinations.length; i++) ...{
      SingleActivator(_digit(i + 1), control: true): () => _go(i),
      SingleActivator(_digit(i + 1), meta: true): () => _go(i),
    },
  };

  static LogicalKeyboardKey _digit(int n) => switch (n) {
    1 => LogicalKeyboardKey.digit1,
    2 => LogicalKeyboardKey.digit2,
    3 => LogicalKeyboardKey.digit3,
    4 => LogicalKeyboardKey.digit4,
    5 => LogicalKeyboardKey.digit5,
    6 => LogicalKeyboardKey.digit6,
    _ => LogicalKeyboardKey.digit7,
  };

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).asData?.value;

    if (_loading && _context == null) {
      return const Scaffold(
        body: Padding(padding: EdgeInsets.all(Space.xl), child: LoadingList()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: ErrorState(
          title: context.tr('shell.loadError'),
          message: _error!,
          onRetry: _load,
          extra: OutlinedButton.icon(
            onPressed: _signOut,
            icon: const DirIcon(Icons.logout_rounded, size: 18),
            label: Text(context.tr('common.signOut')),
          ),
        ),
      );
    }

    final warehouseId = _warehouseId;
    final contextInfo = _context?.context;
    final warehouses = _context?.warehouses ?? const <WarehouseOption>[];
    final companyName = contextInfo?.companyName ?? context.tr('app.name');
    final warehouseName = contextInfo?.warehouseName ?? '';

    Widget page() {
      if (_tab == _settingsTab) {
        return SettingsScreen(
          userName: user?.fullName ?? _context?.fullName ?? '',
          userPhone: user?.phoneNumber,
          boutique: warehouseName,
        );
      }
      if (warehouseId == null) {
        return EmptyState(
          icon: Icons.storefront_outlined,
          title: context.tr('shell.noBoutique'),
          message: context.tr('shell.noBoutiqueHint'),
        );
      }
      return switch (_tab) {
        0 => SalesScreen(
          key: ValueKey('sell-$warehouseId'),
          warehouseId: warehouseId,
          warehouseName: warehouseName,
          companyName: companyName,
        ),
        1 => SalesHistoryScreen(
          key: ValueKey('history-$warehouseId'),
          warehouseId: warehouseId,
          warehouseName: warehouseName,
          companyName: companyName,
          onStartSale: () => _go(0),
        ),
        2 => ClientsScreen(
          key: ValueKey('clients-$warehouseId'),
          warehouseId: warehouseId,
          warehouseName: warehouseName,
          companyName: companyName,
        ),
        3 => StockScreen(
          key: ValueKey('stock-$warehouseId'),
          warehouseId: warehouseId,
          warehouseName: warehouseName,
          companyName: companyName,
        ),
        4 => OrdersScreen(
          key: ValueKey('orders-$warehouseId'),
          warehouseId: warehouseId,
          warehouseName: warehouseName,
          companyName: companyName,
        ),
        _ => ExpensesScreen(
          key: ValueKey('expenses-$warehouseId'),
          warehouseId: warehouseId,
          warehouseName: warehouseName,
          companyName: companyName,
        ),
      };
    }

    return Scaffold(
      body: CallbackShortcuts(
        bindings: _shortcuts,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= Breakpoints.wideSidebar;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Sidebar(
                  wide: wide,
                  tab: _tab,
                  onSelect: _go,
                  warehouses: warehouses,
                  warehouseId: warehouseId,
                  warehouseName: warehouseName,
                  onWarehouseChanged: _selectWarehouse,
                  userName: user?.fullName ?? _context?.fullName ?? '',
                  companyName: companyName,
                  onSignOut: _signOut,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.xl,
                      Space.xl,
                      Space.xl,
                      Space.lg,
                    ),
                    child: KeyedSubtree(
                      key: ValueKey('page-$_tab'),
                      child: page(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.wide,
    required this.tab,
    required this.onSelect,
    required this.warehouses,
    required this.warehouseId,
    required this.warehouseName,
    required this.onWarehouseChanged,
    required this.userName,
    required this.companyName,
    required this.onSignOut,
  });

  final bool wide;
  final int tab;
  final ValueChanged<int> onSelect;
  final List<WarehouseOption> warehouses;
  final String? warehouseId;
  final String warehouseName;
  final ValueChanged<String?> onWarehouseChanged;
  final String userName;
  final String companyName;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final padding = wide ? Space.lg : Space.md;
    return Container(
      width: wide ? 248 : 80,
      color: AppColors.sidebar,
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: wide
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Image.asset('assets/logos/logo-pos.png'),
              ),
              if (wide) ...[
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('app.name'),
                        style: text.titleSmall!.copyWith(
                          color: AppColors.sidebarText,
                        ),
                      ),
                      Text(
                        context.tr('app.tagline'),
                        style: text.bodySmall!.copyWith(
                          color: AppColors.sidebarMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.xl),
          _BoutiqueSwitcher(
            wide: wide,
            warehouses: warehouses,
            warehouseId: warehouseId,
            warehouseName: warehouseName,
            onChanged: onWarehouseChanged,
          ),
          const SizedBox(height: Space.lg),
          for (var i = 0; i < _settingsTab; i++)
            _NavItem(
              key: ValueKey('nav-$i'),
              index: i,
              wide: wide,
              selected: tab == i,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          _NavItem(
            key: const ValueKey('nav-$_settingsTab'),
            index: _settingsTab,
            wide: wide,
            selected: tab == _settingsTab,
            onTap: () => onSelect(_settingsTab),
          ),
          const SizedBox(height: Space.sm),
          const Divider(color: AppColors.sidebarHover),
          const SizedBox(height: Space.sm),
          _UserCard(
            wide: wide,
            userName: userName,
            companyName: companyName,
            onSignOut: onSignOut,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    super.key,
    required this.index,
    required this.wide,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final bool wide;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final destination = _destinations[widget.index];
    final label = context.tr(destination.labelKey);
    final selected = widget.selected;
    final color = selected ? Colors.white : AppColors.sidebarText;
    final text = Theme.of(context).textTheme;
    final mac = Theme.of(context).platform == TargetPlatform.macOS;
    final keyLabel = ltr('${mac ? '⌘' : 'Ctrl+'}${widget.index + 1}');
    final shortcut = context.tr('nav.shortcut', namedArgs: {'key': keyLabel});

    final item = Semantics(
      selected: selected,
      button: true,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 46,
            margin: const EdgeInsets.only(bottom: Space.xs),
            padding: EdgeInsets.symmetric(
              horizontal: widget.wide ? Space.md : 0,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                  : _hover
                  ? AppColors.sidebarHover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              mainAxisAlignment: widget.wide
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 21,
                  color: color,
                ),
                if (widget.wide) ...[
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge!.copyWith(color: color),
                    ),
                  ),
                  if (_hover && !selected)
                    Text(
                      keyLabel,
                      style: text.labelSmall!.copyWith(
                        color: AppColors.sidebarMuted,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Tooltip(
      message: widget.wide ? shortcut : '$label · $shortcut',
      preferBelow: false,
      child: item,
    );
  }
}

class _BoutiqueSwitcher extends StatelessWidget {
  const _BoutiqueSwitcher({
    required this.wide,
    required this.warehouses,
    required this.warehouseId,
    required this.warehouseName,
    required this.onChanged,
  });

  final bool wide;
  final List<WarehouseOption> warehouses;
  final String? warehouseId;
  final String warehouseName;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canSwitch = warehouses.length > 1;
    final label = context.tr('nav.boutique');

    final face = Container(
      height: wide ? 56 : 46,
      padding: EdgeInsets.symmetric(horizontal: wide ? Space.md : 0),
      decoration: BoxDecoration(
        color: AppColors.sidebarHover,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        mainAxisAlignment: wide
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.storefront_rounded,
            size: 20,
            color: AppColors.sidebarText,
          ),
          if (wide) ...[
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.labelSmall!.copyWith(
                      color: AppColors.sidebarMuted,
                    ),
                  ),
                  Text(
                    warehouseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge!.copyWith(
                      color: AppColors.sidebarText,
                    ),
                  ),
                ],
              ),
            ),
            if (canSwitch)
              const Icon(
                Icons.unfold_more_rounded,
                size: 18,
                color: AppColors.sidebarMuted,
              ),
          ],
        ],
      ),
    );

    if (!canSwitch) {
      return Tooltip(message: '$label · $warehouseName', child: face);
    }
    return PopupMenuButton<String>(
      tooltip: label,
      initialValue: warehouseId,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final warehouse in warehouses)
          PopupMenuItem(
            value: warehouse.id,
            child: Row(
              children: [
                Icon(
                  warehouse.id == warehouseId
                      ? Icons.check_rounded
                      : Icons.storefront_outlined,
                  size: 18,
                ),
                const SizedBox(width: Space.sm),
                Text(warehouse.name),
              ],
            ),
          ),
      ],
      child: face,
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.wide,
    required this.userName,
    required this.companyName,
    required this.onSignOut,
  });

  final bool wide;
  final String userName;
  final String companyName;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final signOut = IconButton(
      key: const ValueKey('signout'),
      tooltip: context.tr('common.signOut'),
      onPressed: onSignOut,
      color: AppColors.sidebarText,
      style: IconButton.styleFrom(foregroundColor: AppColors.sidebarText),
      icon: const DirIcon(Icons.logout_rounded, size: 20),
    );
    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primary,
      child: Text(
        userName.isEmpty ? '?' : userName.characters.first.toUpperCase(),
        style: text.labelLarge!.copyWith(color: Colors.white),
      ),
    );
    if (!wide) {
      return Column(
        children: [
          Tooltip(message: userName, child: avatar),
          const SizedBox(height: Space.sm),
          signOut,
        ],
      );
    }
    return Row(
      children: [
        avatar,
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge!.copyWith(color: AppColors.sidebarText),
              ),
              Text(
                companyName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall!.copyWith(color: AppColors.sidebarMuted),
              ),
            ],
          ),
        ),
        signOut,
      ],
    );
  }
}
