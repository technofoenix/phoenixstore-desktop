import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';

/// Asks for the customer printed on a facture: contact details plus the
/// fiscal identifiers. Name, address and NIF are required. Returns null when
/// the user cancels.
Future<DocumentCustomer?> showCustomerInfoDialog(
  BuildContext context, {
  required DocumentCustomer initial,
}) => showDialog<DocumentCustomer>(
  context: context,
  builder: (_) => CustomerInfoDialog(initial: initial),
);

class CustomerInfoDialog extends StatefulWidget {
  const CustomerInfoDialog({super.key, required this.initial});

  final DocumentCustomer initial;

  @override
  State<CustomerInfoDialog> createState() => _CustomerInfoDialogState();
}

class _CustomerInfoDialogState extends State<CustomerInfoDialog> {
  late final _name = TextEditingController(text: widget.initial.name ?? '');
  late final _address = TextEditingController(
    text: widget.initial.address ?? '',
  );
  late final _phone = TextEditingController(text: widget.initial.phone ?? '');
  late final _email = TextEditingController(text: widget.initial.email ?? '');
  late final _nif = TextEditingController(text: widget.initial.nif ?? '');
  late final _nis = TextEditingController(text: widget.initial.nis ?? '');
  late final _rc = TextEditingController(text: widget.initial.rc ?? '');
  late final _ai = TextEditingController(text: widget.initial.ai ?? '');

  bool _submitted = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _phone,
      _email,
      _nif,
      _nis,
      _rc,
      _ai,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  DocumentCustomer get _value => DocumentCustomer(
    name: _name.text,
    address: _address.text,
    phone: _phone.text,
    email: _email.text,
    nif: _nif.text,
    nis: _nis.text,
    rc: _rc.text,
    ai: _ai.text,
  ).normalized;

  String? _required(TextEditingController controller) =>
      _submitted && controller.text.trim().isEmpty
      ? context.tr('invoiceCustomer.required')
      : null;

  void _submit() {
    setState(() => _submitted = true);
    if (!_value.isCompleteForInvoice) return;
    Navigator.of(context).pop(_value);
  }

  Widget _field(
    String key,
    TextEditingController controller, {
    bool required = false,
    bool ltr = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool autofocus = false,
  }) {
    final label = context.tr('invoiceCustomer.$key');
    return TextField(
      key: ValueKey('invoiceCustomer.$key'),
      controller: controller,
      autofocus: autofocus,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textDirection: ltr ? TextDirection.ltr : null,
      decoration: InputDecoration(
        labelText: required
            ? '$label *'
            : '$label (${context.tr('common.optional')})',
        errorText: required ? _required(controller) : null,
      ),
      onChanged: (_) {
        if (_submitted) setState(() {});
      },
      onSubmitted: maxLines == 1 ? (_) => _submit() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: Space.md),
        Expanded(child: b),
      ],
    );
    return AppDialog(
      width: 600,
      icon: Icons.receipt_long_rounded,
      title: context.tr('invoiceCustomer.title'),
      subtitle: context.tr('invoiceCustomer.subtitle'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(context.tr('invoiceCustomer.contact')),
          const SizedBox(height: Space.sm),
          _field('name', _name, required: true, autofocus: true),
          const SizedBox(height: Space.md),
          _field('address', _address, required: true, maxLines: 2),
          const SizedBox(height: Space.md),
          pair(
            _field(
              'phone',
              _phone,
              ltr: true,
              keyboardType: TextInputType.phone,
            ),
            _field(
              'email',
              _email,
              ltr: true,
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          const SizedBox(height: Space.xl),
          SectionLabel(context.tr('invoiceCustomer.fiscal')),
          const SizedBox(height: Space.xs),
          Text(
            context.tr('invoiceCustomer.fiscalHint'),
            style: text.bodySmall!.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: Space.sm),
          pair(
            _field('nif', _nif, required: true, ltr: true),
            _field('nis', _nis, ltr: true),
          ),
          const SizedBox(height: Space.md),
          pair(_field('rc', _rc, ltr: true), _field('ai', _ai, ltr: true)),
        ],
      ),
      secondary: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.tr('common.cancel')),
      ),
      primary: FilledButton.icon(
        key: const ValueKey('invoiceCustomer.submit'),
        onPressed: _submit,
        icon: const Icon(Icons.print_rounded, size: 18),
        label: Text(context.tr('invoiceCustomer.submit')),
      ),
    );
  }
}
