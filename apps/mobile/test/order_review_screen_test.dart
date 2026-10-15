import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasalny_orders/core/api_client.dart';
import 'package:wasalny_orders/screens/order_review_screen.dart';

void main() {
  testWidgets('shows order and quote details without a payment method', (
    tester,
  ) async {
    final api = _ReviewApiClient(await _preferences());
    final harness = await _pumpReview(tester, api);
    addTearDown(harness.router.dispose);

    expect(find.text('مراجعة السعر'), findsOneWidget);
    expect(find.text('نقطة الاستلام'), findsOneWidget);
    expect(find.text('القاهرة'), findsOneWidget);
    expect(find.text('المطار'), findsOneWidget);
    expect(find.text('مشتريات'), findsOneWidget);
    expect(find.text('18.5 كم'), findsOneWidget);
    expect(find.text('42.50 EGP'), findsNWidgets(2));
    expect(find.text('عمولة المندوب'), findsNothing);
    expect(
      find.text('تُخصم من محفظة المندوب ولا تضاف إلى إجمالي العميل'),
      findsNothing,
    );
    expect(find.text('طريقة الدفع'), findsNothing);
  });

  testWidgets('edit returns to order form without creating an order', (
    tester,
  ) async {
    final api = _ReviewApiClient(await _preferences());
    final harness = await _pumpReview(tester, api);
    addTearDown(harness.router.dispose);

    await tester.tap(find.text('تعديل'));
    await tester.pumpAndSettle();

    expect(find.text('فتح المراجعة'), findsOneWidget);
    expect(api.paths, isEmpty);
  });

  testWidgets('confirmation creates exactly once and opens tracking', (
    tester,
  ) async {
    final api = _ReviewApiClient(await _preferences())
      ..createCompleter = Completer<Map<String, dynamic>>();
    final harness = await _pumpReview(tester, api);
    addTearDown(harness.router.dispose);

    await tester.tap(find.text('تأكيد وطلب مندوب'));
    await tester.pump();
    expect(api.paths, ['/orders']);

    final disabledButtons = find.byWidgetPredicate(
      (widget) => widget is ElevatedButton && widget.onPressed == null,
    );
    expect(disabledButtons, findsOneWidget);
    await tester.tap(disabledButtons);
    expect(api.paths, ['/orders']);

    api.createCompleter!.complete({'id': 'order-42'});
    await tester.pumpAndSettle();
    expect(find.text('تتبع الطلب order-42'), findsOneWidget);
    expect(api.paths, ['/orders']);
  });

  testWidgets('network failure shows Arabic error and stays on review', (
    tester,
  ) async {
    final api = _ReviewApiClient(await _preferences())
      ..error = DioException(
        requestOptions: RequestOptions(path: '/orders'),
        type: DioExceptionType.connectionError,
      );
    final harness = await _pumpReview(tester, api);
    addTearDown(harness.router.dispose);

    await tester.tap(find.text('تأكيد وطلب مندوب'));
    await tester.pumpAndSettle();

    expect(
      find.text('تعذر الاتصال بالخادم. تحقق من اتصالك وحاول مرة أخرى.'),
      findsOneWidget,
    );
    expect(find.text('تأكيد وطلب مندوب'), findsOneWidget);
    expect(find.text('مراجعة السعر'), findsOneWidget);
  });

  testWidgets('400 response displays the API validation message', (
    tester,
  ) async {
    final requestOptions = RequestOptions(path: '/orders');
    final api = _ReviewApiClient(await _preferences())
      ..error = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {
            'message': ['recipientPhone must be a valid phone number'],
          },
        ),
      );
    final harness = await _pumpReview(tester, api);
    addTearDown(harness.router.dispose);

    await tester.tap(find.text('تأكيد وطلب مندوب'));
    await tester.pumpAndSettle();

    expect(
      find.text('recipientPhone must be a valid phone number'),
      findsOneWidget,
    );
    expect(find.text('مراجعة السعر'), findsOneWidget);
  });

  testWidgets('401 response asks the client to sign in again', (tester) async {
    final requestOptions = RequestOptions(path: '/orders');
    final api = _ReviewApiClient(await _preferences())
      ..error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
    final harness = await _pumpReview(tester, api);
    addTearDown(harness.router.dispose);

    await tester.tap(find.text('تأكيد وطلب مندوب'));
    await tester.pumpAndSettle();

    expect(find.text('انتهت الجلسة، سجّل الدخول مرة أخرى'), findsOneWidget);
    expect(find.text('مراجعة السعر'), findsOneWidget);
  });
}

Future<SharedPreferences> _preferences() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Future<_Harness> _pumpReview(WidgetTester tester, _ReviewApiClient api) async {
  final router = GoRouter(
    initialLocation: '/new-order',
    routes: [
      GoRoute(
        path: '/new-order',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => context.push(
                '/order-review',
                extra: {'orderData': _orderData, 'quote': _quote},
              ),
              child: const Text('فتح المراجعة'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/order-review',
        builder: (context, state) => OrderReviewScreen(
          orderData: Map<String, dynamic>.from(
            (state.extra as Map)['orderData'] as Map,
          ),
          quote: Map<String, dynamic>.from(
            (state.extra as Map)['quote'] as Map,
          ),
        ),
      ),
      GoRoute(
        path: '/track/:id',
        builder: (context, state) =>
            Scaffold(body: Text('تتبع الطلب ${state.pathParameters['id']}')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('فتح المراجعة'));
  await tester.pumpAndSettle();
  return _Harness(router);
}

const _orderData = <String, dynamic>{
  'pickupLabel': 'القاهرة',
  'deliveryLabel': 'المطار',
  'category': 'PURCHASES',
  'pickupLatitude': 30.0,
  'pickupLongitude': 31.0,
  'deliveryLatitude': 30.1,
  'deliveryLongitude': 31.1,
  'description': 'مشتريات',
  'recipientName': 'عميل',
  'recipientPhone': '01000000000',
};

const _quote = <String, dynamic>{
  'currency': 'EGP',
  'distanceKm': 18.5,
  'price': 42.5,
  'commission': 4.25,
};

class _Harness {
  const _Harness(this.router);
  final GoRouter router;
}

class _ReviewApiClient extends ApiClient {
  _ReviewApiClient(super.preferences);

  final List<String> paths = [];
  Object? error;
  Completer<Map<String, dynamic>>? createCompleter;

  @override
  Future<Map<String, dynamic>> post(String path, {Object? data}) {
    paths.add(path);
    if (error != null) return Future<Map<String, dynamic>>.error(error!);
    if (createCompleter != null) return createCompleter!.future;
    return Future.value({'id': 'order-42'});
  }
}
