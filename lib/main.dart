// import 'dart:convert';
// import 'dart:async';
// import 'dart:html' as html; // Web-only
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
//
// import 'auth_screen.dart';
//
// /// Simple Flutter web app to complete onboarding in an OAuth 2.1 flow.
// /// It expects a `tx` param in the URL: https://idp.example.com/onboard?tx=abc
// /// On "Complete", it POSTs { tx } to /oauth/tx/complete (same origin as IDP),
// /// reads { next_url }, and redirects the browser to finish the OAuth code flow.
//
// void main() {
//   runApp(const OnboardApp());
// }
//
// class OnboardApp extends StatelessWidget {
//   const OnboardApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Onboarding',
//       theme: ThemeData(
//         colorSchemeSeed: Colors.deepOrange,
//         useMaterial3: true,
//       ),
//       home: const AuthScreen(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }
//
// class OnboardPage extends StatefulWidget {
//   const OnboardPage({super.key});
//
//   @override
//   State<OnboardPage> createState() => _OnboardPageState();
// }
//
// class _OnboardPageState extends State<OnboardPage> {
//   final _formKey = GlobalKey<FormState>();
//   final _emailCtrl = TextEditingController();
//   final _passwordCtrl = TextEditingController();
//   bool _isLoading = false;
//   String? _error;
//
//   late final String? _tx;
//
//   @override
//   void initState() {
//     super.initState();
//     final params = Uri.base.queryParameters; // current URL
//     _tx = params['tx'];
//     if (_tx == null || _tx!.isEmpty) {
//       _error = 'Missing tx in URL. Opened without an authorization transaction.';
//     }
//   }
//
//   @override
//   void dispose() {
//     _emailCtrl.dispose();
//     _passwordCtrl.dispose();
//     super.dispose();
//   }
//
//   Future<void> _completeOnboarding() async {
//     if (_tx == null) return;
//     setState(() {
//       _error = null;
//       _isLoading = true;
//     });
//
//     try {
//       // TODO: (Optional) Call your own /login endpoint here to set session cookies.
//       // Since our demo IDP accepts POST /oauth/tx/complete without real auth,
//       // we directly complete the transaction.
//
//       final resp = await http.post(
//         Uri.parse('/oauth/tx/complete'), // same-origin call to the IDP
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'tx': _tx}),
//       );
//
//       if (resp.statusCode != 200) {
//         setState(() {
//           _error = 'Server error: ${resp.statusCode} ${resp.reasonPhrase}';
//           _isLoading = false;
//         });
//         return;
//       }
//
//       final data = jsonDecode(resp.body) as Map<String, dynamic>;
//       final nextUrl = data['next_url'] as String?;
//       if (nextUrl == null || nextUrl.isEmpty) {
//         setState(() {
//           _error = 'No next_url in response.';
//           _isLoading = false;
//         });
//         return;
//       }
//
//       // Redirect the browser to ChatGPT's redirect_uri with ?code=&state=
//       html.window.location.href = nextUrl;
//     } catch (e) {
//       setState(() {
//         _error = 'Network/parse error: $e';
//         _isLoading = false;
//       });
//     }
//   }
//
//   Widget _buildBody() {
//     if (_tx == null) {
//       return _ErrorPane(message: _error ?? 'Invalid entry point.');
//     }
//
//     return Center(
//       child: ConstrainedBox(
//         constraints: const BoxConstraints(maxWidth: 440),
//         child: Card(
//           elevation: 3,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           child: Padding(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Icon(Icons.local_pizza, size: 56),
//                 const SizedBox(height: 12),
//                 const Text(
//                   'Sign in to continue',
//                   style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
//                 ),
//                 const SizedBox(height: 4),
//                 const Text(
//                   'This step is part of a secure OAuth authorization.',
//                   textAlign: TextAlign.center,
//                 ),
//                 const SizedBox(height: 20),
//
//                 // Demo login form (optional; for real apps, call your /login)
//                 Form(
//                   key: _formKey,
//                   child: Column(
//                     children: [
//                       TextFormField(
//                         controller: _emailCtrl,
//                         decoration: const InputDecoration(
//                           labelText: 'Email',
//                           border: OutlineInputBorder(),
//                         ),
//                         keyboardType: TextInputType.emailAddress,
//                         validator: (v) {
//                           if (v == null || v.isEmpty) return 'Email is required';
//                           if (!v.contains('@')) return 'Invalid email';
//                           return null;
//                         },
//                       ),
//                       const SizedBox(height: 12),
//                       TextFormField(
//                         controller: _passwordCtrl,
//                         decoration: const InputDecoration(
//                           labelText: 'Password',
//                           border: OutlineInputBorder(),
//                         ),
//                         obscureText: true,
//                         validator: (v) {
//                           if (v == null || v.isEmpty) return 'Password is required';
//                           if (v.length < 4) return 'Too short';
//                           return null;
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 if (_error != null) ...[
//                   const SizedBox(height: 12),
//                   _ErrorBanner(message: _error!),
//                 ],
//
//                 const SizedBox(height: 16),
//                 SizedBox(
//                   width: double.infinity,
//                   child: FilledButton.icon(
//                     onPressed: _isLoading
//                         ? null
//                         : () {
//                       if (_formKey.currentState?.validate() ?? false) {
//                         // In real app, verify credentials via your login API,
//                         // then call _completeOnboarding().
//                         _completeOnboarding();
//                       }
//                     },
//                     icon: _isLoading
//                         ? const SizedBox(
//                         width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
//                         : const Icon(Icons.lock_open),
//                     label: Text(_isLoading ? 'Continuing…' : 'Continue'),
//                   ),
//                 ),
//
//                 const SizedBox(height: 10),
//                 TextButton(
//                   onPressed: _isLoading ? null : _completeOnboarding,
//                   child: const Text('Skip sign-in (demo)'),
//                 ),
//
//                 const SizedBox(height: 8),
//                 const Text(
//                   'By continuing you agree to authorize the app.',
//                   style: TextStyle(fontSize: 12, color: Colors.black54),
//                   textAlign: TextAlign.center,
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: _buildBody(),
//       backgroundColor: const Color(0xFFF8F7F5),
//     );
//   }
// }
//
// class _ErrorPane extends StatelessWidget {
//   final String message;
//   const _ErrorPane({required this.message});
//
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Text(message, style: const TextStyle(color: Colors.red)),
//     );
//   }
// }
//
// class _ErrorBanner extends StatelessWidget {
//   final String message;
//   const _ErrorBanner({required this.message});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.red.withOpacity(0.08),
//         border: Border.all(color: Colors.red.shade200),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.error_outline, color: Colors.red.shade700),
//           const SizedBox(width: 8),
//           Expanded(child: Text(message, style: TextStyle(color: Colors.red.shade700))),
//         ],
//       ),
//     );
//   }
// }





import 'package:flutter/material.dart';
import 'package:vitty_onboarding_web/question.dart';
import 'callbackscreen.dart';
import 'onboarding.dart';

import 'auth_screen.dart';


void main() {
  runApp(const VittyOnboardingApp());
}

class VittyOnboardingApp extends StatelessWidget {
  const VittyOnboardingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vitty Onboarding',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF667EEA),
        useMaterial3: true,
      ),
      home: const OnboardingFlow(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _currentStep = 0;
  String? _userEmail;
  String? _redirectUrl;

  // Steps:
  // 0: Onboarding screens (3 pages)
  // 1: Google Sign In
  // 2: Questions (3 questions)
  // 3: Callback redirect

  void _completeOnboarding() {
    setState(() {
      _currentStep = 1;
    });
  }

  void _completeAuth(String email, String redirectUrl) {
    setState(() {
      _userEmail = email;
      _redirectUrl = redirectUrl;
      _currentStep = 2;
    });
  }

  void _completeQuestions() {
    setState(() {
      _currentStep = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return OnboardingScreen(
          onComplete: _completeOnboarding,
        );
      case 1:
        return AuthScreen(
          onAuthComplete: _completeAuth,
        );
      case 2:
        return QuestionsScreen(
          userEmail: _userEmail ?? 'User',
          onComplete: _completeQuestions,
        );
      case 3:
        return CallbackScreen(
          redirectUrl: _redirectUrl ?? '',
          userEmail: _userEmail ?? 'User',
        );
      default:
        return OnboardingScreen(
          onComplete: _completeOnboarding,
        );
    }
  }
}