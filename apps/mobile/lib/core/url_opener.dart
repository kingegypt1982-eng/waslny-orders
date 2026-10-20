import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an external URL (hosted payment pages, support links).
///
/// Indirection so widget tests can capture the requested URL without touching
/// the url_launcher platform channel.
///
/// Returns `false` when the platform refused to open the URL. Note: on web this
/// always reports success once `window.open` is called — the browser cannot
/// tell us whether a pop-up blocker actually suppressed it, which is why the
/// wallet screen also offers a manual "open payment page" button.
typedef UrlOpener = Future<bool> Function(Uri uri);

/// [LaunchMode.externalApplication] opens the real browser (the in-app web view
/// cannot complete a hosted card payment), and [webOnlyWindowName] forces a new
/// tab on Flutter Web (`_blank`). On non-web platforms the name is ignored.
Future<bool> _launchExternal(Uri uri) => launchUrl(
  uri,
  mode: LaunchMode.externalApplication,
  webOnlyWindowName: '_blank',
);

final urlOpenerProvider = Provider<UrlOpener>((ref) => _launchExternal);
