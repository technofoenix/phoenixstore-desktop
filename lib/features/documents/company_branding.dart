import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../api/desktop_api.dart';

/// Company settings + logo bytes, printed as the seller on every document.
class CompanyBranding {
  CompanyBranding({required this.company, this.logo, DateTime? loadedAt})
    : loadedAt = loadedAt ?? DateTime.now();

  final CompanySettings company;

  /// PNG/JPEG bytes of the company logo; null when none is set or it failed
  /// to download (the document then shows the company name only).
  final Uint8List? logo;

  /// When it was fetched; documents refresh it once it is a few minutes old
  /// so a logo or address changed in the backoffice shows up without a
  /// restart.
  final DateTime loadedAt;

  /// Used when the settings cannot be loaded (offline): the boutique name.
  factory CompanyBranding.fallback(String name) =>
      CompanyBranding(company: CompanySettings(name: name));
}

/// How long fetched branding is reused before printing fetches it again.
const brandingMaxAge = Duration(minutes: 2);

/// Cached between prints; [readCompanyBranding] refreshes it when stale.
final companyBrandingProvider = FutureProvider<CompanyBranding>((ref) async {
  final api = ref.watch(desktopApiProvider);
  final company = await api.company();
  final logoUrl = company.logoUrl;
  final logo = logoUrl == null || logoUrl.isEmpty
      ? null
      : await api.downloadBytes(logoUrl);
  return CompanyBranding(company: company, logo: logo);
});

/// The branding to print with; falls back to [fallbackName] on failure so a
/// document can still be printed when the settings are unreachable.
Future<CompanyBranding> readCompanyBranding(
  WidgetRef ref, {
  required String fallbackName,
}) async {
  try {
    var branding = await ref.read(companyBrandingProvider.future);
    if (DateTime.now().difference(branding.loadedAt) > brandingMaxAge) {
      ref.invalidate(companyBrandingProvider);
      branding = await ref.read(companyBrandingProvider.future);
    }
    return branding;
  } catch (_) {
    ref.invalidate(companyBrandingProvider);
    return CompanyBranding.fallback(fallbackName);
  }
}
