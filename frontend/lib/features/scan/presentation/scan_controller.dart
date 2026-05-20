import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../apple_native/apple_native_bridge.dart';
import '../../../core/notifications/medication_notification_service.dart';
import '../../shared/data/mediguard_api_service.dart';
import '../../shared/models/api_models.dart';
import 'medication_intake_controller.dart';

class ScanController extends ChangeNotifier {
  ScanController(this._api, this._notifications, this._intake);

  final MediGuardApiService _api;
  final MedicationNotificationService _notifications;
  final MedicationIntakeController _intake;
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

  /// OCR flow:
  ///   1. Try on-device Apple Vision OCR (iOS 17+) → fast, free, no server round-trip for extraction.
  ///   2. If Vision fails / not available, fall back to sending base64 image to backend vision model.
  ///   Either way, the raw text or image is sent to `POST /api/v1/medications/scan` which returns
  ///   a list of [OCRScanResult] (one per medication detected on the prescription).
  Future<void> runOcrFromImage(File imageFile) async {
    isLoading = true;
    error = null;
    scanResults = [];
    drugInfo = null;
    createdMedication = null;
    _pendingSourceImageUrl = null;
    notifyListeners();
    try {
      // Always encode the image — needed as fallback for older backend versions
      // and as the vision-model input when on-device OCR is unavailable.
      final bytes = await imageFile.readAsBytes();
      final imageBase64 = base64Encode(bytes);

      // ── Step 1: try on-device Apple Vision text extraction ──────────────
      // If successful, include ocr_text alongside image_base64 so the new
      // backend can use the faster text-only path while the old backend
      // (which ignores unknown fields) falls back to image_base64.
      OCRScanRequest request;
      try {
        final ocrResult = await _bridge.recognizeTextFromFile(imageFile.path);
        if (ocrResult.rawText.trim().isNotEmpty) {
          request = OCRScanRequest(imageBase64: imageBase64, ocrText: ocrResult.rawText);
        } else {
          throw const FormatException('Vision returned empty text');
        }
      } on MissingPluginException {
        request = OCRScanRequest(imageBase64: imageBase64);
      } on PlatformException {
        request = OCRScanRequest(imageBase64: imageBase64);
      } catch (_) {
        request = OCRScanRequest(imageBase64: imageBase64);
      }

      // ── Step 2: parse via backend (vision or text-only model) ───────────
      final results = await _api.scanMedication(request);
      if (results.isEmpty) {
        error = 'No medications detected. Try a clearer photo.';
        return;
      }
      scanResults = results;
      _pendingSourceImageUrl = results.first.sourceImageUrl;

      // Fetch drug info for the first (primary) medication only.
      final first = results.first;
      try {
        drugInfo = await _api.fetchDrugInfo(
          DrugInfoRequest(drugName: first.name, drugNameZh: first.nameZh),
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
      // Schedule monitoring reminder in background; ignore notification errors.
      _notifications.scheduleMonitoringReminder(
        logId: response.logId,
        scheduleId: scheduleId,
        scheduledTime: DateTime.now().toUtc().toIso8601String(),
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
