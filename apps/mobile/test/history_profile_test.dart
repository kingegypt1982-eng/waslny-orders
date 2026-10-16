import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasalny_orders/core/api_client.dart';
import 'package:wasalny_orders/screens.dart';
import 'package:wasalny_orders/screens/history_screen.dart';
import 'package:wasalny_orders/screens/profile_screen.dart';

void main() {
  group('HistoryScreen', () {
    testWidgets('chips filter orders by status', (tester) async {
      final api = _HPApiClient(await _preferences());
      await _pumpHistory(tester, api);

      expect(find.text('REF-SEARCHING'), findsOneWidget);
      expect(find.text('REF-WAY'), findsOneWidget);
      expect(find.text('REF-DONE'), findsOneWidget);
      expect(find.text('REF-CANCELLED'), findsOneWidget);

      await tester.tap(find.text('نشطة'));
      await tester.pumpAndSettle();
      expect(find.text('REF-SEARCHING'), findsOneWidget);
      expect(find.text('REF-WAY'), findsOneWidget);
      expect(find.text('REF-DONE'), findsNothing);
      expect(find.text('REF-CANCELLED'), findsNothing);

      await tester.tap(find.text('مكتملة'));
      await tester.pumpAndSettle();
      expect(find.text('REF-DONE'), findsOneWidget);
      expect(find.text('REF-SEARCHING'), findsNothing);

      await tester.tap(find.text('ملغاة'));
      await tester.pumpAndSettle();
      expect(find.text('REF-CANCELLED'), findsOneWidget);
      expect(find.text('REF-DONE'), findsNothing);

      await tester.tap(find.text('الكل'));
      await tester.pumpAndSettle();
      expect(find.text('REF-DONE'), findsOneWidget);
      expect(find.text('REF-CANCELLED'), findsOneWidget);
    });

    testWidgets('empty message per filter', (tester) async {
      final api = _HPApiClient(await _preferences())
        ..live = _HPApiClient.all.take(2).toList();
      await _pumpHistory(tester, api);

      await tester.tap(find.text('ملغاة'));
      await tester.pumpAndSettle();
      expect(find.text('لا توجد طلبات ملغاة'), findsOneWidget);
    });

    testWidgets('error with retry', (tester) async {
      final api = _HPApiClient(await _preferences())
        ..error = Exception('offline');
      await _pumpHistory(tester, api);

      expect(find.text('إعادة المحاولة'), findsOneWidget);
      api.error = null;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(find.text('REF-DONE'), findsOneWidget);
    });

    testWidgets('tap opens tracking', (tester) async {
      final api = _HPApiClient(await _preferences());
      final router = _historyRouter(api);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('REF-WAY'));
      await tester.pumpAndSettle();
      expect(find.text('تتبع الطلب o-way'), findsOneWidget);
    });
  });

  group('ClientHome feed', () {
    testWidgets('shows active orders only', (tester) async {
      final api = _HPApiClient(await _preferences());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: MaterialApp(
            home: Scaffold(
              body: ClientHome(
                user: const {'name': 'Karim', 'role': 'CLIENT'},
                isArabic: true,
                onToggleLanguage: () {},
                onViewAll: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REF-SEARCHING'), findsOneWidget);
      expect(find.text('REF-WAY'), findsOneWidget);
      expect(find.text('REF-DONE'), findsNothing);
      expect(find.text('REF-CANCELLED'), findsNothing);
    });
  });

  group('ProfileScreen', () {
    testWidgets('shows session name, email and arabic role', (tester) async {
      final api = _HPApiClient(await _preferences(session: true));
      await _pumpProfile(tester, api);

      expect(find.text('Karim'), findsOneWidget);
      expect(find.text('k@x.com'), findsNWidgets(2));
      expect(find.text('عميل'), findsOneWidget);
    });

    testWidgets('notifications tile opens inbox', (tester) async {
      final api = _HPApiClient(await _preferences(session: true));
      final router = _profileRouter(api);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            preferencesProvider.overrideWithValue(api.preferences),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('الإشعارات'));
      await tester.pumpAndSettle();
      expect(find.text('صندوق الإشعارات'), findsOneWidget);
    });

    testWidgets('policies tile shows terms sheet', (tester) async {
      final api = _HPApiClient(await _preferences(session: true));
      await _pumpProfile(tester, api);

      await tester.tap(find.text('السياسات والشروط'));
      await tester.pumpAndSettle();

      expect(find.text('شروط استخدام العميل'), findsOneWidget);
      expect(find.text('نص الشروط للاختبار'), findsOneWidget);
    });

    testWidgets('help shows static text', (tester) async {
      final api = _HPApiClient(await _preferences(session: true));
      await _pumpProfile(tester, api);

      await tester.tap(find.text('المساعدة والدعم'));
      await tester.pumpAndSettle();

      expect(find.textContaining('support@waslny.com'), findsOneWidget);
    });

    testWidgets('sign out confirms and clears session', (tester) async {
      final preferences = await _preferences(session: true);
      final api = _HPApiClient(preferences);
      final router = _profileRouter(api);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            preferencesProvider.overrideWithValue(preferences),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('تسجيل الخروج'), 200);
      await tester.tap(find.text('تسجيل الخروج'));
      await tester.pumpAndSettle();
      expect(find.text('تسجيل الخروج؟'), findsOneWidget);

      await tester.tap(find.text('تسجيل الخروج').last);
      await tester.pumpAndSettle();
      expect(find.text('الصفحة الرئيسية'), findsOneWidget);
      expect(preferences.getString('session_user'), isNull);
    });
  });
}

Future<SharedPreferences> _preferences({bool session = false}) async {
  SharedPreferences.setMockInitialValues({
    if (session)
      'session_user': jsonEncode({
        'id': 'u1',
        'name': 'Karim',
        'email': 'k@x.com',
        'role': 'CLIENT',
      }),
  });
  return SharedPreferences.getInstance();
}

GoRouter _historyRouter(_HPApiClient api) => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HistoryScreen()),
    GoRoute(
      path: '/track/:id',
      builder: (context, state) =>
          Scaffold(body: Text('تتبع الطلب ${state.pathParameters['id']}')),
    ),
  ],
);

Future<void> _pumpHistory(WidgetTester tester, _HPApiClient api) async {
  final router = _historyRouter(api);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _profileRouter(_HPApiClient api) => GoRouter(
  initialLocation: '/profile',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) =>
          const Scaffold(body: Text('الصفحة الرئيسية')),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) =>
          const Scaffold(body: Text('صندوق الإشعارات')),
    ),
  ],
);

Future<void> _pumpProfile(WidgetTester tester, _HPApiClient api) async {
  final router = _profileRouter(api);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        preferencesProvider.overrideWithValue(api.preferences),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _HPApiClient extends ApiClient {
  _HPApiClient(super.preferences);

  static List<Map<String, dynamic>> get all => [
    {
      'id': 'o-search',
      'reference': 'REF-SEARCHING',
      'status': 'SEARCHING_CAPTAIN',
      'pickupLabel': 'A',
      'deliveryLabel': 'B',
      'price': 10,
      'createdAt': '2026-10-01T10:00:00.000Z',
    },
    {
      'id': 'o-way',
      'reference': 'REF-WAY',
      'status': 'ON_THE_WAY',
      'pickupLabel': 'A',
      'deliveryLabel': 'B',
      'price': 20,
      'createdAt': '2026-10-02T10:00:00.000Z',
    },
    {
      'id': 'o-done',
      'reference': 'REF-DONE',
      'status': 'DELIVERED',
      'pickupLabel': 'A',
      'deliveryLabel': 'B',
      'price': 30,
      'createdAt': '2026-10-03T10:00:00.000Z',
    },
    {
      'id': 'o-cancel',
      'reference': 'REF-CANCELLED',
      'status': 'CANCELLED',
      'pickupLabel': 'A',
      'deliveryLabel': 'B',
      'price': 40,
      'createdAt': '2026-10-04T10:00:00.000Z',
    },
  ];

  List<Map<String, dynamic>> live = _HPApiClient.all;
  Object? error;

  @override
  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    if (error != null) throw error!;
    return live.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    if (path == '/policies/TERMS_CLIENT') {
      return {
        'type': 'TERMS_CLIENT',
        'version': '1.0.0',
        'title': 'شروط استخدام العميل',
        'text': 'نص الشروط للاختبار',
      };
    }
    throw StateError('unexpected GET $path');
  }
}
