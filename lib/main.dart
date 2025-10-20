import 'dart:convert';
import 'dart:html' as html; // web only
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const OnboardingApp());

class OnboardingApp extends StatelessWidget {
  const OnboardingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vitty Onboarding',
      theme: ThemeData(useMaterial3: true),
      home: const OnboardingScreen(),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final nameCtrl = TextEditingController();
  String? sessionId;
  String status = '';

  // Compile-time injected backend base (ngrok): --dart-define=BACKEND_BASE=https://<ngrok>.ngrok-free.dev
  static const backendBase = String.fromEnvironment('BACKEND_BASE', defaultValue: '');

  @override
  void initState() {
    super.initState();
    final uri = Uri.base;
    sessionId = uri.queryParameters['session_id'];
    if (sessionId == null || sessionId!.isEmpty) {
      status = 'Missing session_id in URL';
    }
  }

  Future<void> submit() async {
    if (sessionId == null || sessionId!.isEmpty) {
      setState(() => status = 'Missing session_id in URL');
      return;
    }
    if (backendBase.isEmpty) {
      setState(() => status = 'App not configured (BACKEND_BASE missing).');
      return;
    }

    setState(() => status = 'Saving…');

    try {
      final resp = await http.post(
        Uri.parse('$backendBase/api/onboarding/complete'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'name': nameCtrl.text.trim(),
        }),
      );

      if (resp.statusCode == 200) {
        setState(() => status = 'All set ✅  — You can switch back to ChatGPT.');
      } else {
        setState(() => status = 'Server error: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      setState(() => status = 'Network error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Welcome 👋', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: submit,
                    child: const Text('Submit'),
                  ),
                ),
                const SizedBox(height: 12),
                if (status.isNotEmpty) Text(status, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
