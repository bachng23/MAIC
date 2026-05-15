import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../shared/data/mediguard_api_service.dart';
import '../../shared/models/api_models.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FB).withValues(alpha: 0.88),
        elevation: 0,
        titleSpacing: 16,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFD1E4FF),
              child: Icon(Icons.person, color: Color(0xFF004A99)),
            ),
            SizedBox(width: 10),
            Text('MediAgent', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0B3A70))),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF0B3A70)),
          ),
        ],
      ),
      body: state.when(
        data: (data) => LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 900;
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              children: [
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 8, child: _MedsCard(data: data)),
                      const SizedBox(width: 16),
                      const Expanded(flex: 4, child: _HealthSnapshotCard()),
                    ],
                  )
                else ...[
                  _MedsCard(data: data),
                  const SizedBox(height: 16),
                  const _HealthSnapshotCard(),
                ],
                const SizedBox(height: 16),
                _ScanActionButton(onPressed: () => context.go('/scan')),
                const SizedBox(height: 16),
                const _HeroCard(),
                const SizedBox(height: 16),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _EmergencyCard(data: data)),
                      const SizedBox(width: 16),
                      Expanded(flex: 7, child: _WeeklyReportCard(data: data)),
                    ],
                  )
                else ...[
                  _WeeklyReportCard(data: data),
                  const SizedBox(height: 16),
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
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF0066CC), Color(0xFF004E9F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your health,\nsynchronized.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Daily adherence is key to recovery.',
            style: TextStyle(color: Color(0xCCFFFFFF), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _MedsCard extends StatelessWidget {
  const _MedsCard({required this.data});
  final DashboardViewData data;

  @override
  Widget build(BuildContext context) {
    final meds = data.medications.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Today\'s Medications',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x1A0066CC),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${meds.length}/${data.schedules.length} Doses',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0066CC)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (meds.isEmpty)
            const Text('No medications found.')
          else
            ...meds.map(
              (med) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MedicationTile(med: med),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.go('/compliance'),
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('View Full Schedule'),
          ),
        ],
      ),
    );
  }
}

class _MedicationTile extends StatelessWidget {
  const _MedicationTile({required this.med});
  final MedicationOut med;

  @override
  Widget build(BuildContext context) {
    final isTaken = med.isActive;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isTaken ? const Color(0xFFD1E4FF) : const Color(0xFFFFDDB8),
            child: Icon(Icons.medication_outlined, color: isTaken ? const Color(0xFF0066CC) : const Color(0xFF855300)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  med.dosage ?? 'Dosage not set',
                  style: const TextStyle(color: Color(0xFF3E4946), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isTaken ? const Color(0xFF0066CC) : const Color(0xFFFEA619),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isTaken ? 'TAKEN' : 'PENDING',
              style: TextStyle(
                color: isTaken ? Colors.white : const Color(0xFF684000),
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthSnapshotCard extends StatelessWidget {
  const _HealthSnapshotCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Health Monitoring', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21)),
          const SizedBox(height: 14),
          const _VitalsRow(
            icon: Icons.favorite,
            iconColor: Color(0xFFB9161C),
            label: 'Heart Rate',
            value: '72',
            unit: 'BPM',
          ),
          const SizedBox(height: 10),
          const _VitalsRow(
            icon: Icons.water_drop,
            iconColor: Color(0xFF0066CC),
            label: 'SpO2',
            value: '98',
            unit: '%',
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0x330066CC),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(10),
            child: const Row(
              children: [
                Icon(Icons.verified_user, size: 16, color: Color(0xFF004A99)),
                SizedBox(width: 8),
                Text('All vitals normal', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF004A99))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalsRow extends StatelessWidget {
  const _VitalsRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF3E4946))),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: iconColor)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(unit, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF3E4946))),
                ),
              ],
            ),
          ],
        ),
        Icon(icon, color: iconColor, size: 28),
      ],
    );
  }
}

class _ScanActionButton extends StatelessWidget {
  const _ScanActionButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.qr_code_scanner),
      label: const Text('Scan New Medication'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        foregroundColor: const Color(0xFF0066CC),
        side: const BorderSide(color: Color(0x4D0066CC), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _WeeklyReportCard extends StatelessWidget {
  const _WeeklyReportCard({required this.data});
  final DashboardViewData data;

  @override
  Widget build(BuildContext context) {
    final total = data.schedules.fold<int>(0, (sum, s) => sum + s.times.length);
    final percent = total == 0 ? 0 : ((total * 0.94) * 100 / total).round();
    const bars = [0.8, 0.95, 0.6, 1.0, 0.85, 0.9, 0.4];
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly Report', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21)),
                  Text('Excellent consistency', style: TextStyle(fontSize: 12, color: Color(0xFF3E4946))),
                ],
              ),
              Text('$percent%', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0066CC))),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: 60 * bars[i],
                      decoration: BoxDecoration(
                        color: i == 3 ? const Color(0xFF0066CC) : const Color(0xFFA6C8FF),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.map((e) => Text(e, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF3E4946)))).toList(),
          ),
        ],
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.data});
  final DashboardViewData data;

  @override
  Widget build(BuildContext context) {
    final shown = data.contacts.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Emergency', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: shown
                .map((c) => Chip(
                      backgroundColor: Colors.white,
                      label: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.go('/health'),
            icon: const Icon(Icons.emergency_share),
            label: const Text('Send Alert'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: const Color(0xFFB9161C),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
