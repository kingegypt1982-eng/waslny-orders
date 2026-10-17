import 'dart:async';

import 'package:flutter/material.dart';
// The web plugin implements google_sign_in's platform interface. It is already
// resolved transitively by google_sign_in_web; we use its types directly here
// without adding a second explicit dependency.
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

import 'google_auth_types.dart';

/// On the web, `GoogleSignIn.signIn()` performs an OAuth2 *authorization* flow
/// that does not reliably return an ID token (it may synthesize user data from
/// the People API with a null `idToken`). Callers must use the official
/// [GoogleSignInButton] instead, so this entry point is unsupported.
Future<String> requestGoogleIdToken() async {
  throw const GoogleAuthException(
    GoogleAuthErrorKind.unknown,
    'Use GoogleSignInButton on web: signIn() cannot return an idToken.',
  );
}

/// The official Google Identity Services button for Flutter Web.
///
/// Renders `id.renderButton` (limited customization) and listens to the GIS
/// credential stream to extract the ID token, then reports it through
/// [onIdToken] — mirroring the native flow so the caller's POST /auth/google,
/// session save, and routing stay identical across platforms.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.label,
    required this.onIdToken,
    this.onCancel,
    this.onError,
    this.busy = false,
    this.text = GoogleButtonText.continueWith,
    this.theme = GoogleButtonTheme.outline,
    this.locale,
    this.height = 46,
  });

  /// Native caption; the web button uses the GIS-provided text instead.
  final String label;

  /// Called with the Google ID token; runs POST /auth/google in the caller.
  final Future<void> Function(String idToken) onIdToken;

  /// Called when the user dismisses the account picker (unused on web).
  final VoidCallback? onCancel;

  /// Called when the GIS client cannot initialize or emits an error.
  final void Function(Object error)? onError;

  /// Unused on web (the GIS button manages its own enabled state).
  final bool busy;

  /// Wording for the official button (e.g. "Sign up with Google").
  final GoogleButtonText text;

  /// Theme for the official button.
  final GoogleButtonTheme theme;

  /// Locale for the official button text (e.g. 'ar').
  final String? locale;

  /// Button height in logical pixels.
  final double height;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  StreamSubscription<GoogleSignInUserData?>? _subscription;
  bool _ready = false;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (googleWebClientId.isEmpty) {
      // Report after the first frame: onError callbacks may surface a
      // SnackBar, which must not run during this widget's build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onError?.call(
            const GoogleAuthException(GoogleAuthErrorKind.notConfigured),
          );
        }
      });
      return;
    }
    try {
      // Equivalent to the <meta name="google-signin-client_id"> tag; passing
      // clientId here also satisfies the plugin's init assertion.
      await GoogleSignInPlatform.instance.initWithParams(
        SignInInitParameters(
          clientId: googleWebClientId,
          scopes: const <String>[],
        ),
      );
      _subscription = GoogleSignInPlatform.instance.userDataEvents?.listen(
        _onUserData,
        onError: (Object error) => widget.onError?.call(
          GoogleAuthException(GoogleAuthErrorKind.unknown, error),
        ),
      );
      if (mounted) setState(() => _ready = true);
    } catch (error, stack) {
      debugPrint('[google_auth] web init failed: ${error.runtimeType}: $error');
      debugPrint('[google_auth] stack: $stack');
      widget.onError?.call(
        GoogleAuthException(GoogleAuthErrorKind.notConfigured, error),
      );
    }
  }

  Future<void> _onUserData(GoogleSignInUserData? data) async {
    final idToken = data?.idToken;
    if (idToken == null || idToken.isEmpty || _running) return;
    _running = true;
    try {
      await widget.onIdToken(idToken);
    } finally {
      _running = false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return SizedBox(width: double.infinity, height: widget.height);
    }
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: gsi_web.renderButton(
        configuration: gsi_web.GSIButtonConfiguration(
          type: gsi_web.GSIButtonType.standard,
          theme: _theme(),
          size: gsi_web.GSIButtonSize.large,
          shape: gsi_web.GSIButtonShape.pill,
          text: _text(),
          logoAlignment: gsi_web.GSIButtonLogoAlignment.center,
          locale: widget.locale,
        ),
      ),
    );
  }

  gsi_web.GSIButtonTheme _theme() => switch (widget.theme) {
    GoogleButtonTheme.outline => gsi_web.GSIButtonTheme.outline,
    GoogleButtonTheme.filledBlue => gsi_web.GSIButtonTheme.filledBlue,
    GoogleButtonTheme.filledBlack => gsi_web.GSIButtonTheme.filledBlack,
  };

  gsi_web.GSIButtonText _text() => switch (widget.text) {
    GoogleButtonText.signIn => gsi_web.GSIButtonText.signinWith,
    GoogleButtonText.signUp => gsi_web.GSIButtonText.signupWith,
    GoogleButtonText.continueWith => gsi_web.GSIButtonText.continueWith,
  };
}
