import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an external URL (hosted payment pages, support links).
///
/// Indirection so widget tests can capture the requested URL without touching
/// the url_launcher platform channel.
typedef UrlOpener = Future<bool> Function(Uri uri);

Future<bool> _launchExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

final urlOpenerProvider = Provider<UrlOpener>((ref) => _launchExternal);
