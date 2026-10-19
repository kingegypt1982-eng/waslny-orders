import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasalny_orders/core/api_client.dart';
import 'package:wasalny_orders/screens/captain_availability_screen.dart';

void main() {
  testWidgets('feed lists nearby orders with distance and net earnings', (
    tester,
  ) async {
    final api = _FakeApi(await _preferences())
      ..orders = [_order(id: 'o1', distance: 0.6)];
    await _pumpAvailability(tester, api);

    expect(find.textContaining('الطلبات القريبة (1)'), findsOneWidget);
    expect(find.textContaining('PACKAGE · DEMO-1'), findsOneWidget);
    expect(find.text('0.6 كم من موقعك'), findsOneWidget);
    expect(find.text('صافي ربحك: EGP 40'), findsOneWidget);
    expect(find.text('قبول الطلب'), findsOneWidget);
    expect(find.text('تخطي'), findsOneWidget);
  });

  testWidgets('offline captain sees the empty state instead of the feed', (
    tester,
  ) async {
    final api = _FakeApi(await _preferences())
      ..profile['isOnline'] = false
      ..orders = [_order(id: 'o1', distance: 0.6)];
    await _pumpAvailability(tester, api);

    expect(find.text('أنت غير متصل الآن'), findsOneWidget);
    expect(find.text('قبول الطلب'), findsNothing);
  });

  testWidgets('skipping an order calls the API and removes the card', (
    tester,
  ) async {
    final api = _FakeApi(await _preferences())
      ..orders = [_order(id: 'o1', distance: 0.6)];
    await _pumpAvailability(tester, api);

    await tester.tap(find.text('تخطي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(api.postPaths, ['/orders/o1/skip']);
    expect(find.text('قبول الطلب'), findsNothing);
    expect(find.textContaining('الطلبات القريبة (0)'), findsOneWidget);
  });

  testWidgets('accepting an order opens the trip screen', (tester) async {
    final api = _FakeApi(await _preferences())
      ..orders = [_order(id: 'o1', distance: 0.6)];
    await _pumpAvailability(tester, api);

    await tester.tap(find.text('قبول الطلب'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpAndSettle();

    expect(api.postPaths, ['/orders/o1/accept']);
    expect(find.text('TRIP o1'), findsOneWidget);
  });

  testWidgets('a 409 on accept keeps the captain on the feed with a message', (
    tester,
  ) async {
    final api = _FakeApi(await _preferences())
      ..orders = [_order(id: 'o1', distance: 0.6)]
      ..conflictAccept = true;
    await _pumpAvailability(tester, api);

    await tester.tap(find.text('قبول الطلب'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(find.text('Order was accepted by another captain'), findsOneWidget);
    expect(find.text('TRIP o1'), findsNothing);
  });
}

Future<SharedPreferences> _preferences() async {
  SharedPreferences.setMockInitialValues({
    'session_user': jsonEncode({'id': 'captain-1', 'role': 'CAPTAIN'}),
  });
  return SharedPreferences.getInstance();
}

Map<String, dynamic> _order({required String id, required double distance}) => {
  'id': id,
  'reference': 'DEMO-1',
  'category': 'PACKAGE',
  'status': 'SEARCHING_CAPTAIN',
  'price': 50,
  'commission': 10,
  'pickupLabel': 'نقطة الاستلام',
  'deliveryLabel': 'نقطة التسليم',
  'distanceToPickupKm': distance,
};

Future<void> _pumpAvailability(WidgetTester tester, _FakeApi api) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/captain/availability',
    routes: [
      GoRoute(
        path: '/captain/availability',
        builder: (context, state) => const CaptainAvailabilityScreen(),
      ),
      GoRoute(
        path: '/captain/trip/:id',
        builder: (context, state) =>
            Scaffold(body: Text('TRIP ${state.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(api.preferences),
        apiClientProvider.overrideWithValue(api),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

class _FakeApi extends ApiClient {
  _FakeApi(super.preferences);

  final postPaths = <String>[];
  final patchBodies = <Map<String, dynamic>>[];
  bool conflictAccept = false;
  Map<String, dynamic> profile = {
    'isOnline': true,
    'serviceRadiusKm': 10,
    'radiusBand': {'min': 2, 'max': 15},
  };
  List<Map<String, dynamic>> orders = [];

  @override
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, dynamic>? query,
  }) async => path == '/captains/me'
      ? Map<String, dynamic>.from(profile)
      : <String, dynamic>{};

  @override
  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async => path == '/orders/available'
      ? orders.map((order) => Map<String, dynamic>.from(order)).toList()
      : <dynamic>[];

  @override
  Future<Map<String, dynamic>> post(String path, {Object? data}) async {
    postPaths.add(path);
    if (conflictAccept && path.endsWith('/accept')) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 409,
          data: {'message': 'Order was accepted by another captain'},
        ),
      );
    }
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> patch(String path, {Object? data}) async {
    patchBodies.add({
      'path': path,
      if (data is Map) ...Map<String, dynamic>.from(data),
    });
    return <String, dynamic>{};
  }
}
