import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'google_auth_types.dart';

/// Web OAuth client ID resolved at runtime.
///
/// A compile-time `--dart-define=GOOGLE_CLIENT_ID=...` (or the legacy
/// `GOOGLE_WEB_CLIENT_ID`) wins, so existing deployments keep working. When it
/// is absent — the common case for `flutter run` — the value is fetched from
/// the public `GET /auth/google/config` endpoint, which returns the same client
/// ID the API verifies as the token audience. A web OAuth client ID is not a
/// secret: it is visible in every browser request.
///
/// Native builds keep their own client configuration (google-services.json /
/// GoogleService-Info.plist), so no network call is made there.
final googleClientIdProvider = FutureProvider<String?>((ref) async {
  if (!kIsWeb) return null;
  if (!isUnusableGoogleClientId(googleWebClientId)) return googleWebClientId;
  try {
    final config = await ref.read(apiClientProvider).getMap('/auth/google/config');
    final clientId = config['clientId'];
    return clientId is String && !isUnusableGoogleClientId(clientId)
        ? clientId
        : null;
  } catch (_) {
    // The button stays visible and reports "not configured" when tapped.
    return null;
  }
});
