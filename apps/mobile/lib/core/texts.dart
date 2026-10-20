import 'package:flutter/widgets.dart';

/// Shared UI texts.
///
/// The raw API enums (e.g. `SPARE_PARTS`) must never reach the screen: every
/// category goes through [categoryLabel] and every bottom-navigation label
/// through [homeTabLabels], which follows the device language.
///
/// Note: this file is the mobile-side source of truth for those labels; the
/// same mapping is currently duplicated inline in the trip and order-review
/// screens.

/// Arabic label for a shipment category value coming from the API.
/// Unknown or missing values fall back to a generic "shipment".
String categoryLabel(Object? category) => switch (category) {
  'PAPERS' => 'مستندات وأوراق',
  'MATERIALS' => 'مواد',
  'GOODS' => 'بضائع',
  'SPARE_PARTS' => 'قطع غيار',
  'PACKAGE' => 'طرد',
  'OTHER' => 'أخرى',
  'MEDICINES' => 'أدوية',
  'PURCHASES' => 'مشتريات',
  'FOOD' => 'طعام ومشروبات',
  'ELECTRONICS' => 'إلكترونيات',
  _ => 'شحنة',
};

/// Whether the device's preferred language is Arabic.
///
/// Read straight from the platform dispatcher so it works without adding
/// `flutter_localizations` / `supportedLocales` to the app.
bool deviceIsArabic() =>
    WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ar';

/// Bottom-navigation labels for the current role, in the device language.
List<String> homeTabLabels({required bool captain}) {
  final arabic = deviceIsArabic();
  if (captain) {
    return arabic
        ? const ['الرئيسية', 'الرحلات', 'المحفظة', 'الملف']
        : const ['Home', 'Trips', 'Wallet', 'Profile'];
  }
  return arabic
      ? const ['الرئيسية', 'طلباتي', 'الملف']
      : const ['Home', 'Orders', 'Profile'];
}

/// Picks the Arabic text on an Arabic device and the English one otherwise.
///
/// Lightweight stand-in for full localisation (the app has no
/// `flutter_localizations` setup yet) so every string has a single source.
String tr({required String ar, required String en}) =>
    deviceIsArabic() ? ar : en;

/// Localised currency symbol ("ج.م" in Arabic, "EGP" otherwise).
String currencyLabel() => tr(ar: 'ج.م', en: 'EGP');

/// A money amount, always shown to two decimals with the localised currency.
String moneyLabel(double value) =>
    '${currencyLabel()} ${value.toStringAsFixed(2)}';

/// Label for a wallet transaction type. Arabic is translated; English keeps
/// the historical raw display (`TOP_UP` -> `TOP UP`).
String walletTransactionLabel(Object? type) {
  if (!deviceIsArabic()) {
    return '${type ?? 'Transaction'}'.replaceAll('_', ' ');
  }
  return switch (type) {
    'TOP_UP' => 'شحن رصيد',
    'ORDER_COMMISSION' => 'عمولة طلب',
    'COMMISSION_REFUND' => 'استرداد عمولة',
    'ADJUSTMENT' => 'تسوية',
    _ => 'معاملة',
  };
}
