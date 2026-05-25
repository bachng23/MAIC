import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../apple_native/apple_native_bridge.dart';
import '../../../core/notifications/medication_notification_service.dart';
import '../../health/data/monitoring_service.dart';
import '../../shared/data/mediguard_api_service.dart';
import '../../shared/models/api_models.dart';
import 'medication_intake_controller.dart';
import 'prescription_parser.dart';

class ScanController extends ChangeNotifier {
  ScanController(this._api, this._notifications, this._intake, this._monitoring);

  final MediGuardApiService _api;
  final MedicationNotificationService _notifications;
  final MedicationIntakeController _intake;
  final MonitoringService _monitoring;
  final _bridge = AppleNativeBridge();

  bool isLoading = false;
  String? error;

  /// All medications detected from the last scan (may contain multiple).
  List<OCRScanResult> scanResults = [];

  /// Convenience: first result (backwards compat with single-med review flow).
  OCRScanResult? get scanResult => scanResults.isNotEmpty ? scanResults.first : null;

  DrugInfo? drugInfo;
  MedicationOut? createdMedication;
  String? _pendingSourceImageUrl;

  void clearForNewEntry() {
    scanResults = [];
    drugInfo = null;
    createdMedication = null;
    error = null;
    _pendingSourceImageUrl = null;
    notifyListeners();
  }

  /// OCR flow — fully on-device, no external vision model:
  ///   1. Apple Vision (iOS 17+) extracts raw text from the image.
  ///   2. [parsePrescriptionText] parses the raw text into medication entries.
  ///   3. Drug info is fetched from the backend for the first detected medication.
  ///   If Vision is unavailable (iOS < 17 / simulator), opens the entry sheet
  ///   with empty fields so the user can type manually.
  Future<void> runOcrFromImage(File imageFile) async {
    isLoading = true;
    error = null;
    scanResults = [];
    drugInfo = null;
    createdMedication = null;
    _pendingSourceImageUrl = null;
    notifyListeners();
    try {
      // ── Step 1: on-device Apple Vision text extraction ──────────────────
      String rawText;
      try {
        final ocrResult = await _bridge.recognizeTextFromFile(imageFile.path);
        rawText = ocrResult.rawText.trim();
      } on MissingPluginException {
        // iOS < 17 or simulator — open entry sheet with empty fields
        rawText = '';
      } on PlatformException {
        rawText = '';
      } catch (_) {
        rawText = '';
      }

      // ── Step 2: local parse ─────────────────────────────────────────────
      if (rawText.isEmpty) {
        // No text extracted — return one empty result so entry sheet opens
        scanResults = [OCRScanResult(name: '')];
        return;
      }

      final results = parsePrescriptionText(rawText);
      if (results.isEmpty) {
        error = 'No medications detected. Try a clearer photo or enter manually.';
        return;
      }
      scanResults = results;

      // ── Step 3: fetch drug info for the first medication ────────────────
      try {
        drugInfo = await _api.fetchDrugInfo(
          DrugInfoRequest(drugName: results.first.name, drugNameZh: results.first.nameZh),
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
    List<int>? daysOfWeek,
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
        ScheduleCreate(
          medicationId: med.id,
          times: times,
          daysOfWeek: daysOfWeek,
        ),
      );

      await _notifications.requestPermissions();
      await _notifications.syncSchedule(
        schedule: schedule,
        medicationName: med.name,
        dosage: med.dosage,
      );

      _pendingSourceImageUrl = null;
      scanResults = [];
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
    String? medicationName,
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
      // Confirm intake first — notification scheduling must NOT block this.
      _intake.confirmIntake(scheduleId: scheduleId, medicationId: medicationId);
      final now = DateTime.now();
      // Start HealthKit monitoring window; fire-and-forget, don't block intake confirm.
      _monitoring.startMonitoring(
        logId: response.logId,
        start: now,
        end: response.monitoringEnd,
        medicationName: medicationName,
      ).catchError((_) {});
      // Schedule monitoring reminder in background; ignore notification errors.
      _notifications.scheduleMonitoringReminder(
        logId: response.logId,
        scheduleId: scheduleId,
        scheduledTime: now.toUtc().toIso8601String(),
        monitoringEnd: response.monitoringEnd,
      ).catchError((_) {}); // fire-and-forget
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
