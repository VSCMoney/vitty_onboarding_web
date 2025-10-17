import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const backendBase = String.fromEnvironment(
    'BACKEND_BASE', defaultValue: 'https://<your-backend-host>'
);

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: 'Onboarding', home: const OnboardingPage());
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  String? sessionId;
  String status = 'loading';
  String? userName;
  String? userId;

  @override
  void initState() {
    super.initState();
    final p = Uri.base.queryParameters;
    sessionId = p['session_id'];
    _load();
  }

  Future<void> _load() async {
    if (sessionId == null) { setState(() => status = 'missing_session'); return; }
    final r = await http.get(
      Uri.parse('$backendBase/api/session?state=$sessionId'),
      headers: {'Accept':'application/json'},
    );
    if (r.statusCode == 200) {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      setState(() {
        status = j['status']?.toString() ?? 'unknown';
        final prof = (j['profile'] as Map?) ?? {};
        userName = prof['name']?.toString();
        userId = prof['id']?.toString();
      });
    } else {
      setState(() => status = 'error_${r.statusCode}');
    }
  }

  Future<void> _finish() async {
    if (sessionId == null) return;
    final r = await http.post(
      Uri.parse('$backendBase/api/onboarding/complete'),
      headers: {'Content-Type':'application/json'},
      body: jsonEncode({'state': sessionId}),
    );
    if (r.statusCode == 200) setState(() => status = 'approved');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vitty Onboarding')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SelectableText('Session: ${sessionId ?? '-'}'),
        const SizedBox(height: 8),
        Text('Status: $status'),
        if (userName != null || userId != null)
          Text('Hello ${userName ?? ''} (${userId ?? ''})'),
        const SizedBox(height: 16),
        FilledButton(onPressed: _finish, child: const Text('Finish onboarding')),
        const Divider(height: 32),
        const Text('Return to ChatGPT and type: done'),
      ]),
    ),
  );
}
