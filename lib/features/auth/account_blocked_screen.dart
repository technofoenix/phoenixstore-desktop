import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/session_events.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import 'auth_controller.dart';

class AccountBlockedScreen extends ConsumerWidget {
  const AccountBlockedScreen({super.key, required this.message});

  /// Reason sent by the server.
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Panel(
              padding: const EdgeInsets.all(Space.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(Radii.lg),
                    ),
                    child: const Icon(
                      Icons.block_rounded,
                      color: AppColors.danger,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  Text(
                    context.tr('auth.blockedTitle'),
                    style: text.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    message,
                    style: text.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    context.tr('auth.blockedHint'),
                    style: text.bodyMedium!.copyWith(color: AppColors.inkMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Space.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        ref.read(accountBlockedProvider.notifier).reset();
                        await ref
                            .read(authControllerProvider.notifier)
                            .logout();
                      },
                      icon: const DirIcon(Icons.logout_rounded, size: 18),
                      label: Text(context.tr('common.signOut')),
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
