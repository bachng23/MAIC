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
      appBar: AppBar(title: const Text('Health Monitoring')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _logId,
            decoration: const InputDecoration(
              labelText: 'Medication Log ID',
              hintText: 'Enter log_id from taken medication flow',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: controller.isLoading
                    ? null
                    : () => ref.read(healthControllerProvider).getStatus(_logId.text.trim()),
                child: const Text('Fetch Status'),
              ),
              OutlinedButton(
                onPressed: controller.isLoading
                    ? null
                    : () => ref.read(healthControllerProvider).reportTestAnomaly(_logId.text.trim()),
                child: const Text('Report Test Anomaly'),
              ),
              OutlinedButton(
                onPressed: controller.isLoading
                    ? null
                    : () => ref.read(healthControllerProvider).resolve(_logId.text.trim()),
                child: const Text('Resolve Alert'),
              ),
            ],
          ),
          if (controller.error != null) ...[
            const SizedBox(height: 12),
            Text(controller.error!, style: const TextStyle(color: Colors.red)),
          ],
          if (controller.status != null) ...[
            const SizedBox(height: 16),
            _HealthStatusCard(status: controller.status!),
          ],
        ],
      ),
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
    return Card(
      child: ListTile(
        title: Text('Alert Level: $level'),
        subtitle: Text(
          status.resolved
              ? 'Resolved'
              : status.monitoringActive
                  ? 'Monitoring active'
                  : 'Monitoring inactive',
        ),
      ),
    );
  }
}
