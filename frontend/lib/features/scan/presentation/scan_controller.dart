import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/notifications/medication_notification_service.dart';
import '../../shared/data/mediguard_api_service.dart';
import '../../shared/models/api_models.dart';
import 'medication_intake_controller.dart';

class ScanController extends ChangeNotifier {
  ScanController(this._api, this._notifications, this._intake);

  final MediGuardApiService _api;
  final MedicationNotificationService _notifications;
  final MedicationIntakeController _intake;

  bool isLoading = false;
  String? error;
  OCRScanResult? scanResult;
  DrugInfo? drugInfo;
  MedicationOut? createdMedication;
  String? _pendingSourceImageUrl;

  void clearForNewEntry() {
    scanResult = null;
    drugInfo = null;
    createdMedication = null;
    error = null;
    _pendingSourceImageUrl = null;
    notifyListeners();
  }

  /// OCR only — image is sent as base64 JSON to `POST /api/v1/medications/scan` (backend uploads to storage).
  Future<void> runOcrFromImage(File imageFile) async {
    isLoading = true;
    error = null;
    scanResult = null;
    drugInfo = null;
    createdMedication = null;
    _pendingSourceImageUrl = null;
    notifyListeners();
    try {
      final bytes = await imageFile.readAsBytes();
      final imageBase64 = base64Encode(bytes);
      final scanned = await _api.scanMedication(OCRScanRequest(imageBase64: imageBase64));
      scanResult = scanned;
      _pendingSourceImageUrl = scanned.sourceImageUrl;

      try {
        drugInfo = await _api.fetchDrugInfo(
          DrugInfoRequest(drugName: scanned.name, drugNameZh: scanned.nameZh),
        );
      } catch (_) {
        drugInfo = null;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveMedicationWithSchedule({
    required String name,
    String? nameZh,
    String? dosage,
    String? notes,
    required List<String> times,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      error = 'Medicine name is required.';
      notifyListeners();
      return;
    }
    if (times.isEmpty) {
      error = 'Add at least one scheduled time.';
      notifyListeners();
      return;
    }
    for (final t in times) {
      if (!_isValidHm(t)) {
        error = 'Invalid time "$t". Use HH:mm (24-hour).';
        notifyListeners();
        return;
      }
    }

    isLoading = true;
    error = null;
    notifyListeners();
    try {
      var resolvedDrug = drugInfo;
      if (resolvedDrug == null) {
        try {
          resolvedDrug = await _api.fetchDrugInfo(
            DrugInfoRequest(
              drugName: trimmedName,
              drugNameZh: _nullableTrim(nameZh),
            ),
          );
        } catch (_) {
          resolvedDrug = null;
        }
      }

      final med = await _api.createMedication(
        MedicationCreate(
          name: trimmedName,
          nameZh: _nullableTrim(nameZh),
          dosage: _nullableTrim(dosage),
          notes: _nullableTrim(notes),
          sourceImageUrl: _pendingSourceImageUrl,
          drugInfo: resolvedDrug,
        ),
      );

      final schedule = await _api.createSchedule(
        ScheduleCreate(medicationId: med.id, times: times),
      );

      await _notifications.requestPermissions();
      await _notifications.syncSchedule(
        schedule: schedule,
        medicationName: med.name,
        dosage: med.dosage,
      );

      _pendingSourceImageUrl = null;
      scanResult = null;
      drugInfo = null;
      createdMedication = null;
    } catch (e) {
      error = e.toString();
      createdMedication = null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  static String? _nullableTrim(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  static bool _isValidHm(String s) {
    final parts = s.split(':');
    if (parts.length != 2) return false;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return false;
    if (h < 0 || h > 23 || m < 0 || m > 59) return false;
    if (parts[0].length != 2 || parts[1].length != 2) return false;
    return true;
  }

  Future<bool> logDoseTaken({
    required String scheduleId,
    required String medicationId,
  }) async {
    if (scheduleId.isEmpty) {
      error = 'Missing schedule.';
      notifyListeners();
      return false;
    }
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final response = await _api.logMedicationTaken(MedicationTakenRequest(scheduleId: scheduleId));
      await _notifications.scheduleMonitoringReminder(
        logId: response.logId,
        scheduleId: scheduleId,
        scheduledTime: DateTime.now().toUtc().toIso8601String(),
        monitoringEnd: response.monitoringEnd,
      );
      _intake.confirmIntake(scheduleId: scheduleId, medicationId: medicationId);
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
