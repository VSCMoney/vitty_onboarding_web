import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'callbackscreen.dart'; // ← ADD THIS

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = true;
  String _status = 'Initializing...';
  String? _errorMessage;

  // OAuth parameters from URL
  String? clientId;
  String? redirectUri;
  String? state;
  String? codeChallenge;
  String? codeChallengeMethod;
  String? scope;

  // Google Auth Service
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

  /// Parse OAuth parameters from URL
  void _parseUrlParameters() {
    setState(() {
      _status = 'Reading authorization request...';
    });

    try {
      final uri = Uri.base;

      clientId = uri.queryParameters['client_id'];
      redirectUri = uri.queryParameters['redirect_uri'];
      state = uri.queryParameters['state'];
      codeChallenge = uri.queryParameters['code_challenge'];
      codeChallengeMethod = uri.queryParameters['code_challenge_method'] ?? 'S256';
      scope = uri.queryParameters['scope'] ?? AppConfig.defaultScope;

      debugPrint('📋 OAuth Parameters Received:');
      debugPrint('   Client ID: $clientId');
      debugPrint('   Redirect URI: $redirectUri');
      debugPrint('   State: $state');

      if (clientId == null || redirectUri == null || state == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Missing required OAuth parameters. Please initiate the flow from ChatGPT.';
          _status = 'Invalid Request';
        });
        return;
      }

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _startGoogleSignIn();
        }
      });

    } catch (e) {
      debugPrint('❌ Error parsing URL parameters: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to parse authorization request: $e';
        _status = 'Error';
      });
    }
  }

  /// Start Google Sign In flow
  Future<void> _startGoogleSignIn() async {
    if (!mounted) return;

    setState(() {
      _status = 'Opening Google Sign In...';
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🔐 Starting Google Sign In...');

      final GoogleSignInAccount? user = await _authService.signIn();

      if (user == null) {
        debugPrint('⚠️ Sign in cancelled');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sign in cancelled. Please try again.';
          _status = 'Cancelled';
        });
        return;
      }

      debugPrint('✅ Signed in: ${user.email}');

      if (!mounted) return;
      setState(() {
        _status = 'Getting authentication token...';
      });

      final GoogleSignInAuthentication auth = await user.authentication;

      // Check for ID token first, then fallback to access token
      String? token = auth.idToken;

      if (token == null || token.isEmpty) {
        debugPrint('⚠️ ID token is null, trying access token...');
        token = auth.accessToken;
      }

      if (token == null || token.isEmpty) {
        throw Exception('Failed to get any authentication token from Google');
      }

      debugPrint('✅ Got token: ${token.substring(0, 20)}...');

      await _sendTokenToBackend(token, user.email);

    } catch (e) {
      debugPrint('❌ Sign in error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sign in failed: ${e.toString()}';
        _status = 'Error';
      });
    }
  }

  /// Send Google token to backend for OAuth code exchange
  Future<void> _sendTokenToBackend(String googleToken, String email) async {
    if (!mounted) return;

    setState(() {
      _status = 'Exchanging credentials with backend...';
    });

    try {
      debugPrint('📤 Sending token to backend...');

      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/oauth/callback'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
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

      debugPrint('📥 Backend response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String redirectUrl = data['redirect_url'];

        debugPrint('✅ Authorization successful!');
        debugPrint('   Redirect URL: $redirectUrl');

        if (!mounted) return;

        // Navigate to callback screen instead of direct redirect
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CallbackScreen(
              redirectUrl: redirectUrl,
              userEmail: email,
            ),
          ),
        );

      } else {
        final errorBody = response.body;
        debugPrint('❌ Backend error response: $errorBody');
        throw Exception('Backend returned status ${response.statusCode}: $errorBody');
      }

    } on http.ClientException catch (e) {
      debugPrint('❌ Network error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network error. Please check your connection and try again.';
        _status = 'Connection Failed';
      });
    } catch (e) {
      debugPrint('❌ Backend communication error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to communicate with backend: ${e.toString()}';
        _status = 'Backend Error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 12,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 32),

                      const Text(
                        'Vitty Onboard',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF667EEA),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      const Text(
                        'Secure OAuth Authentication',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 48),

                      _buildStatusContent(),

                      const SizedBox(height: 32),

                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '🚀',
          style: TextStyle(fontSize: 56),
        ),
      ),
    );
  }

  Widget _buildStatusContent() {
    if (_isLoading) {
      return Column(
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _status,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Please wait while we authenticate you...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else if (_errorMessage != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  _status,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startGoogleSignIn,
              icon: Image.network(
                'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                height: 24,
                width: 24,
                errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 24),
              ),
              label: const Text(
                'Try Again with Google',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 18,
                ),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.security_rounded,
            size: 18,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _isLoading
                  ? 'Secure OAuth 2.0 + PKCE authentication'
                  : 'Protected by Google Sign-In',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}



/// Application configuration
class AppConfig {
  // Backend URL - Railway deployment
  static const String backendUrl =
      'https://fastapi-app-130321581049.asia-south1.run.app';

  // Google Web Client ID
  // ⚠️ IMPORTANT: Replace with your actual Web Client ID from Google Cloud Console
  static const String googleWebClientId =
      '130321581049-ktqt7omporh5is930jmjpmmbaq5m5noi.apps.googleusercontent.com';

  // OAuth scopes
  static const List<String> googleScopes = [
    'email',
    'profile',
    'openid',
  ];

  // Default permissions
  static const String defaultScope = 'user docs.read docs.write tasks.manage';
}





class GoogleAuthService {
  final GoogleSignIn _googleSignIn;

  GoogleAuthService(String webClientId, List<String> scopes)
      : _googleSignIn = GoogleSignIn(
    clientId: webClientId,
    scopes: [...scopes, 'https://www.googleapis.com/auth/userinfo.email'],
    // Force online mode for web
    forceCodeForRefreshToken: true,
  );

  Future<GoogleSignInAccount?> signIn() async {
    try {
      debugPrint('🔐 Starting Google Sign In...');

      // For web, we need to sign out first
      if (kIsWeb) {
        try {
          await _googleSignIn.signOut();
        } catch (e) {
          debugPrint('⚠️ Sign out error (ignored): $e');
        }
      }

      final account = await _googleSignIn.signIn();

      if (account == null) {
        debugPrint('⚠️ Sign in cancelled');
        return null;
      }

      debugPrint('✅ Signed in: ${account.email}');

      // Verify authentication
      try {
        final auth = await account.authentication;

        debugPrint('📋 Auth check:');
        debugPrint('   ID Token: ${auth.idToken != null ? "✓" : "✗"}');
        debugPrint('   Access Token: ${auth.accessToken != null ? "✓" : "✗"}');

        if (auth.idToken == null && auth.accessToken == null) {
          throw Exception('No tokens received from Google');
        }

        // For web, sometimes we get access token but not ID token
        // We can use access token to get user info
        if (auth.idToken == null && auth.accessToken != null) {
          debugPrint('⚠️ Using access token instead of ID token');
        }

      } catch (e) {
        debugPrint('❌ Authentication error: $e');
        rethrow;
      }

      return account;
    } catch (error) {
      debugPrint('❌ Sign in error: $error');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
      debugPrint('✅ Signed out');
    } catch (e) {
      debugPrint('⚠️ Sign out error: $e');
    }
  }
}