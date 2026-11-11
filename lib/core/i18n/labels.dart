import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// Human labels for API codes (payment methods, statuses, categories). An
/// unknown code is shown as sent by the server instead of a missing key.
String codeLabel(BuildContext context, String group, String? code) {
  if (code == null || code.isEmpty) return context.tr('common.none');
  final key = '$group.$code';
  return context.trExists(key) ? context.tr(key) : code;
}

String paymentLabel(BuildContext context, String? code) =>
    codeLabel(context, 'payment', code);

String paymentStatusLabel(BuildContext context, String? code) =>
    codeLabel(context, 'paymentStatus', code);

String orderStatusLabel(BuildContext context, String? code) =>
    codeLabel(context, 'orderStatus', code);

String expenseCategoryLabel(BuildContext context, String? code) =>
    codeLabel(context, 'expenseCategory', code);
