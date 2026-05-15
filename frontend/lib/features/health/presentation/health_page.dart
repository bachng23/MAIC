import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../shared/models/api_models.dart';

class HealthPage extends ConsumerStatefulWidget {
  const HealthPage({super.key});

  @override
  ConsumerState<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends ConsumerState<HealthPage> {
  final _logId = TextEditingController();

  @override
  void dispose() {
    _logId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(healthControllerProvider);
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
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF0B3A70)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          const Row(
            children: [
              CircleAvatar(radius: 5, backgroundColor: Color(0xFF0066CC)),
              SizedBox(width: 8),
              Text(
                'LIVE FROM APPLE WATCH',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0066CC),
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Health Monitor', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 1.05)),
          const SizedBox(height: 16),
          TextField(
            controller: _logId,
            decoration: InputDecoration(
              labelText: 'Medication Log ID',
              hintText: 'Enter log_id from taken medication flow',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFBDC9C5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF0066CC), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 760;
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ActionButton(
                      icon: Icons.monitor_heart_outlined,
                      label: 'Fetch Status',
                      background: const Color(0xFF0066CC),
                      foreground: Colors.white,
                      onPressed: controller.isLoading
                          ? null
                          : () => ref.read(healthControllerProvider).getStatus(_logId.text.trim()),
                    ),
                    const SizedBox(height: 10),
                    _ActionButton(
                      icon: Icons.warning_amber_rounded,
                      label: 'Report Test Anomaly',
                      background: const Color(0xFFE0E3E5),
                      foreground: const Color(0xFF191C1E),
                      onPressed: controller.isLoading
                          ? null
                          : () => ref.read(healthControllerProvider).reportTestAnomaly(_logId.text.trim()),
                    ),
                    const SizedBox(height: 10),
                    _ActionButton(
                      icon: Icons.verified_outlined,
                      label: 'Resolve Alert',
                      background: const Color(0xFFE0E3E5),
                      foreground: const Color(0xFF191C1E),
                      onPressed: controller.isLoading
                          ? null
                          : () => ref.read(healthControllerProvider).resolve(_logId.text.trim()),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.monitor_heart_outlined,
                      label: 'Fetch Status',
                      background: const Color(0xFF0066CC),
                      foreground: Colors.white,
                      onPressed: controller.isLoading
                          ? null
                          : () => ref.read(healthControllerProvider).getStatus(_logId.text.trim()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.warning_amber_rounded,
                      label: 'Report Test Anomaly',
                      background: const Color(0xFFE0E3E5),
                      foreground: const Color(0xFF191C1E),
                      onPressed: controller.isLoading
                          ? null
                          : () => ref.read(healthControllerProvider).reportTestAnomaly(_logId.text.trim()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.verified_outlined,
                      label: 'Resolve Alert',
                      background: const Color(0xFFE0E3E5),
                      foreground: const Color(0xFF191C1E),
                      onPressed: controller.isLoading
                          ? null
                          : () => ref.read(healthControllerProvider).resolve(_logId.text.trim()),
                    ),
                  ),
                ],
              );
            },
          ),
          if (controller.error != null) ...[
            const SizedBox(height: 12),
            Text(controller.error!, style: const TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 18),
          const _VitalsGrid(),
          const SizedBox(height: 18),
          _ImpactTimeline(logId: _logId.text.trim()),
          const SizedBox(height: 18),
          _EmergencyAlertButton(
            onPressed: controller.isLoading
                ? null
                : () => ref.read(healthControllerProvider).reportTestAnomaly(_logId.text.trim()),
          ),
          if (controller.status != null) ...[
            const SizedBox(height: 18),
            _HealthStatusCard(status: controller.status!),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: background,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _VitalsGrid extends StatelessWidget {
  const _VitalsGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 760;
        if (!wide) {
          return const Column(
            children: [
              _VitalCard(
                title: 'Heart Rate',
                value: '72',
                unit: 'BPM',
                accent: Color(0xFF0066CC),
                icon: Icons.favorite,
                status: 'Safe Range',
              ),
              SizedBox(height: 12),
              _VitalCard(
                title: 'Blood Oxygen',
                value: '94',
                unit: '%',
                accent: Color(0xFFFEA619),
                icon: Icons.bloodtype,
                status: 'Monitor Closely',
              ),
            ],
          );
        }
        return const Row(
          children: [
            Expanded(
              child: _VitalCard(
                title: 'Heart Rate',
                value: '72',
                unit: 'BPM',
                accent: Color(0xFF0066CC),
                icon: Icons.favorite,
                status: 'Safe Range',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _VitalCard(
                title: 'Blood Oxygen',
                value: '94',
                unit: '%',
                accent: Color(0xFFFEA619),
                icon: Icons.bloodtype,
                status: 'Monitor Closely',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VitalCard extends StatelessWidget {
  const _VitalCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.accent,
    required this.icon,
    required this.status,
  });

  final String title;
  final String value;
  final String unit;
  final Color accent;
  final IconData icon;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x140066CC), blurRadius: 28, offset: Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6D7A76), fontSize: 11)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(value, style: const TextStyle(fontSize: 48, height: 1, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 5),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Text(unit, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6D7A76))),
                      ),
                    ],
                  ),
                ],
              ),
              Icon(icon, size: 30, color: accent),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 4, backgroundColor: accent),
                const SizedBox(width: 8),
                Text(status, style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactTimeline extends StatelessWidget {
  const _ImpactTimeline({required this.logId});
  final String logId;

  @override
  Widget build(BuildContext context) {
    const bars = [0.60, 0.65, 0.50, 0.45, 0.42, 0.40, 0.38, 0.38];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Post-Medication Impact', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          Text(
            logId.isEmpty ? 'Tracking heart rate trends after medication.' : 'Tracking for log ID: $logId',
            style: const TextStyle(color: Color(0xFF6D7A76)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(bars.length, (index) {
                final active = index == 2;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: 110 * bars[index],
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF0066CC) : const Color(0x330066CC),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('08:00 AM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6D7A76))),
              Text('10:00 AM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6D7A76))),
              Text('12:00 PM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6D7A76))),
              Text('02:00 PM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6D7A76))),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmergencyAlertButton extends StatelessWidget {
  const _EmergencyAlertButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.emergency, size: 32),
          label: const Text(
            'Send Emergency Alert',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 88),
            backgroundColor: const Color(0xFFB9161C),
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This immediately reports an emergency anomaly.',
          style: TextStyle(color: Color(0xFF6D7A76), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _HealthStatusCard extends StatelessWidget {
  const _HealthStatusCard({required this.status});
  final HealthStatus status;

  @override
  Widget build(BuildContext context) {
    final level = switch (status.alertLevel) {
      AnomalyLevel.low => 'Low',
      AnomalyLevel.medium => 'Medium',
      AnomalyLevel.high => 'High',
    };

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alert Level: $level', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            status.resolved
                ? 'Resolved'
                : status.monitoringActive
                    ? 'Monitoring active'
                    : 'Monitoring inactive',
            style: const TextStyle(color: Color(0xFF3E4946)),
          ),
        ],
      ),
    );
  }
}
