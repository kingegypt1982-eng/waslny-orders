import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasalny_orders/screens/payment_redirect_screen.dart';

void main() {
  testWidgets('payment redirect confirms in English off an Arabic device', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await tester.pumpWidget(const MaterialApp(home: PaymentRedirectScreen()));

    expect(find.text('Payment completed'), findsOneWidget);
    expect(find.text('Back to the app'), findsOneWidget);
    expect(find.text('Payment completed'), findsOneWidget);
  });

  testWidgets('payment redirect confirms in Arabic on an Arabic device', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('ar');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await tester.pumpWidget(const MaterialApp(home: PaymentRedirectScreen()));

    expect(find.text('تم إتمام عملية الدفع'), findsOneWidget);
    expect(find.text('العودة إلى التطبيق'), findsOneWidget);
  });
}
