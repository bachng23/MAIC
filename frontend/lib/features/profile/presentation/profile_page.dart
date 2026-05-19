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
    final userProfile = ref.watch(profileControllerProvider).profile;
    final displayName = userProfile.name.trim().isEmpty ? 'MediAgent User' : userProfile.name.trim();
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
                      onPressed: () => context.push('/profile/settings'),
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
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF004E9F)),
                    ),
                    const Text(
                      'Your care profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Color(0xFF4C616C), fontWeight: FontWeight.w500),
                    ),
                    if (userProfile.age != null || userProfile.address.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        [
                          if (userProfile.age != null) 'Age ${userProfile.age}',
                          if (userProfile.address.trim().isNotEmpty) userProfile.address.trim(),
                        ].join(' · '),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF4C616C)),
                      ),
                    ],
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
                    _HealthProfileGrid(
                      bloodType: userProfile.displayOrDash(userProfile.bloodType),
                      allergies: userProfile.displayOrDash(userProfile.allergies),
                      conditions: userProfile.displayOrDash(userProfile.medicalConditions),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => context.push('/profile/edit'),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(userProfile.hasAnyData ? 'Edit Profile' : 'Add Profile Info'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: const Color(0xFF0066CC),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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

class _HealthProfileGrid extends StatelessWidget {
  const _HealthProfileGrid({
    required this.bloodType,
    required this.allergies,
    required this.conditions,
  });

  final String bloodType;
  final String allergies;
  final String conditions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _HealthTile(
            icon: Icons.bloodtype,
            iconBg: const Color(0xFFD7E3FF),
            label: 'Blood Type',
            value: bloodType,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _HealthTile(
            icon: Icons.coronavirus_outlined,
            iconBg: const Color(0xFFFFDAD6),
            iconColor: const Color(0xFFBA1A1A),
            label: 'Allergies',
            value: allergies,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _HealthTile(
            icon: Icons.monitor_heart_outlined,
            iconBg: const Color(0xFFFFDFA0),
            iconColor: const Color(0xFF684C00),
            label: 'Conditions',
            value: conditions,
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
            radius: 16,
            backgroundColor: iconBg,
            child: Icon(icon, size: 18, color: iconColor ?? const Color(0xFF004E9F)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF4C616C), fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.2),
          ),
        ],
      ),
    );
  }
}
