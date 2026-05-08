import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.isWelcome = false});
  final bool isWelcome;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final maxWidth = MediaQuery.sizeOf(context).width > 700 ? 540.0 : 430.0;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 40),
              Text('MediAgent', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(widget.isWelcome ? 'Stay safe with every dose' : 'Welcome back'),
              const SizedBox(height: 32),
              if (widget.isWelcome)
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Get Started'),
                ),
              if (widget.isWelcome) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Create Account'),
                ),
              ] else ...[
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          final ok = await ref
                              .read(authControllerProvider)
                              .login(_email.text.trim(), _password.text);
                          if (ok && context.mounted) context.go('/home');
                        },
                  child: Text(auth.isLoading ? 'Loading...' : 'Log In'),
                ),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Don’t have an account? Create Account'),
                ),
                if (auth.error != null) Text(auth.error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
