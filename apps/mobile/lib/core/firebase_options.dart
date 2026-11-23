// Firebase configuration options for Waslny orders app.
// These values are provided via --dart-define during build:
//   flutter run --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_AUTH_DOMAIN=...
//               --dart-define=FIREBASE_DATABASE_URL=... --dart-define=FIREBASE_PROJECT_ID=...
//               --dart-define=FIREBASE_STORAGE_BUCKET=... --dart-define=FIREBASE_MESSAGING_SENDER_ID=...
//               --dart-define=FIREBASE_APP_ID=...
import 'dart:developer' show log;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase configuration class that supports initialization via dart-define.
class FirebaseOptionsBuilder {
  static FirebaseOptions build() {
    final apiKey = const String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
    final authDomain = const String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: '');
    final databaseUrl = const String.fromEnvironment('FIREBASE_DATABASE_URL', defaultValue: '');
    final projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
    final storageBucket = const String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');
    final messagingSenderId = const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
    final appId = const String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');

    final hasAnyConfig = apiKey.isNotEmpty ||
        authDomain.isNotEmpty ||
        databaseUrl.isNotEmpty ||
        projectId.isNotEmpty;

    if (!hasAnyConfig) {
      log('Warning: Firebase config not provided via dart-define. Firebase initialization may fail.');
    }

    return FirebaseOptions(
      apiKey: apiKey,
      authDomain: authDomain,
      databaseURL: databaseUrl,
      projectId: projectId,
      storageBucket: storageBucket,
      messagingSenderId: messagingSenderId,
      appId: appId,
    );
  }
}

/// Creates FirebaseOptions from the default Waslny project configuration.
/// Use this as a fallback when dart-define is not used.
FirebaseOptions get defaultFirebaseOptions => FirebaseOptions(
      apiKey: const String.fromEnvironment('FIREBASE_API_KEY',
          defaultValue: 'AIzaSyC-CuSCiHGrls_Ho3bhLpml4X9BHwPPCk'),
      authDomain: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN',
          defaultValue: 'waslny-c6ffb.firebaseapp.com'),
      databaseURL: const String.fromEnvironment('FIREBASE_DATABASE_URL',
          defaultValue:
              'https://waslny-c6ffb-default-rtdb.europe-west1.firebasedatabase.app'),
      projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID',
          defaultValue: 'waslny-c6ffb'),
      storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET',
          defaultValue: 'waslny-c6ffb.firebasestorage.app'),
      messagingSenderId: const String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
          defaultValue: '999658624457'),
      appId: const String.fromEnvironment('FIREBASE_APP_ID',
          defaultValue: '1:999658624457:web:d16b77d780cd82521bc418'),
    );