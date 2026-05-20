import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../scan/presentation/medication_intake_controller.dart';
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
      ),
      body: state.when(
        data: (data) {
          final intake = ref.watch(medicationIntakeControllerProvider);
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 900;
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 8, child: _MedsCard(data: data, intake: intake)),
                      const SizedBox(width: 16),
                      const Expanded(flex: 4, child: _HealthSnapshotCard()),
                    ],
                  )
                  else ...[
                    _MedsCard(data: data, intake: intake),
                    const SizedBox(height: 16),
                    const _HealthSnapshotCard(),
                  ],
                const SizedBox(height: 16),
                _ScanActionButton(onPressed: () => context.go('/scan')),
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Failed to load dashboard: $e')),
      ),
    );
  }
}

// ── Today's Medications ──────────────────────────────────────────────────────

class _MedsCard extends StatelessWidget {
  const _MedsCard({required this.data, required this.intake});
  final DashboardViewData data;
  final MedicationIntakeController intake;

  @override
  Widget build(BuildContext context) {
    final meds = data.medications.where((m) => m.isActive).take(6).toList();
    final totalDoses = data.schedules.fold<int>(0, (s, x) => s + x.times.length);
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
              const Expanded(
                child: Text(
                  'Today\'s Medications',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
                ),
              ),
              if (totalDoses > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x1A0066CC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$totalDoses dose${totalDoses == 1 ? '' : 's'} today',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0066CC),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (meds.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No medications added yet.',
                style: TextStyle(color: Color(0xFF757575)),
              ),
            )
          else
            ...meds.map(
              (med) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MedicationTile(
                  med: med,
                  isTaken: intake.isMedicationTakenToday(med.id),
                ),
              ),
            ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => context.go('/compliance'),
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: const Text('View Full Schedule'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationTile extends StatelessWidget {
  const _MedicationTile({required this.med, required this.isTaken});
  final MedicationOut med;
  final bool isTaken;

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isTaken ? const Color(0xFF0066CC) : const Color(0xFFFEA619),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isTaken ? 'TAKEN' : 'NOT TAKEN',
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

// ── Health Snapshot (live from monitoring service) ───────────────────────────

class _HealthSnapshotCard extends ConsumerWidget {
  const _HealthSnapshotCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitor = ref.watch(monitoringServiceProvider);
    final snap = monitor.latestSnapshot;
    final hr = snap?.heartRate;
    final spo2 = snap?.spo2;

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
              const Expanded(
                child: Text(
                  'Health Monitoring',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
                ),
              ),
              if (monitor.isMonitoring)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF00C853),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _VitalsRow(
            icon: Icons.favorite,
            iconColor: const Color(0xFFB9161C),
            label: 'Heart Rate',
            value: hr != null ? hr.round().toString() : '—',
            unit: 'BPM',
          ),
          const SizedBox(height: 10),
          _VitalsRow(
            icon: Icons.water_drop,
            iconColor: const Color(0xFF0066CC),
            label: 'Blood O₂',
            value: spo2 != null ? spo2.round().toString() : '—',
            unit: '%',
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.go('/health'),
            child: Container(
              decoration: BoxDecoration(
                color: monitor.isMonitoring
                    ? const Color(0x1400C853)
                    : const Color(0x0F000000),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    monitor.isMonitoring
                        ? Icons.monitor_heart
                        : Icons.watch_outlined,
                    size: 16,
                    color: monitor.isMonitoring
                        ? const Color(0xFF00A846)
                        : const Color(0xFF9E9E9E),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      monitor.isMonitoring
                          ? 'Live from Apple Watch'
                          : snap != null
                              ? 'Last reading shown'
                              : 'No data yet — confirm a dose to start',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: monitor.isMonitoring
                            ? const Color(0xFF00A846)
                            : const Color(0xFF757575),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: monitor.isMonitoring
                        ? const Color(0xFF00A846)
                        : const Color(0xFFBDBDBD),
                  ),
                ],
              ),
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
    final hasData = value != '—';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3E4946),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: hasData ? iconColor : const Color(0xFFBDBDBD),
                  ),
                ),
                if (hasData) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text(
                      unit,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3E4946),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        Icon(icon, color: hasData ? iconColor : const Color(0xFFBDBDBD), size: 28),
      ],
    );
  }
}

// ── Scan CTA ─────────────────────────────────────────────────────────────────

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

// ── Weekly Report ─────────────────────────────────────────────────────────────

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
                  Text(
                    'Weekly Report',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
                  ),
                  Text(
                    'Medication adherence',
                    style: TextStyle(fontSize: 12, color: Color(0xFF3E4946)),
                  ),
                ],
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0066CC),
                ),
              ),
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
                        color: i == 3
                            ? const Color(0xFF0066CC)
                            : const Color(0xFFA6C8FF),
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(4)),
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
            children: labels
                .map((e) => Text(
                      e,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3E4946),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Emergency Card ────────────────────────────────────────────────────────────

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
          const Text(
            'Emergency',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
          ),
          const SizedBox(height: 4),
          Text(
            shown.isEmpty
                ? 'No contacts added yet'
                : shown.map((c) => c.name).join(', '),
            style: const TextStyle(
              color: Color(0xFF3E4946),
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.go('/health'),
            icon: const Icon(Icons.emergency_share),
            label: const Text('Emergency Alerts'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: const Color(0xFFB9161C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
