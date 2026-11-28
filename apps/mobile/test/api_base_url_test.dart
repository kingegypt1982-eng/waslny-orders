import 'package:flutter_test/flutter_test.dart';
import 'package:wasalny_orders/core/api_client.dart';

void main() {
  group('resolveApiBaseUrl', () {
    test('uses the Railway HTTPS endpoint by default in release', () {
      expect(
        resolveApiBaseUrl(configuredUrl: '', isRelease: true, isWeb: false),
        productionApiBaseUrl,
      );
    });

    test('allows an HTTPS dart-define override in release', () {
      expect(
        resolveApiBaseUrl(
          configuredUrl: 'https://api.example.com',
          isRelease: true,
          isWeb: false,
        ),
        'https://api.example.com/api/v1',
      );
    });

    test('rejects HTTP and loopback release overrides', () {
      for (final url in [
        'http://api.example.com/api/v1',
        'https://localhost/api/v1',
        'https://127.0.0.1/api/v1',
      ]) {
        expect(
          () => resolveApiBaseUrl(
            configuredUrl: url,
            isRelease: true,
            isWeb: false,
          ),
          throwsArgumentError,
        );
      }
    });

    test('keeps the web and Android emulator defaults in debug', () {
      expect(
        resolveApiBaseUrl(configuredUrl: '', isRelease: false, isWeb: true),
        'http://localhost:3000/api/v1',
      );
      expect(
        resolveApiBaseUrl(configuredUrl: '', isRelease: false, isWeb: false),
        'http://10.0.2.2:3000/api/v1',
      );
    });
  });
}
