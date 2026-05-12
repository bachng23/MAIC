import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../shared/models/api_models.dart' show EmergencyContact;

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  static String _initials(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final s = parts.first;
      return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s.toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardControllerProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom + 88;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: dash.when(
        data: (data) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: const Color(0xE6F7F9FC),
                surfaceTintColor: Colors.transparent,
                title: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFE6E8EB),
                      child: Icon(Icons.person, color: Color(0xFF004E9F)),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'MediAgent',
                      style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF004E9F), fontSize: 20),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.settings_outlined, color: Color(0xFF004E9F)),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    const CircleAvatar(
                      radius: 56,
                      backgroundColor: Color(0xFFE6E8EB),
                      child: Icon(Icons.person, size: 56, color: Color(0xFF004E9F)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'MediAgent User',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF004E9F)),
                    ),
                    const Text(
                      'Your care profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Color(0xFF4C616C), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 28),
                    _SectionCard(
                      title: 'Emergency Contacts',
                      icon: Icons.emergency_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (data.contacts.isEmpty)
                            const Text(
                              'No emergency contacts yet.',
                              style: TextStyle(color: Color(0xFF414753)),
                            )
                          else
                            ...data.contacts.map((c) => _ContactRow(contact: c)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Add contact flow coming soon.')),
                              );
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Add New Emergency Contact'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'Health Profile',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth > 720;
                        final tiles = [
                          _HealthTile(
                            icon: Icons.bloodtype,
                            iconBg: const Color(0xFFD7E3FF),
                            label: 'Blood Type',
                            value: '—',
                          ),
                          _HealthTile(
                            icon: Icons.coronavirus_outlined,
                            iconBg: const Color(0xFFFFDAD6),
                            iconColor: const Color(0xFFBA1A1A),
                            label: 'Allergies',
                            value: '—',
                          ),
                          _HealthTile(
                            icon: Icons.monitor_heart_outlined,
                            iconBg: const Color(0xFFFFDFA0),
                            iconColor: const Color(0xFF684C00),
                            label: 'Conditions',
                            value: '—',
                          ),
                        ];
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < tiles.length; i++) ...[
                                if (i > 0) const SizedBox(width: 12),
                                Expanded(child: tiles[i]),
                              ],
                            ],
                          );
                        }
                        return Column(
                          children: [
                            for (final t in tiles) ...[t, const SizedBox(height: 12)],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _SectionCard(
                      title: 'App Settings',
                      icon: null,
                      child: Column(
                        children: [
                          _SettingsRow(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () {}),
                          _SettingsRow(icon: Icons.lock_outline, label: 'Data Privacy', onTap: () {}),
                          _SettingsRow(icon: Icons.dark_mode_outlined, label: 'Theme (Light/Dark)', onTap: () {}),
                          _SettingsRow(icon: Icons.help_outline, label: 'Help & Support', onTap: () {}),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton.icon(
                        onPressed: () async {
                          await ref.read(authControllerProvider).logout();
                          if (context.mounted) context.go('/login');
                        },
                        icon: const Icon(Icons.logout, color: Color(0xFFBA1A1A)),
                        label: const Text('Sign Out', style: TextStyle(color: Color(0xFFBA1A1A), fontSize: 17)),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.icon});

  final String title;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A191C1E), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: const Color(0xFF0066CC)),
                const SizedBox(width: 8),
              ],
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact});

  final EmergencyContact contact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFCFE6F2),
              child: Text(
                ProfilePage._initials(contact.name),
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF526772)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                  Text('${contact.relation} • ${contact.phone}', style: const TextStyle(color: Color(0xFF4C616C))),
                ],
              ),
            ),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: const Color(0xFF0066CC), foregroundColor: Colors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Call ${contact.phone}')));
              },
              icon: const Icon(Icons.call),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthTile extends StatelessWidget {
  const _HealthTile({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.value,
    this.iconColor,
  });

  final IconData icon;
  final Color iconBg;
  final Color? iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A191C1E), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: iconBg,
            child: Icon(icon, color: iconColor ?? const Color(0xFF004E9F)),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: Color(0xFF4C616C), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      ),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF4C616C)),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500))),
              const Icon(Icons.chevron_right, color: Color(0xFFC1C6D5)),
            ],
          ),
        ),
      ),
    );
  }
}
