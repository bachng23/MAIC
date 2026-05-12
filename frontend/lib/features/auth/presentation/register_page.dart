import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _showPassword = false;
  bool _acceptTerms = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        elevation: 0,
        title: const Text('MediAgent', style: TextStyle(color: Color(0xFF004E9F), fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              const Text('Create Account', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Color(0xFF004E9F))),
              const SizedBox(height: 8),
              const Text(
                'Join MediAgent to manage medications and stay connected.',
                style: TextStyle(fontSize: 16, color: Color(0xFF4C616C)),
              ),
              const SizedBox(height: 20),
              _fieldLabel('Full Name'),
              TextField(controller: _name, decoration: _inputDecoration('John Doe')),
              const SizedBox(height: 12),
              _fieldLabel('Email Address'),
              TextField(controller: _email, decoration: _inputDecoration('name@example.com')),
              const SizedBox(height: 12),
              _fieldLabel('Phone'),
              TextField(controller: _phone, decoration: _inputDecoration('0912345678')),
              const SizedBox(height: 12),
              _fieldLabel('Password'),
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
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _acceptTerms,
                onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'I agree to Terms of Service and Privacy Policy.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF414753)),
                ),
              ),
              if (auth.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(auth.error!, style: const TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.w600)),
                ),
              FilledButton.icon(
                onPressed: !_acceptTerms || auth.isLoading
                    ? null
                    : () async {
                        final ok = await ref.read(authControllerProvider).register(
                              email: _email.text.trim(),
                              password: _password.text,
                              name: _name.text.trim(),
                              phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                            );
                        if (ok && context.mounted) context.go('/home');
                      },
                icon: const Icon(Icons.arrow_forward),
                label: Text(auth.isLoading ? 'Loading...' : 'Create Account'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(58),
                  backgroundColor: const Color(0xFF0066CC),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Already have an account? Log In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4C616C))),
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
