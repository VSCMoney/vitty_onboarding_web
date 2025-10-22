import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:async';

class AuthService {
  String backendUrl = 'https://vittyonboard-production.up.railway.app';
  String googleClientId = '130321581049-ktqt7omporh5is930jmjpmmbaq5m5noi.apps.googleusercontent.com';

  bool _isInitialized = false;

  Future<void> _ensureGoogleApiLoaded() async {
    if (_isInitialized) return;

    // Check if Google API is loaded
    if (js.context.hasProperty('google')) {
      _isInitialized = true;
      return;
    }

    // Wait for Google API to load
    await Future.delayed(Duration(seconds: 2));

    if (js.context.hasProperty('google')) {
      _isInitialized = true;
      print('✅ Google API loaded');
    } else {
      throw Exception('Google Sign-In API not loaded');
    }
  }

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      await _ensureGoogleApiLoaded();

      print('🔄 Starting Google Sign-In...');

      final idToken = await _promptGoogleSignIn();

      if (idToken == null) {
        print('❌ Failed to get ID token');
        return null;
      }

      print('🎫 Got Google ID token');
      print('📤 Sending to backend...');

      final response = await http.post(
        Uri.parse('$backendUrl/auth/google'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'id_token': idToken}),
      );

      print('📥 Backend response: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Backend authentication successful');
        return jsonDecode(response.body);
      } else {
        print('❌ Backend error: ${response.body}');
        throw Exception('Backend authentication failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error during sign in: $e');
      rethrow;
    }
  }

  Future<String?> _promptGoogleSignIn() async {
    final completer = Completer<String?>();

    try {
      // Create callback function
      js.context['handleGoogleSignIn'] = (response) {
        final credential = response['credential'];
        if (credential != null) {
          print('✅ Got credential from Google');
          completer.complete(credential.toString());
        } else {
          print('❌ No credential in response');
          completer.complete(null);
        }
      };

      // Initialize Google Sign-In
      final google = js.context['google'];
      final accounts = google['accounts'];
      final id = accounts['id'];

      // Initialize with callback
      id.callMethod('initialize', [
        js.JsObject.jsify({
          'client_id': googleClientId,
          'callback': js.allowInterop((response) {
            js.context.callMethod('handleGoogleSignIn', [response]);
          }),
        })
      ]);

      print('📱 Prompting Google Sign-In...');

      // Prompt for sign-in
      id.callMethod('prompt', [
        js.allowInterop((notification) {
          // Check if prompt was displayed
          final isNotDisplayed = notification.callMethod('isNotDisplayed', []);
          final isSkippedMoment = notification.callMethod('isSkippedMoment', []);

          if (isNotDisplayed == true || isSkippedMoment == true) {
            print('⚠️ One Tap not displayed, showing button...');
            _showSignInButton();
          }
        })
      ]);

      // Timeout after 60 seconds
      return completer.future.timeout(
        Duration(seconds: 60),
        onTimeout: () {
          print('⏱️ Sign-in timed out');
          return null;
        },
      );
    } catch (e) {
      print('❌ Error in _promptGoogleSignIn: $e');
      return null;
    }
  }

  void _showSignInButton() {
    try {
      // Remove existing button if any
      final existingButton = html.document.getElementById('google-signin-button-container');
      existingButton?.remove();

      // Create container for button
      final buttonContainer = html.DivElement()
        ..id = 'google-signin-button-container'
        ..style.cssText = '''
          position: fixed;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          z-index: 99999;
          background: white;
          padding: 40px;
          border-radius: 16px;
          box-shadow: 0 10px 40px rgba(0,0,0,0.3);
        ''';

      // Add close button
      final closeButton = html.ButtonElement()
        ..text = '✕'
        ..style.cssText = '''
          position: absolute;
          top: 10px;
          right: 10px;
          background: none;
          border: none;
          font-size: 24px;
          cursor: pointer;
          color: #666;
        '''
        ..onClick.listen((_) {
          buttonContainer.remove();
        });

      buttonContainer.append(closeButton);

      // Add title
      final title = html.HeadingElement.h3()
        ..text = 'Sign in to continue'
        ..style.cssText = '''
          margin: 0 0 20px 0;
          text-align: center;
          color: #333;
        ''';

      buttonContainer.append(title);

      // Create div for Google button
      final buttonDiv = html.DivElement()
        ..id = 'google-signin-button';

      buttonContainer.append(buttonDiv);

      // Add overlay
      final overlay = html.DivElement()
        ..style.cssText = '''
          position: fixed;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          background: rgba(0,0,0,0.5);
          z-index: 99998;
        '''
        ..onClick.listen((_) {
          buttonContainer.remove();
          ///overlay.remove();
        });

      html.document.body!.append(overlay);
      html.document.body!.append(buttonContainer);

      // Render Google button
      final google = js.context['google'];
      final accounts = google['accounts'];
      final id = accounts['id'];

      id.callMethod('renderButton', [
        html.document.getElementById('google-signin-button'),
        js.JsObject.jsify({
          'theme': 'filled_blue',
          'size': 'large',
          'text': 'signin_with',
          'width': 300,
        })
      ]);

      print('✅ Sign-in button rendered');
    } catch (e) {
      print('❌ Error showing button: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _ensureGoogleApiLoaded();

      final google = js.context['google'];
      final accounts = google['accounts'];
      final id = accounts['id'];

      id.callMethod('disableAutoSelect', []);

      // Clean up
      js.context.deleteProperty('handleGoogleSignIn');

      print('👋 User signed out');
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  Map<String, dynamic> parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid JWT token');
    }

    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));

    return jsonDecode(decoded);
  }
}