import 'dart:convert';

/// Matches backend APNs custom fields in `notification_service.send_medication_reminder_push`.
class MedicationReminderPayload {
  const MedicationReminderPayload({
    required this.action,
    required this.scheduleId,
    required this.scheduledTime,
    this.medicationName,
    this.dosage,
    this.logId,
    this.mirrorToWatch = true,
  });

  final String action;
  final String scheduleId;
  final String scheduledTime;
  final String? medicationName;
  final String? dosage;
  final String? logId;
  final bool mirrorToWatch;

  factory MedicationReminderPayload.reminder({
    required String scheduleId,
    required String scheduledTime,
    String? medicationName,
    String? dosage,
  }) {
    return MedicationReminderPayload(
      action: 'medication_reminder',
      scheduleId: scheduleId,
      scheduledTime: scheduledTime,
      medicationName: medicationName,
      dosage: dosage,
    );
  }

  factory MedicationReminderPayload.monitoringActive({
    required String logId,
    required String scheduleId,
    required String scheduledTime,
  }) {
    return MedicationReminderPayload(
      action: 'monitoring_active',
      scheduleId: scheduleId,
      scheduledTime: scheduledTime,
      logId: logId,
    );
  }

  Map<String, dynamic> toJson() => {
        'action': action,
        'schedule_id': scheduleId,
        'scheduled_time': scheduledTime,
        if (medicationName != null) 'medication_name': medicationName,
        if (dosage != null) 'dosage': dosage,
        if (logId != null) 'log_id': logId,
        'mirror_to_watch': mirrorToWatch,
      };

  String encode() => jsonEncode(toJson());
}
