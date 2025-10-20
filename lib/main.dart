import 'dart:convert';
import 'dart:html' as html show window;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Backend base (FastAPI/ngrok).  GH Pages build में हम --dart-define से देंगे.
const String backendBase =
String.fromEnvironment('BACKEND_BASE', defaultValue: '');

String? _query(String key) {
  final uri = Uri.parse(html.window.location.href);
  return uri.queryParameters[key];
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OnboardingApp());
}

class OnboardingApp extends StatelessWidget {
  const OnboardingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OnboardingScreen(),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  bool _submitting = false;
  String? _msg;

  Future<void> _submit() async {
    final state = _query('session_id') ?? _query('state');
    if (state == null || state.isEmpty) {
      setState(() => _msg = 'Missing session_id in URL');
      return;
    }
    if (backendBase.isEmpty) {
      setState(() => _msg = 'BACKEND_BASE not configured.');
      return;
    }

    setState(() {
      _submitting = true;
      _msg = null;
    });

    try {
      final resp = await http.post(
        Uri.parse('$backendBase/api/onboarding/complete'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'state': state, 'name': _name.text.trim()}),
      );
      if (resp.statusCode == 200) {
        setState(() => _msg = 'Onboarding complete. Switch back to ChatGPT and type: done');
      } else {
        setState(() => _msg = 'Server error: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      setState(() => _msg = 'Network error: $e');
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _query('session_id') ?? _query('state') ?? '-';
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            elevation: 6,
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Vitty Onboarding', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Session: $state', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),

                // (optional) "Login with Google" button placeholder for later
                // ElevatedButton.icon(
                //   onPressed: _startGoogleLogin, icon: const Icon(Icons.login), label: const Text('Login with Google'),
                // ),

                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Submit'),
                  ),
                ),
                const SizedBox(height: 8),
                if (_msg != null) Text(_msg!, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('After submit, go back to ChatGPT and type "done".',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
