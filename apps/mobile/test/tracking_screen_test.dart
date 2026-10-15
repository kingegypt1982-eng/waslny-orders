import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasalny_orders/core/api_client.dart';
import 'package:wasalny_orders/screens/tracking_screen.dart';

void main() {
  testWidgets('search tracking fits both pins and keeps cancel fixed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _TrackingApiClient(await _preferences());
    await _pumpTracking(tester, api);

    expect(find.text('جارٍ البحث عن مندوب'), findsOneWidget);
    expect(find.byKey(const ValueKey('cancel-order-button')), findsOneWidget);

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final cameraFit = map.options.initialCameraFit! as FitBounds;
    expect(cameraFit.bounds.south, 30.0);
    expect(cameraFit.bounds.north, 30.1);
    expect(cameraFit.bounds.west, 31.0);
    expect(cameraFit.bounds.east, 31.1);
    expect(cameraFit.padding, const EdgeInsets.all(32));
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(2),
    );
    final mapHeight = tester.getSize(find.byType(FlutterMap)).height;
    expect(mapHeight, greaterThan(150));
    expect(mapHeight, lessThan(300));
    expect(
      tester.getRect(find.byKey(const ValueKey('cancel-order-button'))).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
  });

  testWidgets('client confirms searching order cancellation once', (
    tester,
  ) async {
    final api = _TrackingApiClient(await _preferences())
      ..cancelCompleter = Completer<Map<String, dynamic>>();
    await _pumpTracking(tester, api);

    await tester.tap(find.byKey(const ValueKey('cancel-order-button')));
    await tester.pump();
    expect(find.text('إلغاء الطلب؟'), findsOneWidget);

    await tester.tap(find.text('نعم، ألغِ الطلب'));
    await tester.pump();
    expect(api.postPaths, ['/orders/order-1/cancel']);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('cancel-order-button')));
    expect(api.postPaths, ['/orders/order-1/cancel']);

    api.order['status'] = 'CANCELLED';
    api.cancelCompleter!.complete({});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byKey(const ValueKey('cancel-order-button')), findsNothing);
    expect(find.text('تم إلغاء الطلب'), findsOneWidget);
  });
}

Future<SharedPreferences> _preferences() async {
  SharedPreferences.setMockInitialValues({
    'session_user': jsonEncode({'id': 'client-1', 'role': 'CLIENT'}),
  });
  return SharedPreferences.getInstance();
}

Future<void> _pumpTracking(WidgetTester tester, _TrackingApiClient api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(api.preferences),
        apiClientProvider.overrideWithValue(api),
      ],
      child: const MaterialApp(home: TrackingScreen(orderId: 'order-1')),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

class _TrackingApiClient extends ApiClient {
  _TrackingApiClient(super.preferences);

  final postPaths = <String>[];
  Completer<Map<String, dynamic>>? cancelCompleter;
  final order = <String, dynamic>{
    'id': 'order-1',
    'reference': 'WS-1',
    'clientId': 'client-1',
    'captainId': null,
    'captain': null,
    'status': 'SEARCHING_CAPTAIN',
    'pickupLatitude': 30.0,
    'pickupLongitude': 31.0,
    'deliveryLatitude': 30.1,
    'deliveryLongitude': 31.1,
    'pickupLabel': 'نقطة الاستلام',
    'deliveryLabel': 'نقطة التسليم',
    'price': 45,
  };

  @override
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, dynamic>? query,
  }) async => Map<String, dynamic>.from(order);

  @override
  Future<Map<String, dynamic>> post(String path, {Object? data}) {
    postPaths.add(path);
    if (cancelCompleter != null) return cancelCompleter!.future;
    return Future.value(Map<String, dynamic>.from(order));
  }
}
