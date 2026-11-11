import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import 'auth_controller.dart';
import 'login_screen.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _passwordError;
  String? _confirmError;
  String? _serverError;
  bool _saving = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _serverError = null;
      _passwordError = _password.text.length < 8
          ? context.tr('errors.passwordShort')
          : null;
      _confirmError = _passwordError == null && _password.text != _confirm.text
          ? context.tr('errors.passwordMismatch')
          : null;
    });
    if (_passwordError != null || _confirmError != null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(_password.text);
    } catch (error) {
      if (mounted) setState(() => _serverError = toApiException(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ruleMet = _password.text.length >= 8;
    return Scaffold(
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(Space.lg),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: LanguagePicker(),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Space.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Panel(
                    padding: const EdgeInsets.all(Space.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                            child: const Icon(
                              Icons.key_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.lg),
                        Text(
                          context.tr('auth.changeTitle'),
                          style: text.headlineSmall,
                        ),
                        const SizedBox(height: Space.sm),
                        Text(
                          context.tr('auth.changeSubtitle'),
                          style: text.bodyMedium!.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: Space.xl),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: context.tr('auth.newPassword'),
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            errorText: _passwordError,
                            suffixIcon: IconButton(
                              tooltip: context.tr(
                                _obscure
                                    ? 'auth.showPassword'
                                    : 'auth.hidePassword',
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          onChanged: (_) =>
                              setState(() => _passwordError = null),
                        ),
                        const SizedBox(height: Space.sm),
                        Row(
                          children: [
                            Icon(
                              ruleMet
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 16,
                              color: ruleMet
                                  ? AppColors.success
                                  : AppColors.inkMuted,
                            ),
                            const SizedBox(width: Space.xs),
                            Text(
                              context.tr('auth.passwordRule'),
                              style: text.bodySmall!.copyWith(
                                color: ruleMet
                                    ? AppColors.success
                                    : AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.lg),
                        TextField(
                          controller: _confirm,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: context.tr('auth.confirmPassword'),
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            errorText: _confirmError,
                          ),
                          onChanged: (_) {
                            if (_confirmError != null) {
                              setState(() => _confirmError = null);
                            }
                          },
                          onSubmitted: (_) => _submit(),
                        ),
                        if (_serverError != null) ...[
                          const SizedBox(height: Space.lg),
                          InlineMessage(_serverError!),
                        ],
                        const SizedBox(height: Space.xl),
                        FilledButton(
                          onPressed: _saving ? null : _submit,
                          child: _saving
                              ? const ButtonSpinner(color: AppColors.inkMuted)
                              : Text(context.tr('auth.savePassword')),
                        ),
                        const SizedBox(height: Space.sm),
                        TextButton.icon(
                          onPressed: () => ref
                              .read(authControllerProvider.notifier)
                              .logout(),
                          icon: const DirIcon(Icons.logout_rounded, size: 18),
                          label: Text(context.tr('common.signOut')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
