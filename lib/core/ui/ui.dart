/// Shared building blocks: every screen is made from these so the app reads
/// as one system (one card, one pill, one dialog, one set of states).
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/server_config.dart';
import '../theme/app_theme.dart';

bool isRtl(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl;

/// Wraps numbers, codes and phone numbers so they keep their left-to-right
/// order inside an Arabic sentence.
String ltr(String value) => '\u2066$value\u2069';

enum Tone { neutral, success, warning, danger, brand }

({Color fg, Color bg}) toneColors(Tone tone) => switch (tone) {
  Tone.success => (fg: AppColors.success, bg: AppColors.successSoft),
  Tone.warning => (fg: AppColors.warning, bg: AppColors.warningSoft),
  Tone.danger => (fg: AppColors.danger, bg: AppColors.dangerSoft),
  Tone.brand => (fg: AppColors.primaryDeep, bg: AppColors.primarySoft),
  Tone.neutral => (fg: AppColors.inkMuted, bg: AppColors.surfaceMuted),
};

/// Icon that mirrors in right-to-left layouts (logout, arrows, send).
class DirIcon extends StatelessWidget {
  const DirIcon(this.icon, {super.key, this.size, this.color});

  final IconData icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Transform.flip(
    flipX: isRtl(context),
    child: Icon(icon, size: size, color: color),
  );
}

/// The white card used for every block of content.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Material(
    color: color ?? AppColors.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.lg),
      side: const BorderSide(color: AppColors.line),
    ),
    child: Padding(padding: padding, child: child),
  );
}

/// Title row of a screen. Holds at most one filled (primary) button.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Space.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: text.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          for (final action in actions) ...[
            const SizedBox(width: Space.sm),
            action,
          ],
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      ?trailing,
    ],
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = Tone.neutral});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelSmall!.copyWith(color: colors.fg),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = Tone.neutral,
  });

  final String label;
  final String value;
  final IconData icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    final text = Theme.of(context).textTheme;
    return Panel(
      padding: const EdgeInsets.all(Space.lg),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(icon, size: 20, color: colors.fg),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A short tinted line under a field or above a list (scan result, error).
class InlineMessage extends StatelessWidget {
  const InlineMessage(this.message, {super.key, this.tone = Tone.danger});

  final String message;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            tone == Tone.success
                ? Icons.check_circle_rounded
                : tone == Tone.danger
                ? Icons.error_rounded
                : Icons.info_rounded,
            size: 18,
            color: colors.fg,
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: colors.fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered message used for empty and error states. Scrolls when the
/// window is too short.
class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Tone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = toneColors(tone);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colors.bg,
                        borderRadius: BorderRadius.circular(Radii.lg),
                      ),
                      child: Icon(icon, size: 26, color: colors.fg),
                    ),
                    const SizedBox(height: Space.lg),
                    Text(
                      title,
                      style: text.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (message != null && message!.isNotEmpty) ...[
                      const SizedBox(height: Space.xs),
                      Text(
                        message!,
                        style: text.bodyMedium!.copyWith(
                          color: AppColors.inkMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (action != null) ...[
                      const SizedBox(height: Space.lg),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => _StateMessage(
    icon: icon,
    title: title,
    message: message,
    tone: Tone.neutral,
    action: action,
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.title,
    this.extra,
  });

  final String message;
  final VoidCallback onRetry;
  final String? title;
  final Widget? extra;

  @override
  Widget build(BuildContext context) => _StateMessage(
    icon: Icons.cloud_off_rounded,
    title: title ?? context.tr('common.errorTitle'),
    message: message,
    tone: Tone.danger,
    action: Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      alignment: WrapAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(context.tr('common.retry')),
        ),
        ?extra,
      ],
    ),
  );
}

/// Gently pulsing grey blocks shown while data loads.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = Radii.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );
    if (reduce) return box;
    return FadeTransition(
      opacity: Tween(begin: 0.55, end: 1.0).animate(_controller),
      child: box,
    );
  }
}

/// Skeleton rows that mimic a table while it loads.
class LoadingList extends StatelessWidget {
  const LoadingList({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(Space.lg),
    physics: const NeverScrollableScrollPhysics(),
    itemCount: rows,
    separatorBuilder: (_, _) => const SizedBox(height: Space.md),
    itemBuilder: (_, i) => Row(
      children: [
        const Skeleton(width: 36, height: 36, radius: Radii.md),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(
                widthFactor: i.isEven ? 0.5 : 0.35,
                child: const Skeleton(),
              ),
              const SizedBox(height: 6),
              const FractionallySizedBox(
                widthFactor: 0.25,
                child: Skeleton(height: 10),
              ),
            ],
          ),
        ),
        const Skeleton(width: 80),
      ],
    ),
  );
}

/// Skeleton cards that mimic a product grid while it loads.
class LoadingGrid extends StatelessWidget {
  const LoadingGrid({super.key, this.tileWidth = 220, this.tileHeight = 190});

  final double tileWidth;
  final double tileHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / tileWidth).floor().clamp(1, 6);
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: tileHeight,
          crossAxisSpacing: Space.md,
          mainAxisSpacing: Space.md,
        ),
        itemCount: columns * 3,
        itemBuilder: (_, _) => const Panel(
          padding: EdgeInsets.all(Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(height: 72, radius: Radii.md),
              SizedBox(height: Space.md),
              FractionallySizedBox(widthFactor: 0.8, child: Skeleton()),
              SizedBox(height: 6),
              FractionallySizedBox(
                widthFactor: 0.4,
                child: Skeleton(height: 10),
              ),
              Spacer(),
              FractionallySizedBox(
                widthFactor: 0.5,
                child: Skeleton(height: 16),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Lifts 2px on hover; used for clickable cards.
class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final lifted = widget.enabled && _hover;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, lifted ? -2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: [
            if (lifted)
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

class ProductThumb extends StatelessWidget {
  const ProductThumb({
    super.key,
    required this.imageUrl,
    this.width = 44,
    this.height = 44,
    this.radius = Radii.md,
  });

  final String? imageUrl;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        size: (height * 0.4).clamp(16, 28),
        color: AppColors.inkMuted,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl == null
            ? placeholder
            : Image.network(
                // The API sends `/uploads/...`; a bare path cannot load.
                ServerConfig.resolveMedia(imageUrl!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

/// Column of [AppTable]. A column with [minWidth] is hidden when the table
/// is narrower, so tables never scroll sideways.
class TableColumn {
  const TableColumn(
    this.label, {
    this.flex = 2,
    this.numeric = false,
    this.minWidth = 0,
    this.width,
  });

  final String label;
  final int flex;
  final bool numeric;
  final double minWidth;
  final double? width;
}

class AppTable extends StatelessWidget {
  const AppTable({
    super.key,
    required this.columns,
    required this.rows,
    this.rowKeys,
    this.onRowTap,
  });

  final List<TableColumn> columns;
  final List<List<Widget>> rows;
  final List<Key>? rowKeys;

  /// Opens the row (details). Rows show a pointer and react to hover.
  final ValueChanged<int>? onRowTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final visible = [
          for (var i = 0; i < columns.length; i++)
            if (constraints.maxWidth >= columns[i].minWidth) i,
        ];

        Widget cell(int index, Widget child) {
          final column = columns[index];
          final aligned = Align(
            alignment: column.numeric
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: child,
          );
          final padded = Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
            child: aligned,
          );
          return column.width != null
              ? SizedBox(width: column.width, child: padded)
              : Expanded(flex: column.flex, child: padded);
        }

        final header = Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.sm,
            vertical: Space.md,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              for (final i in visible)
                cell(
                  i,
                  Text(
                    columns[i].label,
                    style: text.labelMedium!.copyWith(
                      color: AppColors.inkMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(
              child: Scrollbar(
                child: ListView.builder(
                  primary: true,
                  itemCount: rows.length,
                  itemBuilder: (context, r) => _HoverRow(
                    key: rowKeys?[r],
                    onTap: onRowTap == null ? null : () => onRowTap!(r),
                    child: Row(
                      children: [for (final i in visible) cell(i, rows[r][i])],
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

class _HoverRow extends StatefulWidget {
  const _HoverRow({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: _row(),
    ),
  );

  Widget _row() => AnimatedContainer(
    duration: const Duration(milliseconds: 120),
    constraints: const BoxConstraints(minHeight: 56),
    padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 6),
    decoration: BoxDecoration(
      color: _hover ? AppColors.paper : null,
      border: const Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: widget.child,
  );
}

/// The one dialog layout: header with icon and close, scrolling body,
/// footer with a secondary and a primary action.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.subtitle,
    this.primary,
    this.secondary,
    this.width = 520,
    this.onClose,
    this.scrollBody = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget body;
  final Widget? primary;
  final Widget? secondary;
  final double width;
  final VoidCallback? onClose;
  final bool scrollBody;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(Space.xl),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                  if (icon != null) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      child: Icon(icon, size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: Space.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.titleLarge),
                        if (subtitle != null)
                          Text(subtitle!, style: text.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('common.close'),
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(),
            Flexible(
              child: scrollBody
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(Space.xl),
                      child: body,
                    )
                  : body,
            ),
            if (primary != null || secondary != null) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.xl,
                  vertical: Space.lg,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (secondary != null) Flexible(child: secondary!),
                    if (primary != null && secondary != null)
                      const SizedBox(width: Space.sm),
                    if (primary != null) Flexible(child: primary!),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Spinner that fits inside a button while it works.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );
}

/// Segmented choice used for payment method, stock filter and similar.
class ChoiceBar<T> extends StatelessWidget {
  const ChoiceBar({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.keyPrefix,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) => SegmentedButton<T>(
    showSelectedIcon: false,
    selected: {value},
    onSelectionChanged: (selection) => onChanged(selection.first),
    segments: [
      for (final (option, label) in options)
        ButtonSegment<T>(
          value: option,
          label: Text(
            label,
            key: keyPrefix == null ? null : ValueKey('$keyPrefix$option'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
  );
}

/// Compact dropdown used for catalogue filters (family, category...).
class FilterMenu extends StatelessWidget {
  const FilterMenu({
    super.key,
    required this.label,
    required this.allLabel,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String allLabel;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final active = value != null;
    return PopupMenuButton<String>(
      tooltip: label,
      position: PopupMenuPosition.under,
      onSelected: (selected) => onChanged(selected.isEmpty ? null : selected),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: '',
          checked: !active,
          child: Text(allLabel),
        ),
        for (final option in options)
          CheckedPopupMenuItem(
            value: option,
            checked: option == value,
            child: Text(option),
          ),
      ],
      child: Container(
        height: 44,
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        decoration: BoxDecoration(
          color: active ? AppColors.ink : AppColors.surface,
          border: Border.all(color: active ? AppColors.ink : AppColors.line),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value ?? label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium!.copyWith(
                  color: active ? Colors.white : AppColors.ink,
                ),
              ),
            ),
            const SizedBox(width: Space.xs),
            Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: active ? Colors.white : AppColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Quantity you can type, with − and + around it. Typing more than [max]
/// keeps [max] and calls [onLimit]; clearing it or typing 0 removes the line.
class QuantityField extends StatefulWidget {
  const QuantityField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onRemove,
    this.max,
    this.onLimit,
    this.fieldKey,
  });

  final int value;
  final int? max;
  final ValueChanged<int> onChanged;
  final VoidCallback onRemove;
  final ValueChanged<int>? onLimit;
  final Key? fieldKey;

  @override
  State<QuantityField> createState() => _QuantityFieldState();
}

class _QuantityFieldState extends State<QuantityField> {
  late final _controller = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      } else {
        _commit();
      }
    });
  }

  @override
  void didUpdateWidget(QuantityField old) {
    super.didUpdateWidget(old);
    if (int.tryParse(_controller.text) != widget.value) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _typed(String text) {
    final n = int.tryParse(text);
    if (n == null || n <= 0) return;
    final max = widget.max;
    if (max != null && n > max) {
      _controller.text = '$max';
      _controller.selection = TextSelection.collapsed(offset: '$max'.length);
      widget.onLimit?.call(max);
      widget.onChanged(max);
      return;
    }
    widget.onChanged(n);
  }

  void _commit() {
    final n = int.tryParse(_controller.text) ?? 0;
    if (n <= 0) {
      widget.onRemove();
    } else if (n != widget.value) {
      widget.onChanged(n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final atMax = widget.max != null && widget.value >= widget.max!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: context.tr('sell.removeOne'),
          iconSize: 18,
          style: IconButton.styleFrom(minimumSize: const Size(36, 40)),
          onPressed: () => widget.value > 1
              ? widget.onChanged(widget.value - 1)
              : widget.onRemove(),
          icon: Icon(
            widget.value > 1
                ? Icons.remove_rounded
                : Icons.delete_outline_rounded,
          ),
        ),
        SizedBox(
          width: 52,
          height: 36,
          child: TextField(
            key: widget.fieldKey,
            controller: _controller,
            focusNode: _focus,
            textAlign: TextAlign.center,
            style: text.titleSmall,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              filled: true,
              fillColor: AppColors.surface,
              semanticCounterText: context.tr('sell.quantity'),
            ),
            onChanged: _typed,
            onSubmitted: (_) => _commit(),
          ),
        ),
        IconButton(
          tooltip: context.tr('sell.addOne'),
          iconSize: 18,
          style: IconButton.styleFrom(minimumSize: const Size(36, 40)),
          onPressed: atMax ? null : () => widget.onChanged(widget.value + 1),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

/// Label / value line used in details dialogs.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: text.bodyMedium!.copyWith(color: AppColors.inkMuted),
            ),
          ),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}

/// Small table inside a details dialog (lines, payments). Columns share
/// the width by flex; numeric columns align to the end.
class MiniTable extends StatelessWidget {
  const MiniTable({super.key, required this.columns, required this.rows});

  final List<TableColumn> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget row(List<String> cells, {bool header = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: Space.sm),
      decoration: BoxDecoration(
        color: header ? AppColors.paper : null,
        border: const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              flex: columns[i].flex,
              child: Text(
                cells[i],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: columns[i].numeric ? TextAlign.end : TextAlign.start,
                style: header
                    ? text.labelMedium!.copyWith(color: AppColors.inkMuted)
                    : text.bodyMedium,
              ),
            ),
        ],
      ),
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row([for (final c in columns) c.label], header: true),
          for (final cells in rows) row(cells),
        ],
      ),
    );
  }
}
