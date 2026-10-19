import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasalny_orders/core/api_client.dart';
import 'package:wasalny_orders/screens.dart' show WalletScreen;

void main() {
  testWidgets('captain wallet renders Decimal strings without a type error', (
    tester,
  ) async {
    final api = _WalletApi(await _preferences());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(api.preferences),
          apiClientProvider.overrideWithValue(api),
        ],
        child: const MaterialApp(home: WalletScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('EGP 39.44'), findsOneWidget);
    expect(find.text('TOP UP'), findsOneWidget);
    expect(find.text('EGP 10.00'), findsOneWidget);
  });
}

Future<SharedPreferences> _preferences() async {
  SharedPreferences.setMockInitialValues({
    'session_user': jsonEncode({'id': 'captain-1', 'role': 'CAPTAIN'}),
  });
  return SharedPreferences.getInstance();
}

class _WalletApi extends ApiClient {
  _WalletApi(super.preferences);

  @override
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, dynamic>? query,
  }) async => {
    'balance': '39.44',
    'user': {
      'id': 'captain-1',
      'walletTransactions': [
        {
          'id': 't1',
          'type': 'TOP_UP',
          'amount': '-10.00',
          'createdAt': '2026-10-19T10:00:00.000Z',
        },
      ],
    },
  };
}
