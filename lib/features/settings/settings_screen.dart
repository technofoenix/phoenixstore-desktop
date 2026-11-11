import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/i18n/languages.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.userName,
    required this.boutique,
    this.userPhone,
  });

  final String userName;
  final String? userPhone;
  final String boutique;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final current = context.locale.languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(title: context.tr('settings.title')),
        Expanded(
          child: SingleChildScrollView(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Panel(
                      padding: const EdgeInsets.all(Space.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.tr('settings.language'),
                            style: text.titleMedium,
                          ),
                          const SizedBox(height: Space.xs),
                          Text(
                            context.tr('settings.languageHint'),
                            style: text.bodyMedium!.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: Space.lg),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final count = AppLanguages.all.length;
                              final columns = constraints.maxWidth >= 520
                                  ? count
                                  : 1;
                              final width =
                                  (constraints.maxWidth -
                                      Space.md * (columns - 1)) /
                                  columns;
                              return Wrap(
                                spacing: Space.md,
                                runSpacing: Space.md,
                                children: [
                                  for (final language in AppLanguages.all)
                                    SizedBox(
                                      width: width,
                                      child: _LanguageCard(
                                        language: language,
                                        selected: language.code == current,
                                        onTap: () =>
                                            context.setLocale(language.locale),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                    Panel(
                      padding: const EdgeInsets.all(Space.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.tr('settings.about'),
                            style: text.titleMedium,
                          ),
                          const SizedBox(height: Space.md),
                          _InfoRow(
                            label: context.tr('settings.account'),
                            value: userPhone == null || userPhone!.isEmpty
                                ? userName
                                : '$userName · ${ltr(userPhone!)}',
                          ),
                          _InfoRow(
                            label: context.tr('settings.boutique'),
                            value: boutique.isEmpty
                                ? context.tr('common.none')
                                : boutique,
                          ),
                          _InfoRow(
                            label: context.tr('settings.server'),
                            value: ltr(AppConfig.apiBaseUrl),
                          ),
                          _InfoRow(
                            label: context.tr('settings.version'),
                            value: ltr(AppConfig.version),
                            last: true,
                          ),
                        ],
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
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Each name is drawn in its own script and direction.
    final nameStyle = text.titleLarge!.copyWith(
      fontFamily: language.font,
      color: selected ? Colors.white : AppColors.ink,
    );
    return HoverLift(
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          key: ValueKey('lang-${language.code}'),
          color: selected ? AppColors.ink : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
            side: BorderSide(
              color: selected ? AppColors.ink : AppColors.line,
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: selected ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Directionality(
                          textDirection: language.rtl
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: Text(language.name, style: nameStyle),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ltr(language.code.toUpperCase()),
                          style: text.labelSmall!.copyWith(
                            color: selected
                                ? AppColors.sidebarMuted
                                : AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: selected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            key: ValueKey('on'),
                            color: Colors.white,
                          )
                        : const Icon(
                            Icons.circle_outlined,
                            key: ValueKey('off'),
                            color: AppColors.line,
                          ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
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
