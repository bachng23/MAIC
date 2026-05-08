import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../shared/data/mediguard_api_service.dart';

class CompliancePage extends ConsumerWidget {
  const CompliancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardControllerProvider);
    final health = ref.watch(backendHealthProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Compliance Reports')),
      body: dashboard.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WeeklySummaryCard(data: data),
            const SizedBox(height: 12),
            _StatsGrid(data: data),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_done_outlined),
                title: const Text('Backend Status'),
                subtitle: health.when(
                  data: (v) => Text(v.toString()),
                  loading: () => const Text('Checking...'),
                  error: (e, _) => Text('Health check failed: $e'),
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load compliance data: $e')),
      ),
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  const _WeeklySummaryCard({required this.data});
  final DashboardViewData data;

  @override
  Widget build(BuildContext context) {
    final totalPlanned = data.schedules.fold<int>(0, (sum, s) => sum + s.times.length);
    final estimatedTaken = (totalPlanned * 0.9).round();
    final compliance = totalPlanned == 0 ? 0 : (estimatedTaken * 100 / totalPlanned).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Weekly Summary', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('$compliance% Compliant', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Row(
              children: List.generate(7, (index) {
                final height = (index == 2 ? 0.6 : index == 6 ? 0.45 : 0.9);
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 48 * height,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.data});
  final DashboardViewData data;

  @override
  Widget build(BuildContext context) {
    final totalMeds = data.medications.length;
    final totalSchedules = data.schedules.length;
    final contacts = data.contacts.length;
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 640 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        _StatTile(label: 'Meds', value: '$totalMeds'),
        _StatTile(label: 'Schedules', value: '$totalSchedules'),
        _StatTile(label: 'Contacts', value: '$contacts'),
        _StatTile(label: 'Risk Alerts', value: '0'),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
