import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/api_client.dart';
import 'screens.dart';
import 'screens/captain_availability_screen.dart';
import 'screens/captain_start_screen.dart';
import 'screens/captain_trip_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/order_review_screen.dart';
import 'screens/register_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/splash_screen.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  var messagingReady = false;
  try {
    await Firebase.initializeApp();
    await FirebaseMessaging.instance.requestPermission();
    messagingReady = true;
  } catch (_) {
    messagingReady = false;
  }
  runApp(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(preferences),
        messagingReadyProvider.overrideWithValue(messagingReady),
      ],
      child: const WasalnyApp(),
    ),
  );
}

final messagingReadyProvider = Provider<bool>((ref) => false);

final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const HomeGate()),
      GoRoute(
        path: '/auth',
        builder: (context, state) => AuthScreen(
          register: state.uri.queryParameters['mode'] == 'register',
          role: state.uri.queryParameters['role'] ?? 'CLIENT',
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterScreen(
          initialRole: state.uri.queryParameters['role'] == 'CAPTAIN'
              ? AccountType.captain
              : AccountType.client,
        ),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/new-order',
        builder: (context, state) {
          final extra = state.extra;
          final category = extra is Map ? extra['category'] : null;
          return CreateOrderScreen(
            initialCategory: category is String ? category : null,
          );
        },
      ),
      GoRoute(
        path: '/order-review',
        builder: (context, state) {
          final extra = state.extra as Map;
          return OrderReviewScreen(
            orderData: Map<String, dynamic>.from(extra['orderData'] as Map),
            quote: Map<String, dynamic>.from(extra['quote'] as Map),
          );
        },
      ),
      GoRoute(
        path: '/captain-start',
        builder: (context, state) => const CaptainStartScreen(),
      ),
      GoRoute(
        path: '/captain-documents',
        builder: (context, state) => const CaptainDocumentsScreen(),
      ),
      GoRoute(
        path: '/captain/availability',
        builder: (context, state) => const CaptainAvailabilityScreen(),
      ),
      GoRoute(
        path: '/captain/trip/:id',
        builder: (context, state) =>
            CaptainTripScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/map-picker',
        builder: (context, state) => MapPickerScreen(
          title: state.uri.queryParameters['title'] ?? 'اختيار الموقع',
        ),
      ),
      GoRoute(
        path: '/track/:id',
        builder: (context, state) =>
            TrackingScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  ),
);

class WasalnyApp extends ConsumerWidget {
  const WasalnyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Wasalny Orders',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF19785F),
          surface: const Color(0xFFF7F8F5),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F8F5),
          foregroundColor: Color(0xFF22342B),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFFE6EBE6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFFE6EBE6)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}
