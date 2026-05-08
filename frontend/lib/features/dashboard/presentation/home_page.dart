import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../shared/data/mediguard_api_service.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediAgent Dashboard'),
        actions: [
          IconButton(
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: state.when(
        data: (data) => LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 860;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeroCard(count: data.medications.length),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => context.go('/scan'),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/health'),
                          icon: const Icon(Icons.monitor_heart_outlined),
                          label: const Text('Health'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/compliance'),
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('Compliance'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _MedsCard(data: data)),
                      const SizedBox(width: 12),
                      Expanded(child: _EmergencyCard(data: data)),
                    ],
                  )
                else ...[
                  _MedsCard(data: data),
                  const SizedBox(height: 12),
                  _EmergencyCard(data: data),
                ],
              ],
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Failed to load dashboard: $e')),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.health_and_safety),
        title: const Text('Your health, synchronized.'),
        subtitle: Text('$count active medications'),
      ),
    );
  }
}

class _MedsCard extends StatelessWidget {
  const _MedsCard({required this.data});
  final DashboardViewData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today\'s Medications', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...data.medications.take(6).map<Widget>((med) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.medication_outlined),
                  title: Text(med.name),
                  subtitle: Text(med.dosage ?? 'Dosage not set'),
                )),
          ],
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.data});
  final DashboardViewData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emergency Contacts', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...data.contacts.map<Widget>((c) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.contact_phone_outlined),
                  title: Text(c.name),
                  subtitle: Text('${c.relation} • ${c.phone}'),
                )),
          ],
        ),
      ),
    );
  }
}
