import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as jsu;

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = true;
  String _status = 'Initializing...';
  String? _errorMessage;

  // OAuth params from /oauth/authorize
  String? clientId, redirectUri, state, codeChallenge, codeChallengeMethod, scope;

  // Google Sign-In plugin (fallback)
  late final GoogleAuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = GoogleAuthService(
      AppConfig.googleWebClientId,
      AppConfig.googleScopes,
    );
    _parseUrlParameters();
  }

  void _parseUrlParameters() {
    setState(() => _status = 'Reading authorization request...');
    try {
      final uri = Uri.base;
      clientId = uri.queryParameters['client_id'];
      redirectUri = uri.queryParameters['redirect_uri'];
      state = uri.queryParameters['state'];
      codeChallenge = uri.queryParameters['code_challenge'];
      codeChallengeMethod = uri.queryParameters['code_challenge_method'] ?? 'S256';
      scope = uri.queryParameters['scope'] ?? AppConfig.defaultScope;

      if (clientId == null || redirectUri == null || state == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
          'Missing OAuth parameters. Please start from ChatGPT again.';
          _status = 'Invalid Request';
        });
        return;
      }
      Future.microtask(_startGoogleSignIn);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to parse authorization request: $e';
        _status = 'Error';
      });
    }
  }

  // --- GIS: Get ID token on Web ---
  Future<String?> _signInWithGIS() async {
    final g = js.context['google'];
    if (g == null) {
      debugPrint('google GSI script not loaded');
      return null;
    }
    final completer = Completer<String?>();

    void callback(dynamic response) {
      try {
        final cred = jsu.getProperty(response, 'credential') as String?;
        if (!completer.isCompleted) completer.complete(cred);
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      }
    }

    // initialize
    jsu.callMethod(
      jsu.getProperty(g, 'accounts')['id'],
      'initialize',
      [
        jsu.jsify({
          'client_id': AppConfig.googleWebClientId,
          'callback': js.allowInterop(callback),
          'ux_mode': 'popup',
          'auto_select': false,
        }),
      ],
    );

    // prompt a popup/One Tap; the callback carries ID token
    jsu.callMethod(jsu.getProperty(g, 'accounts')['id'], 'prompt', []);

    // timeout safeguard
    return completer.future
        .timeout(const Duration(seconds: 25), onTimeout: () => null);
  }

  Future<void> _startGoogleSignIn() async {
    if (!mounted) return;
    setState(() {
      _status = 'Connecting to Google...';
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1) Try GIS first (web-official path) → returns JWT ID token
      final gisIdToken = await _signInWithGIS();
      if (gisIdToken != null && gisIdToken.isNotEmpty) {
        await _sendTokenToBackend(gisIdToken, '(google user)');
        return;
      }

      // 2) Fallback: plugin (may not return idToken on web)
      final GoogleSignInAccount? user = await _authService.signIn();
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sign in was cancelled.';
          _status = 'Cancelled';
        });
        return;
      }
      final GoogleSignInAuthentication auth = await user.authentication;
      final String? pluginIdToken = auth.idToken;
      if (pluginIdToken == null || pluginIdToken.isEmpty) {
        throw Exception('Plugin did not return an ID token on web. Use GIS.');
      }
      await _sendTokenToBackend(pluginIdToken, user.email);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Google Sign In failed: $e';
        _status = 'Authentication Failed';
      });
    }
  }

  Future<void> _sendTokenToBackend(String googleToken, String email) async {
    if (!mounted) return;
    setState(() => _status = 'Exchanging credentials with backend...');
    try {
      final resp = await http.post(
        Uri.parse('${AppConfig.backendUrl}/oauth/callback'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'google_token': googleToken,
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'state': state,
          'code_challenge': codeChallenge,
          'code_challenge_method': codeChallengeMethod,
          'scope': scope,
        }),
      );

      if (resp.statusCode != 200) {
        throw Exception('Backend ${resp.statusCode}: ${resp.body}');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final redirectUrl = data['redirect_url'] as String;

      // Simple redirect (you can keep your fancy CallbackScreen if you like)
      html.window.location.href = redirectUrl;
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Backend error: $e';
        _status = 'Backend Error';
      });
    }
  }

  // ---- UI below (unchanged) ----
  @override
  Widget build(BuildContext context) { /* … same as your UI … */
    return Scaffold(
      body: Center(
        child: _isLoading
            ? Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_status),
        ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_status, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_errorMessage != null) Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _startGoogleSignIn,
            child: const Text('Try Again with Google'),
          ),
        ]),
      ),
    );
  }
}

// Small wrapper so the rest of your code doesn’t change
class GoogleAuthService {
  final GoogleSignIn _googleSignIn;
  GoogleAuthService(String webClientId, List<String> scopes)
      : _googleSignIn = GoogleSignIn(clientId: webClientId, scopes: scopes);
  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();
  Future<void> signOut() => _googleSignIn.disconnect();
}

class AppConfig {
  static const String backendUrl =
      'https://vittyonboard-production.up.railway.app';

  /// IMPORTANT → must match index.html meta
  static const String googleWebClientId =
      '130321581049-41mfh1t7mn9u6n725mibuq7288vacbgs.apps.googleusercontent.com';

  static const List<String> googleScopes = ['email', 'profile', 'openid'];
  static const String defaultScope = 'user docs.read docs.write tasks.manage';
}
