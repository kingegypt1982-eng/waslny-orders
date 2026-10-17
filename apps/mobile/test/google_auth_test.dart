import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasalny_orders/core/api_client.dart';
import 'package:wasalny_orders/core/google_auth.dart';
import 'package:wasalny_orders/screens.dart';

void main() {
  group('googleAuthErrorMessage', () {
    final options = RequestOptions(path: '/auth/google');

    test('localizes a cancelled attempt', () {
      expect(
        googleAuthErrorMessage(const GoogleAuthCancelled(), isArabic: false),
        contains('cancelled'),
      );
      expect(
        googleAuthErrorMessage(const GoogleAuthCancelled(), isArabic: true),
        contains('إلغاء'),
      );
    });

    test('maps "Invalid Google credential" to a verified-email hint', () {
      final error = DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 401,
          data: {'message': 'Invalid Google credential'},
        ),
      );
      expect(
        googleAuthErrorMessage(error, isArabic: false),
        contains('verify'),
      );
      expect(
        googleAuthErrorMessage(error, isArabic: true),
        contains('توثيق'),
      );
    });

    test('maps account mismatch and missing configuration', () {
      final mismatch = DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 409,
          data: {
            'code': 'GOOGLE_ACCOUNT_MISMATCH',
            'message': 'This email is already linked to another Google account',
          },
        ),
      );
      expect(
        googleAuthErrorMessage(mismatch, isArabic: true),
        contains('حساب Google آخر'),
      );

      final notConfigured = DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 500,
          data: {
            'message':
                'Google sign-in is not configured (GOOGLE_CLIENT_ID is empty)',
          },
        ),
      );
      expect(
        googleAuthErrorMessage(notConfigured, isArabic: false),
        contains('not configured'),
      );
    });

    test('maps connectivity failures', () {
      final offline = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
      expect(
        googleAuthErrorMessage(offline, isArabic: false),
        contains('No internet connection'),
      );
      expect(
        googleAuthErrorMessage(offline, isArabic: true),
        contains('لا يوجد اتصال'),
      );
    });

    test('maps the not-configured platform exception', () {
      expect(
        googleAuthErrorMessage(
          const GoogleAuthException(GoogleAuthErrorKind.notConfigured),
          isArabic: true,
        ),
        contains('غير مُهيّأ'),
      );
    });
  });

  group('GoogleSignInButton (native path)', () {
    tearDown(() {
      GoogleSignInPlatform.instance = MethodChannelGoogleSignIn();
    });

    testWidgets('forwards the ID token returned by the platform', (
      tester,
    ) async {
      GoogleSignInPlatform.instance = _FakeGoogleSignInPlatform(
        data: GoogleSignInUserData(
          email: 'rider@example.com',
          id: '123',
          idToken: 'fake-id-token',
        ),
      );

      String? received;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              label: 'Continue with Google',
              onIdToken: (token) async => received = token,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(received, 'fake-id-token');
    });

    testWidgets('reports cancellation when the picker returns no account', (
      tester,
    ) async {
      GoogleSignInPlatform.instance = _FakeGoogleSignInPlatform(data: null);

      var cancelled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              label: 'Continue with Google',
              onIdToken: (_) async {},
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
    });

    testWidgets('reports platform failures through onError', (tester) async {
      GoogleSignInPlatform.instance = _FakeGoogleSignInPlatform(
        error: StateError('no google-services.json'),
      );

      Object? reported;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              label: 'Continue with Google',
              onIdToken: (_) async {},
              onError: (error) => reported = error,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(reported, isA<GoogleAuthException>());
    });
  });

  testWidgets('AuthScreen exchanges the Google token via /auth/google', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    GoogleSignInPlatform.instance = _FakeGoogleSignInPlatform(
      data: GoogleSignInUserData(
        email: 'rider@example.com',
        id: '123',
        idToken: 'google-id-token',
      ),
    );
    addTearDown(
      () => GoogleSignInPlatform.instance = MethodChannelGoogleSignIn(),
    );

    final api = _RecordingApiClient(
      preferences,
      response: {
        'accessToken': 'api-jwt',
        'user': {
          'id': 'u1',
          'email': 'rider@example.com',
          'name': 'Rider',
          'role': 'CLIENT',
        },
      },
    );
    final router = GoRouter(
      initialLocation: '/auth',
      routes: [
        GoRoute(
          path: '/auth',
          builder: (context, state) =>
              const AuthScreen(register: false, role: 'CLIENT'),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Text('home screen')),
        ),
        GoRoute(
          path: '/captain-documents',
          builder: (context, state) =>
              const Scaffold(body: Text('documents screen')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(preferences),
          apiClientProvider.overrideWithValue(api),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(api.requestPath, '/auth/google');
    expect(api.requestBody, containsPair('idToken', 'google-id-token'));
    expect(api.requestBody, containsPair('role', 'CLIENT'));
    expect(find.text('home screen'), findsOneWidget);
  });
}

class _FakeGoogleSignInPlatform extends GoogleSignInPlatform {
  _FakeGoogleSignInPlatform({this.data, this.error});

  final GoogleSignInUserData? data;
  final Object? error;

  @override
  Future<void> init({
    List<String> scopes = const <String>[],
    SignInOption signInOption = SignInOption.standard,
    String? hostedDomain,
    String? clientId,
  }) async {}

  @override
  Future<GoogleSignInUserData?> signIn() async {
    if (error != null) throw error!;
    return data;
  }

  @override
  Future<GoogleSignInTokenData> getTokens({
    required String email,
    bool? shouldRecoverAuth,
  }) async {
    return GoogleSignInTokenData(idToken: data?.idToken);
  }
}

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient(super.preferences, {required Map<String, dynamic> response})
    : _response = Map<String, dynamic>.from(response);

  final Map<String, dynamic> _response;
  String? requestPath;
  Map<String, dynamic>? requestBody;

  @override
  Future<Map<String, dynamic>> post(String path, {Object? data}) async {
    requestPath = path;
    requestBody = Map<String, dynamic>.from(data! as Map);
    return Map<String, dynamic>.from(_response);
  }
}
