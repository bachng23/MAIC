import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/monitoring_service.dart';

class HealthPage extends ConsumerStatefulWidget {
  const HealthPage({super.key});

  @override
  ConsumerState<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends ConsumerState<HealthPage> {
  final _logId = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Trigger an immediate read so the page shows fresh data as soon as it opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(monitoringServiceProvider).manualRefresh();
    });
  }

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
          Builder(
            builder: (_) {
              final monitor = ref.watch(monitoringServiceProvider);
              if (monitor.isWatchSource) {
                return const Row(
                  children: [
                    CircleAvatar(radius: 5, backgroundColor: Color(0xFF0066CC)),
                    SizedBox(width: 8),
                    Text(
                      '⌚ LIVE FROM APPLE WATCH',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0066CC),
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                );
              }
              if (monitor.latestSnapshot != null) {
                return const Row(
                  children: [
                    CircleAvatar(radius: 5, backgroundColor: Color(0xFF5C7B9A)),
                    SizedBox(width: 8),
                    Text(
                      '📱 FROM IPHONE',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5C7B9A),
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
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
        ],
      ),
    );
  }
}

class _VitalsGrid extends ConsumerWidget {
  const _VitalsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitor = ref.watch(monitoringServiceProvider);
    final snapshot = monitor.latestSnapshot;

    final hrValue = snapshot?.heartRate?.round().toString() ?? '—';
    final spo2Value = snapshot?.spo2?.round().toString() ?? '—';
    final hrStatus = snapshot == null
        ? 'Waiting for data'
        : _hrStatus(snapshot.heartRate);
    final spo2Status = snapshot == null
        ? 'Waiting for data'
        : _spo2Status(snapshot.spo2);

    return Column(
      children: [
        if (!monitor.isMonitoring && snapshot == null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBDD3F9)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF0066CC), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Confirm a dose to start Apple Watch monitoring.',
                    style: TextStyle(color: Color(0xFF0B3A70), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        if (monitor.isMonitoring)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F2FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF0066CC).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const CircleAvatar(radius: 5, backgroundColor: Color(0xFF0066CC)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    monitor.activeMedicationName != null
                        ? 'Monitoring after ${monitor.activeMedicationName} · ${MonitoringService.formatDuration(monitor.remainingSeconds)} left'
                        : 'Monitoring active · ${MonitoringService.formatDuration(monitor.remainingSeconds)} left',
                    style: const TextStyle(color: Color(0xFF0B3A70), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 760;
            if (!wide) {
              return Column(
                children: [
                  _VitalCard(
                    title: 'Heart Rate',
                    value: hrValue,
                    unit: 'BPM',
                    accent: const Color(0xFF0066CC),
                    icon: Icons.favorite,
                    status: hrStatus,
                  ),
                  const SizedBox(height: 12),
                  _VitalCard(
                    title: 'Blood Oxygen',
                    value: spo2Value,
                    unit: '%',
                    accent: const Color(0xFFFEA619),
                    icon: Icons.bloodtype,
                    status: spo2Status,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: _VitalCard(
                    title: 'Heart Rate',
                    value: hrValue,
                    unit: 'BPM',
                    accent: const Color(0xFF0066CC),
                    icon: Icons.favorite,
                    status: hrStatus,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _VitalCard(
                    title: 'Blood Oxygen',
                    value: spo2Value,
                    unit: '%',
                    accent: const Color(0xFFFEA619),
                    icon: Icons.bloodtype,
                    status: spo2Status,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  static String _hrStatus(double? hr) {
    if (hr == null) return 'No data';
    if (hr < 60) return 'Low — check if resting';
    if (hr <= 100) return 'Safe Range';
    if (hr <= 120) return 'Slightly elevated';
    return 'Elevated — monitor';
  }

  static String _spo2Status(double? spo2) {
    if (spo2 == null) return 'No data';
    if (spo2 >= 95) return 'Normal';
    if (spo2 >= 90) return 'Monitor Closely';
    return 'Low — seek help';
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

  Future<void> _handleEmergency(BuildContext context, WidgetRef ref) async {
    final MonitoringService monitor = ref.read(monitoringServiceProvider);
    final logId = monitor.activeLogId ?? '';

    // 1. Report to backend (even without active session — user may feel unwell anytime)
    final health = ref.read(healthControllerProvider);
    if (logId.isNotEmpty) {
      await health.reportTestAnomaly(logId);
    }

    if (!context.mounted) return;

    // 2. Get emergency contacts from cached dashboard
    final dashAsync = ref.read(dashboardControllerProvider);
    final contacts = dashAsync.valueOrNull?.contacts ?? [];

    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFB9161C),
          content: Text('No emergency contacts found. Please add contacts in Settings.'),
        ),
      );
      return;
    }

    // 3. Build message
    final medName = monitor.activeMedicationName;
    final message = medName != null
        ? '🚨 [MediGuard] I need help! I took $medName and am feeling unwell. Please contact me immediately.'
        : '🚨 [MediGuard] I need help! I am feeling unwell. Please contact me immediately.';

    // 4. Send iMessage to all contacts (opens Messages app)
    final bridge = ref.read(bridgeProvider);
    try {
      await bridge.sendIMessage(
        contacts: contacts.map((c) => {'phone': c.phone}).toList(),
        message: message,
      );
    } catch (_) {
      // Messages app may not be available — continue to call dialog
    }

    if (!context.mounted) return;

    // 5. Ask if user wants to call the first contact
    final firstContact = contacts.first;
    final shouldCall = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Call for Help?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Do you want to call ${firstContact.name} (${firstContact.phone}) right now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB9161C)),
            child: const Text('Yes, Call Now'),
          ),
        ],
      ),
    );

    if (shouldCall == true && context.mounted) {
      try {
        await bridge.emergencyCall(number: firstContact.phone);
      } catch (_) {}
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFB9161C),
          content: Text('Emergency alert sent!'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (ctx, ref, _) {
        final health = ref.watch(healthControllerProvider);
        return Column(
          children: [
            FilledButton.icon(
              onPressed: health.isLoading
                  ? null
                  : () => _handleEmergency(ctx, ref),
              icon: health.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Icon(Icons.emergency_rounded, size: 28),
              label: const Text(
                'Send Emergency Alert',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 80),
                backgroundColor: const Color(0xFFB9161C),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap if you feel unwell — sends iMessage & offers to call your emergency contacts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF757575), fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}
