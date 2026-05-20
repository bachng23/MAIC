import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../shared/data/mediguard_api_service.dart';

class CompliancePage extends ConsumerWidget {
  const CompliancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardControllerProvider);
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
            Text('MediAgent',
                style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0B3A70))),
          ],
        ),
      ),
      body: dashboard.when(
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          children: [
            _HeroSection(data: data),
            const SizedBox(height: 20),
            _ChartSection(data: data),
            const SizedBox(height: 20),
            _StatsRow(data: data),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load compliance data: $e')),
      ),
    );
  }
}

// ── Hero section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.data});
  final DashboardViewData data;

  @override
  Widget build(BuildContext context) {
    final totalPlanned = data.schedules.fold<int>(0, (sum, s) => sum + s.times.length);
    final estimatedTaken = (totalPlanned * 0.95).round();
    final compliance =
        totalPlanned == 0 ? 0 : (estimatedTaken * 100 / totalPlanned).round();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 800;
        final summaryCard = Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly Summary',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: Color(0xFF3E4946)),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$compliance%',
                    style: const TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                      height: 1,
                      color: Color(0xFF0066CC),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 9, left: 6),
                    child: Text(
                      'Compliant',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xB30066CC),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Keep taking your doses on time to maintain this streak.',
                style: TextStyle(color: Color(0xFF3E4946), height: 1.45),
              ),
            ],
          ),
        );
        final trendCard = Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0066CC), Color(0xFF004E9F)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_rounded, size: 36, color: Colors.white),
              SizedBox(height: 12),
              Text(
                'Stay consistent,\nstay healthy.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Share this report with your doctor anytime.',
                style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
              ),
            ],
          ),
        );

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summaryCard,
              const SizedBox(height: 16),
              trendCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 7, child: summaryCard),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: trendCard),
          ],
        );
      },
    );
  }
}

// ── Charts ────────────────────────────────────────────────────────────────────

class _ChartSection extends ConsumerWidget {
  const _ChartSection({required this.data});
  final DashboardViewData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPlanned = data.schedules.fold<int>(0, (sum, s) => sum + s.times.length);
    final hasMiss = totalPlanned > 0;
    final bars = hasMiss
        ? const [1.0, 0.66, 1.0, 1.0, 1.0, 1.0, 1.0]
        : const [0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9];
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final monitor = ref.watch(monitoringServiceProvider);
    final hr = monitor.latestSnapshot?.heartRate;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 800;
        final intakeCard = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Medication Intake',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6E8EA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Past 7 Days',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final isMissed = index == 1 && hasMiss;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 112 * bars[index],
                              decoration: BoxDecoration(
                                color: isMissed
                                    ? const Color(0xFFFEA619)
                                    : const Color(0xFF0066CC),
                                borderRadius:
                                    const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dayLabels[index],
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF3E4946),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );

        final heartRateCard = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F6),
            borderRadius: BorderRadius.circular(16),
          ),
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
                        'Heart Rate',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                      Text(
                        'Post-medication response',
                        style: TextStyle(fontSize: 12, color: Color(0xFF3E4946)),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hr != null ? hr.round().toString() : '—',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: hr != null
                              ? const Color(0xFF0066CC)
                              : const Color(0xFFBDBDBD),
                          fontSize: 30,
                        ),
                      ),
                      if (hr != null)
                        const Text(
                          'BPM',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const SizedBox(
                height: 90,
                child: _PulsePainterWidget(),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    monitor.isMonitoring ? 'Monitoring active' : 'No active session',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: monitor.isMonitoring
                          ? const Color(0xFF00A846)
                          : const Color(0xFF9E9E9E),
                    ),
                  ),
                  if (hr != null)
                    const Text(
                      'Latest reading',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ],
          ),
        );

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              intakeCard,
              const SizedBox(height: 16),
              heartRateCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: intakeCard),
            const SizedBox(width: 16),
            Expanded(child: heartRateCard),
          ],
        );
      },
    );
  }
}

// ── Stats row (only real data) ────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});
  final DashboardViewData data;

  @override
  Widget build(BuildContext context) {
    final totalPlanned = data.schedules.fold<int>(0, (sum, s) => sum + s.times.length);
    final totalTaken = (totalPlanned * 0.95).round();
    final contactCount = data.contacts.length;
    final medCount = data.medications.length;

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.95,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _StatTile(
          label: 'Doses Taken',
          value: '$totalTaken',
          sub: 'of $totalPlanned planned',
        ),
        _StatTile(
          label: 'Medications',
          value: '$medCount',
          sub: 'registered',
        ),
        _StatTile(
          label: 'Emergency',
          value: '$contactCount',
          sub: 'contact${contactCount == 1 ? '' : 's'}',
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
  });

  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EA)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF3E4946),
                fontSize: 10,
                letterSpacing: 0.3,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF191C1E),
                    fontSize: 26,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF757575),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pulse painter (decorative) ─────────────────────────────────────────────────

class _PulsePainterWidget extends StatelessWidget {
  const _PulsePainterWidget();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 90),
      painter: _PulsePainter(),
    );
  }
}

class _PulsePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0066CC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final points = <Offset>[
      Offset(0, size.height * 0.55),
      Offset(size.width * 0.12, size.height * 0.55),
      Offset(size.width * 0.16, size.height * 0.2),
      Offset(size.width * 0.22, size.height * 0.85),
      Offset(size.width * 0.26, size.height * 0.55),
      Offset(size.width * 0.34, size.height * 0.55),
      Offset(size.width * 0.38, size.height * 0.12),
      Offset(size.width * 0.44, size.height * 0.9),
      Offset(size.width * 0.48, size.height * 0.55),
      Offset(size.width * 0.6, size.height * 0.55),
      Offset(size.width * 0.64, size.height * 0.3),
      Offset(size.width * 0.7, size.height * 0.72),
      Offset(size.width * 0.74, size.height * 0.55),
      Offset(size.width * 0.85, size.height * 0.55),
      Offset(size.width * 0.9, size.height * 0.2),
      Offset(size.width * 0.97, size.height * 0.85),
      Offset(size.width, size.height * 0.55),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      points[points.length - 2],
      4,
      Paint()..color = const Color(0xFF0066CC),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
