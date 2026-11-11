import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/languages.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  String? _phoneError;
  String? _passwordError;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phoneOk = RegExp(r'^0[5-7]\d{8}$').hasMatch(_phone.text.trim());
    setState(() {
      _phoneError = phoneOk ? null : context.tr('errors.phoneInvalid');
      _passwordError = _password.text.isEmpty
          ? context.tr('errors.passwordRequired')
          : null;
    });
    if (_phoneError != null || _passwordError != null) return;
    await ref
        .read(authControllerProvider.notifier)
        .login(phoneNumber: _phone.text.trim(), password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final serverError = auth.hasError
        ? toApiException(auth.error!).message
        : null;
    final isLoading = auth.isLoading;
    final text = Theme.of(context).textTheme;

    final form = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('auth.signInTitle'), style: text.displaySmall),
            const SizedBox(height: Space.sm),
            Text(
              context.tr('auth.signInSubtitle'),
              style: text.bodyLarge!.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: Space.xxl),
            TextField(
              key: const ValueKey('login.phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: InputDecoration(
                labelText: context.tr('auth.phone'),
                hintText: context.tr('auth.phoneHint'),
                prefixIcon: const Icon(Icons.phone_iphone_rounded),
                errorText: _phoneError,
                errorMaxLines: 2,
              ),
              onChanged: (_) {
                if (_phoneError != null) setState(() => _phoneError = null);
              },
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: Space.lg),
            TextField(
              key: const ValueKey('login.password'),
              controller: _password,
              focusNode: _passwordFocus,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: context.tr('auth.password'),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                errorText: _passwordError,
                suffixIcon: IconButton(
                  tooltip: context.tr(
                    _obscure ? 'auth.showPassword' : 'auth.hidePassword',
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              onChanged: (_) {
                if (_passwordError != null) {
                  setState(() => _passwordError = null);
                }
              },
              onSubmitted: (_) => _submit(),
            ),
            if (serverError != null) ...[
              const SizedBox(height: Space.lg),
              InlineMessage(serverError),
            ],
            const SizedBox(height: Space.xl),
            SizedBox(
              height: 50,
              child: FilledButton(
                key: const ValueKey('login.submit'),
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const ButtonSpinner(color: AppColors.inkMuted)
                    : Text(context.tr('auth.signIn')),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showBrand = constraints.maxWidth >= 900;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showBrand) const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(
                flex: 6,
                child: Column(
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.xxl,
                            vertical: Space.lg,
                          ),
                          child: form,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Compact language choice for screens shown before sign-in.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.locale.languageCode;
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(minimumSize: const Size(0, 40)),
      selected: {current},
      onSelectionChanged: (s) => context.setLocale(Locale(s.first)),
      segments: [
        for (final language in AppLanguages.all)
          ButtonSegment(
            value: language.code,
            label: Text(
              language.name,
              key: ValueKey('login.lang-${language.code}'),
              style: TextStyle(fontFamily: language.font),
            ),
          ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final features = [
      (Icons.qr_code_scanner_rounded, 'auth.feature1'),
      (Icons.print_rounded, 'auth.feature2'),
      (Icons.account_balance_wallet_rounded, 'auth.feature3'),
    ];
    return Container(
      color: AppColors.sidebar,
      child: Stack(
        children: [
          // A single brand-red arc gives the panel its shape.
          PositionedDirectional(
            end: -160,
            bottom: -160,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.55),
                  width: 56,
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 96,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                          child: Image.asset('assets/logos/logo-pos.png'),
                        ),
                        const SizedBox(width: Space.md),
                        Text(
                          context.tr('app.name'),
                          style: text.titleMedium!.copyWith(
                            color: AppColors.sidebarText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 64),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('auth.brandTitle'),
                          style: text.displaySmall!.copyWith(
                            color: Colors.white,
                            fontSize: 40,
                          ),
                        ),
                        const SizedBox(height: Space.md),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Text(
                            context.tr('auth.brandLine'),
                            style: text.bodyLarge!.copyWith(
                              color: AppColors.sidebarMuted,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.xxl),
                        for (final (icon, key) in features)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.md),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.sidebarHover,
                                    borderRadius: BorderRadius.circular(
                                      Radii.md,
                                    ),
                                  ),
                                  child: Icon(
                                    icon,
                                    size: 18,
                                    color: AppColors.sidebarText,
                                  ),
                                ),
                                const SizedBox(width: Space.md),
                                Flexible(
                                  child: Text(
                                    context.tr(key),
                                    style: text.bodyLarge!.copyWith(
                                      color: AppColors.sidebarText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
