import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class PhoneEntryPage extends StatefulWidget {
  const PhoneEntryPage({super.key});

  @override
  State<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends State<PhoneEntryPage> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xE6F7F9FC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF004E9F)),
          onPressed: () => context.pop(),
        ),
        title: const Text('Verification', style: TextStyle(color: Color(0xFF004E9F), fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: Color(0xFF414753)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0066CC).withValues(alpha: 0.08),
                  const Color(0xFF0066CC).withValues(alpha: 0.18),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: const Border(left: BorderSide(color: Color(0xFF0066CC), width: 4)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield, color: Color(0xFF0066CC), size: 28),
                        SizedBox(height: 6),
                        Text(
                          'Patient Safety First',
                          style: TextStyle(color: Color(0xFF414753), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Secure your account',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, height: 1.1),
          ),
          const SizedBox(height: 8),
          const Text(
            'We\'ll send a verification code to your mobile number.',
            style: TextStyle(fontSize: 17, color: Color(0xFF4C616C), height: 1.35),
          ),
          const SizedBox(height: 24),
          const Text(
            'MOBILE NUMBER',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: Color(0xFF4C616C)),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Text('🇹🇼', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 6),
                    Text('+886', style: TextStyle(fontWeight: FontWeight.w800)),
                    Icon(Icons.expand_more, size: 18),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))],
                  decoration: InputDecoration(
                    hintText: '09xx xxx xxx',
                    filled: true,
                    fillColor: const Color(0xFFF2F4F7),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF0066CC), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0x33CFE6F2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, color: Color(0xFF0066CC)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your privacy is our priority. We only use this to secure your health data.',
                    style: TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF526772)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              final raw = _phone.text.trim();
              if (raw.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a phone number.')));
                return;
              }
              context.go('/verify-phone?phone=${Uri.encodeComponent(raw)}');
            },
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Send Code'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: const Color(0xFF0066CC),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support: coming soon.')));
              },
              child: const Text('Contact Support', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 32, height: 5, decoration: BoxDecoration(color: const Color(0xFF0066CC), borderRadius: BorderRadius.circular(999))),
              const SizedBox(width: 6),
              Container(width: 8, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0E3E6), borderRadius: BorderRadius.circular(999))),
              const SizedBox(width: 6),
              Container(width: 8, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0E3E6), borderRadius: BorderRadius.circular(999))),
            ],
          ),
        ],
      ),
    );
  }
}
