import '../localization/app_localizations.dart';

/// Keys a licence's `features` set may contain. Plain strings, not an enum:
/// a licence carrying a key this build doesn't recognise yet (an older app
/// build, or one from a different fork) should be ignored, not fail to
/// parse — `Set<String>.contains` already does that for free.
abstract final class LicenseFeature {
  /// Gates the "Historique client" rollup on the client detail screen:
  /// previous rentals, late returns, unpaid balance, damage incidents.
  static const customerHistory = 'customer_history';

  /// Gates the "Rentabilité" section on a vehicle's detail page and the
  /// fleet-wide ranked report at /vehicles/profitability: revenue, rental
  /// days, utilization, expenses by category, net profit.
  static const profitability = 'profitability';
}

/// A display label for a feature key, for the licence card in Settings.
/// Falls back to the raw key for one this build doesn't recognise, rather
/// than hiding it — an agency should still see *something* is included even
/// running an older build than the one a licence was issued for.
String licenseFeatureLabel(String key) => switch (key) {
      LicenseFeature.customerHistory => AppCopy.customerHistoryFeatureLabel,
      LicenseFeature.profitability => AppCopy.profitabilityFeatureLabel,
      _ => key,
    };
