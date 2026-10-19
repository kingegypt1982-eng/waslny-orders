import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasalny_orders/core/api_client.dart';
import 'package:wasalny_orders/screens/captain_trip_screen.dart';

void main() {
  testWidgets('accepted trip advances to the pickup point', (tester) async {
    final api = _FakeTripApi(await _preferences(), _order('ACCEPTED'));
    await _pumpTrip(tester, api);

    expect(find.text('تم قبول الطلب'), findsOneWidget);
    await tester.tap(find.text('وصلت لموقع الاستلام'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(api.patchCalls.single['path'], '/orders/o1/status');
    expect(api.patchCalls.single['status'], 'ARRIVED_AT_PICKUP');
    expect(find.text('تصوير الشحنة وتأكيد الاستلام'), findsOneWidget);
  });

  testWidgets('picked-up trip starts the delivery leg', (tester) async {
    final api = _FakeTripApi(await _preferences(), _order('PICKED_UP'));
    await _pumpTrip(tester, api);

    await tester.tap(find.text('بدء التوصيل للعميل'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(api.patchCalls.single['status'], 'ON_THE_WAY');
    expect(find.text('الشحنة في الطريق'), findsOneWidget);
  });

  testWidgets('on-the-way trip asks for a delivery proof photo', (
    tester,
  ) async {
    final api = _FakeTripApi(await _preferences(), _order('ON_THE_WAY'));
    await _pumpTrip(tester, api);

    expect(find.text('تصوير التسليم وتأكيده'), findsOneWidget);
    expect(find.text('تفاصيل الشحنة'), findsOneWidget);
    expect(find.text('نقطة الاستلام'), findsOneWidget);
    expect(find.text('نقطة التسليم'), findsOneWidget);
  });

  testWidgets('delivered trip shows the earnings summary while waiting', (
    tester,
  ) async {
    final api = _FakeTripApi(await _preferences(), _order('DELIVERED'));
    await _pumpTrip(tester, api);

    expect(find.text('ملخص الأرباح المتوقعة'), findsOneWidget);
    expect(find.text('صافي ربحك'), findsOneWidget);
    expect(find.text('EGP 40'), findsOneWidget);
    expect(find.text('EGP 50'), findsOneWidget);
    expect(
      find.text(
        'في انتظار تأكيد العميل لاستلام الشحنة لإكمال الطلب وتحويل الأرباح.',
      ),
      findsOneWidget,
    );
    expect(find.text('تصوير التسليم وتأكيده'), findsNothing);
  });

  testWidgets('completed trip shows the final summary and timeline', (
    tester,
  ) async {
    final api = _FakeTripApi(await _preferences(), _order('COMPLETED'))
      ..events = [
        {
          'toStatus': 'ACCEPTED',
          'fromStatus': 'SEARCHING_CAPTAIN',
          'actorRole': 'CAPTAIN',
          'note': 'Order accepted',
        },
        {
          'toStatus': 'COMPLETED',
          'fromStatus': 'DELIVERED',
          'actorRole': 'CLIENT',
          'note': 'Client confirmed delivery',
        },
      ]
      ..proofs = [
        {'id': 'p1', 'type': 'PICKUP', 'hasPhoto': true},
        {'id': 'p2', 'type': 'DELIVERY', 'hasPhoto': true},
      ];
    await _pumpTrip(tester, api);

    expect(find.text('ملخص الرحلة والأرباح'), findsOneWidget);
    expect(
      find.text('تم إكمال الطلب وتحويل الأرباح صافية إلى محفظتك.'),
      findsOneWidget,
    );
    expect(find.text('سجل الرحلة'), findsOneWidget);
    expect(find.text('Client confirmed delivery'), findsOneWidget);
    expect(
      find.text('إثباتات مرفوعة: صورة الاستلام، صورة التسليم'),
      findsOneWidget,
    );
  });

  testWidgets('cancelled trip hides every action button', (tester) async {
    final api = _FakeTripApi(await _preferences(), _order('CANCELLED'));
    await _pumpTrip(tester, api);

    expect(find.text('تم إلغاء الطلب'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}

Future<SharedPreferences> _preferences() async {
  SharedPreferences.setMockInitialValues({
    'session_user': jsonEncode({'id': 'captain-1', 'role': 'CAPTAIN'}),
  });
  return SharedPreferences.getInstance();
}

Map<String, dynamic> _order(String status) => {
  'id': 'o1',
  'reference': 'DEMO-1',
  'status': status,
  'category': 'PACKAGE',
  'price': 50,
  'commission': 10,
  'distanceKm': 3.4,
  'pickupLabel': 'نقطة الاستلام',
  'deliveryLabel': 'نقطة التسليم',
  'recipientName': 'أحمد',
  'recipientPhone': '01000000000',
};

Future<void> _pumpTrip(WidgetTester tester, _FakeTripApi api) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(api.preferences),
        apiClientProvider.overrideWithValue(api),
      ],
      child: const MaterialApp(home: CaptainTripScreen(orderId: 'o1')),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

class _FakeTripApi extends ApiClient {
  _FakeTripApi(super.preferences, this.order);

  final Map<String, dynamic> order;
  final patchCalls = <Map<String, dynamic>>[];
  List<dynamic> events = [];
  List<dynamic> proofs = [];

  @override
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, dynamic>? query,
  }) async => Map<String, dynamic>.from(order);

  @override
  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async => path.endsWith('/events') ? events : proofs;

  @override
  Future<Map<String, dynamic>> patch(String path, {Object? data}) async {
    final body = data is Map ? Map<String, dynamic>.from(data) : {};
    patchCalls.add({'path': path, ...body});
    if (body['status'] is String) order['status'] = body['status'] as String;
    return <String, dynamic>{};
  }
}
