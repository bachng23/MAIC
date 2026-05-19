import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF004E9F)),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF004E9F), fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x0A191C1E), blurRadius: 20, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  onTap: () => _showComingSoon(context, 'Notifications'),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsRow(
                  icon: Icons.lock_outline,
                  label: 'Data Privacy',
                  onTap: () => _showComingSoon(context, 'Data Privacy'),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsRow(
                  icon: Icons.dark_mode_outlined,
                  label: 'Theme (Light/Dark)',
                  onTap: () => _showComingSoon(context, 'Theme'),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsRow(
                  icon: Icons.help_outline,
                  label: 'Help & Support',
                  onTap: () => _showComingSoon(context, 'Help & Support'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature settings coming soon.')),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF4C616C)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFC1C6D5)),
            ],
          ),
        ),
      ),
    );
  }
}
