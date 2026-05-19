import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/shared/models/api_models.dart';
import 'medication_reminder_payload.dart';

/// Schedules local medication reminders with payloads aligned to backend APNs pushes.
class MedicationNotificationService {
  MedicationNotificationService();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'medication_reminders';
  static const _channelName = 'Medication Reminders';
  static const _channelDescription =
      'Dose reminders that mirror to Apple Watch when iPhone mirroring is enabled.';

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: initSettings);

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    }
    return true;
  }

  Future<void> cancelAllMedicationReminders() async {
    await initialize();
    await _plugin.cancelAll();
  }

  Future<void> syncAllReminders({
    required List<MedicationOut> medications,
    required List<ScheduleOut> schedules,
  }) async {
    await initialize();
    await requestPermissions();
    await cancelAllMedicationReminders();

    final medById = {for (final m in medications) m.id: m};
    for (final schedule in schedules.where((s) => s.isActive)) {
      final med = medById[schedule.medicationId];
      if (med == null) continue;
      await syncSchedule(
        schedule: schedule,
        medicationName: med.name,
        dosage: med.dosage,
      );
    }
  }

  Future<void> syncSchedule({
    required ScheduleOut schedule,
    required String medicationName,
    String? dosage,
  }) async {
    await initialize();
    for (final time in schedule.times) {
      final days = schedule.daysOfWeek;
      if (days == null || days.isEmpty) {
        await _scheduleRepeating(
          notificationId: _notificationId(schedule.id, time),
          medicationName: medicationName,
          dosage: dosage,
          scheduleId: schedule.id,
          scheduledTime: time,
          dayOfWeek: null,
        );
      } else {
        for (final day in days) {
          await _scheduleRepeating(
            notificationId: _notificationId(schedule.id, time, dayOfWeek: day),
            medicationName: medicationName,
            dosage: dosage,
            scheduleId: schedule.id,
            scheduledTime: time,
            dayOfWeek: day,
          );
        }
      }
    }
  }

  Future<void> scheduleOneOffReminder({
    required String scheduleId,
    required String medicationName,
    String? dosage,
    required String scheduledTime,
    Duration delay = const Duration(minutes: 1),
  }) async {
    await initialize();
    await requestPermissions();

    final fireAt = tz.TZDateTime.now(tz.local).add(delay);
    final body = _reminderBody(medicationName, dosage);
    final payload = MedicationReminderPayload.reminder(
      scheduleId: scheduleId,
      scheduledTime: scheduledTime,
      medicationName: medicationName,
      dosage: dosage,
    );

    await _plugin.zonedSchedule(
      id: _notificationId(scheduleId, scheduledTime, suffix: 'snooze'),
      scheduledDate: fireAt,
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      title: 'Medication Reminder',
      body: "It's time to take $body.",
      payload: payload.encode(),
    );
  }

  Future<void> scheduleMonitoringReminder({
    required String logId,
    required String scheduleId,
    required String scheduledTime,
    required DateTime monitoringEnd,
  }) async {
    await initialize();
    if (!monitoringEnd.isAfter(DateTime.now())) return;

    final fireAt = tz.TZDateTime.from(monitoringEnd.toUtc(), tz.local);
    final payload = MedicationReminderPayload.monitoringActive(
      logId: logId,
      scheduleId: scheduleId,
      scheduledTime: scheduledTime,
    );

    await _plugin.zonedSchedule(
      id: _notificationId(logId, 'monitoring_end'),
      scheduledDate: fireAt,
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      title: 'Monitoring Complete',
      body: 'Post-medication monitoring window has ended.',
      payload: payload.encode(),
    );
  }

  Future<void> _scheduleRepeating({
    required int notificationId,
    required String medicationName,
    String? dosage,
    required String scheduleId,
    required String scheduledTime,
    required int? dayOfWeek,
  }) async {
    final parts = scheduledTime.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    var scheduledDate = _nextInstance(hour, minute, dayOfWeek);
    if (!scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final body = _reminderBody(medicationName, dosage);
    final payload = MedicationReminderPayload.reminder(
      scheduleId: scheduleId,
      scheduledTime: scheduledTime,
      medicationName: medicationName,
      dosage: dosage,
    );

    await _plugin.zonedSchedule(
      id: notificationId,
      scheduledDate: scheduledDate,
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      title: 'Medication Reminder',
      body: "It's time to take $body.",
      payload: payload.encode(),
      matchDateTimeComponents: dayOfWeek == null
          ? DateTimeComponents.time
          : DateTimeComponents.dayOfWeekAndTime,
    );
  }

  tz.TZDateTime _nextInstance(int hour, int minute, int? dayOfWeek) {
    final now = tz.TZDateTime.now(tz.local);
    if (dayOfWeek == null) {
      return tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    }
    var candidate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (candidate.weekday != dayOfWeek) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
        threadIdentifier: 'medication_reminders',
      ),
    );
  }

  String _reminderBody(String medicationName, String? dosage) {
    return dosage == null || dosage.isEmpty ? medicationName : '$medicationName ($dosage)';
  }

  int _notificationId(String a, String b, {int? dayOfWeek, String suffix = ''}) {
    return '$a|$b|${dayOfWeek ?? 'daily'}|$suffix'.hashCode & 0x7fffffff;
  }
}
