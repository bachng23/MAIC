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
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 28),
            children: [
              const Icon(Icons.health_and_safety_rounded, size: 52, color: Color(0xFF0066CC)),
              const SizedBox(height: 10),
              const Text(
                'MediAgent',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF004E9F)),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isWelcome ? 'Stay safe with every dose' : 'Welcome back',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Color(0xFF4C616C), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0F191C1E), blurRadius: 24, offset: Offset(0, 8)),
                  ],
                ),
                padding: const EdgeInsets.all(22),
                child: widget.isWelcome ? _buildWelcomeActions(context) : _buildLoginForm(context, auth),
              ),
              const SizedBox(height: 16),
              if (!widget.isWelcome)
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Column(
                    children: [
                      Text('Don\'t have an account?', style: TextStyle(color: Color(0xFF4C616C))),
                      Text('Create Account', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF004E9F))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Welcome', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => context.go('/login'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: const Color(0xFF0066CC),
            foregroundColor: Colors.white,
          ),
          child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => context.go('/register'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildLoginForm(BuildContext context, dynamic auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Log In', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        const Text('Email Address', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4C616C))),
        const SizedBox(height: 6),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDecoration('name@example.com'),
        ),
        const SizedBox(height: 14),
        const Text('Password', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4C616C))),
        const SizedBox(height: 6),
        TextField(
          controller: _password,
          obscureText: !_showPassword,
          decoration: _inputDecoration('••••••••').copyWith(
            suffixIcon: IconButton(
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () {}, child: const Text('Forgot Password?')),
        ),
        if (auth.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(auth.error!, style: const TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.w600)),
          ),
        FilledButton(
          onPressed: auth.isLoading
              ? null
              : () async {
                  final ok = await ref.read(authControllerProvider).login(_email.text.trim(), _password.text);
                  if (ok && context.mounted) context.go('/home');
                },
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            backgroundColor: const Color(0xFF0066CC),
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
          child: Text(auth.isLoading ? 'Loading...' : 'Log In', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF2F4F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF0066CC), width: 2),
      ),
    );
  }
}
