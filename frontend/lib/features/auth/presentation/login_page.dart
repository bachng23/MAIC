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
    if (widget.isWelcome) {
      return _buildWelcomeScaffold(context);
    }
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
              const Text(
                'Welcome back',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Color(0xFF4C616C), fontWeight: FontWeight.w500),
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
                child: _buildLoginForm(context, auth),
              ),
              const SizedBox(height: 16),
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

  Widget _buildWelcomeScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    const Color(0xFFF2F4F7),
                    const Color(0xFFF7F9FC),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.health_and_safety_rounded, color: Color(0xFF004E9F), size: 32),
                        SizedBox(width: 10),
                        Text(
                          'MediAgent',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF004E9F)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Empathetic Guardian',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4C616C), letterSpacing: 0.3),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                        child: Column(
                          children: [
                            Container(
                              height: 220,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF0066CC).withValues(alpha: 0.12),
                                    const Color(0xFF004E9F).withValues(alpha: 0.22),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x14191C1E), blurRadius: 28, offset: Offset(0, 12)),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: 20,
                                    top: 24,
                                    child: Icon(Icons.medication_liquid_rounded, size: 72, color: Colors.white.withValues(alpha: 0.35)),
                                  ),
                                  Positioned(
                                    left: 18,
                                    bottom: 18,
                                    right: 18,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.92),
                                        borderRadius: BorderRadius.circular(18),
                                        border: const Border(left: BorderSide(color: Color(0xFF0066CC), width: 4)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.verified_user_rounded, color: Color(0xFF0066CC), size: 28),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Guided care for every dose — reminders, scans, and safety checks in one place.',
                                              style: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600, color: Color(0xFF414753)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'Stay safe with every dose',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.15, color: Color(0xFF004E9F)),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Track medications, monitor vitals, and keep loved ones in the loop — with privacy built in.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Color(0xFF4C616C), height: 1.45),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: () => context.go('/login'),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              backgroundColor: const Color(0xFF0066CC),
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: () => context.go('/register'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              side: const BorderSide(color: Color(0xFF0066CC)),
                              foregroundColor: const Color(0xFF0066CC),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('I already have an account', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Privacy first: your health data stays encrypted and under your control.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xFF6B7C86), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
