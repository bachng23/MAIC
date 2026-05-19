import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/providers.dart';

/// Keeps local medication reminders aligned with dashboard schedules.
class NotificationSyncListener extends ConsumerWidget {
  const NotificationSyncListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(dashboardControllerProvider, (previous, next) {
      next.whenData((data) async {
        await ref.read(medicationNotificationServiceProvider).syncAllReminders(
              medications: data.medications,
              schedules: data.schedules,
            );
      });
    });
    return child;
  }
}
