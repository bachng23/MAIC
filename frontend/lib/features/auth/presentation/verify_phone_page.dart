import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class VerifyPhonePage extends StatefulWidget {
  const VerifyPhonePage({super.key, required this.maskedPhone});

  final String maskedPhone;

  @override
  State<VerifyPhonePage> createState() => _VerifyPhonePageState();
}

class _VerifyPhonePageState extends State<VerifyPhonePage> {
  final _nodes = List.generate(6, (_) => FocusNode());
  final _controllers = List.generate(6, (_) => TextEditingController());

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      final last = value.substring(value.length - 1);
      _controllers[index].text = last;
      _controllers[index].selection = const TextSelection.collapsed(offset: 1);
    }
    if (value.isNotEmpty && index < 5) {
      _nodes[index + 1].requestFocus();
    }
    setState(() {});
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
        title: const Text(
          'Verify Your Identity',
          style: TextStyle(color: Color(0xFF0B3A70), fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFF0066CC),
              child: Icon(Icons.vibration, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Verify your phone number',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.15),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 16, color: Color(0xFF414753), height: 1.4),
              children: [
                const TextSpan(text: 'We\'ve sent a 6-digit code to '),
                TextSpan(
                  text: widget.maskedPhone,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0066CC)),
                ),
                const TextSpan(text: '. Please enter it below.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Row(
            children: List.generate(6, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _nodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0066CC)),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0E3E6)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0066CC), width: 2),
                      ),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) => _onDigitChanged(i, v),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),
          const Center(
            child: Text('Didn\'t receive a code?', style: TextStyle(color: Color(0xFF414753), fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 8),
          Center(
            child: FilledButton.tonal(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code resent (demo).')));
              },
              child: const Text('Resend code'),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _code.length == 6
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone verified (demo).')));
                    context.go('/login');
                  }
                : null,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Verify and Continue'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: const Color(0xFF0066CC),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFF0066CC)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Why do I need this?', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF414753))),
                      SizedBox(height: 6),
                      Text(
                        'This ensures only you can access your private health records and MediAgent services.',
                        style: TextStyle(color: Color(0xFF414753), height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
