import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/providers.dart';
import '../../shared/models/api_models.dart' show EmergencyContact, EmergencyContactsUpdate;
import 'contact_edit_sheet.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
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

  Future<void> _saveContacts(BuildContext context, List<EmergencyContact> newContacts) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SavingDialog(),
    );
    try {
      await ref.read(apiServiceProvider).updateEmergencyContacts(
        EmergencyContactsUpdate(contacts: newContacts),
      );
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
      ref.invalidate(dashboardControllerProvider);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: const Color(0xFFBA1A1A),
        ),
      );
    }
  }

  Future<void> _openAddContact(BuildContext context, List<EmergencyContact> existing) async {
    final result = await showModalBottomSheet<EmergencyContact>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ContactEditSheet(),
    );
    if (result == null || !context.mounted) return;
    await _saveContacts(context, [...existing, result]);
  }

  Future<void> _openEditContact(
    BuildContext context,
    List<EmergencyContact> existing,
    int index,
  ) async {
    final result = await showModalBottomSheet<EmergencyContact>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ContactEditSheet(initialContact: existing[index]),
    );
    if (result == null || !context.mounted) return;
    final updated = [...existing];
    updated[index] = result;
    await _saveContacts(context, updated);
  }

  Future<void> _deleteContact(
    BuildContext context,
    List<EmergencyContact> existing,
    int index,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Contact'),
        content: Text('Remove ${existing[index].name} from emergency contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Color(0xFFBA1A1A)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final updated = [...existing]..removeAt(index);
    await _saveContacts(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final dash = ref.watch(dashboardControllerProvider);
    final userProfile = ref.watch(profileControllerProvider).profile;
    final displayName = userProfile.name.trim().isEmpty ? 'MediAgent User' : userProfile.name.trim();
    final bottomPad = MediaQuery.paddingOf(context).bottom + 88;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: dash.when(
        data: (data) {
          // Build contact rows with index
          final contactRows = <Widget>[];
          for (var i = 0; i < data.contacts.length; i++) {
            final c = data.contacts[i];
            contactRows.add(_ContactRow(
              contact: c,
              onCall: () async {
                final uri = Uri(scheme: 'tel', path: c.phone);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              onEdit: () => _openEditContact(context, data.contacts, i),
              onDelete: () => _deleteContact(context, data.contacts, i),
            ));
          }

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
                            ...contactRows,
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _openAddContact(context, data.contacts),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Add New Emergency Contact'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionCard(
                      title: 'Health Profile',
                      icon: Icons.favorite_border_rounded,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFF9E9E9E), size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Blood type, allergies, and conditions will be available in a future update.',
                                style: TextStyle(
                                  color: Color(0xFF757575),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
  const _ContactRow({
    required this.contact,
    required this.onCall,
    required this.onEdit,
    required this.onDelete,
  });

  final EmergencyContact contact;
  final Future<void> Function() onCall;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                _ProfilePageState._initials(contact.name),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: Color(0xFF526772)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 17)),
                  Text(
                    '${contact.relation} · ${contact.phone}',
                    style: const TextStyle(
                        color: Color(0xFF4C616C), fontSize: 13),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF0066CC),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onCall,
                  icon: const Icon(Icons.call),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  color: const Color(0xFF4C616C),
                  tooltip: 'Edit',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: const Color(0xFFBA1A1A),
                  tooltip: 'Remove',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavingDialog extends StatelessWidget {
  const _SavingDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF0066CC)),
              SizedBox(height: 20),
              Text(
                'Saving…',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B3A70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

