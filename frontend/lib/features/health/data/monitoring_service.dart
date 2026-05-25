import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../apple_native/apple_native_bridge.dart';
import '../../../apple_native/apple_native_models.dart';
import '../../shared/data/mediguard_api_service.dart';
import '../../shared/models/api_models.dart';

/// Manages the post-medication health monitoring loop.
///
/// Flow:
///  1. User confirms intake → [startMonitoring] called with log_id + window
///  2. Immediately reads HealthKit snapshot (Apple Watch data via HealthKit sync)
///  3. Runs Core ML anomaly prediction on each snapshot
///  4. Every [pollInterval], repeats steps 2–3
///  5. Auto-reports anomalies to backend (max 1 per 10 min to avoid spam)
///  6. Auto-sends iMessage to emergency contacts on anomaly detection
///  7. On critical anomaly, auto-dials first emergency contact
///  8. Stops automatically when monitoring window expires
class MonitoringService extends ChangeNotifier {
  MonitoringService(this._bridge, this._api);

  final AppleNativeBridge _bridge;
  final MediGuardApiService _api;

  static const pollInterval = Duration(seconds: 10);

  /// Minimum gap between auto-emergency alerts (to avoid spam)
  static const _alertCooldown = Duration(minutes: 30);

  // ── State ──────────────────────────────────────────────────────────────────
  bool isMonitoring = false;
  String? activeLogId;
  String? activeMedicationName;

  HealthSnapshot? latestSnapshot;
  int anomalyLevel = 0;    // 0=normal 1=warning 2=critical
  double confidence = 0;
  String? anomalyType;
  bool isWatchSource = false;

  String? error;

  /// Seconds remaining in monitoring window
  int remainingSeconds = 0;

  /// Seconds until next HealthKit read
  int nextReadSeconds = 0;

  DateTime? _monitoringEnd;
  DateTime? _nextTickAt;
  DateTime? _lastReportedAt;
  DateTime? _lastAlertedAt;

  Timer? _pollTimer;
  Timer? _uiTimer;

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<void> startMonitoring({
    required String logId,
    required DateTime start,
    required DateTime end,
    String? medicationName,
  }) async {
    error = null;
    try {
      await _bridge.requestHealthPermissions();

      await _bridge.startMonitoring(
        logId: logId,
        start: start,
        end: end,
        medicationName: medicationName,
      );

      activeLogId = logId;
      activeMedicationName = medicationName;
      _monitoringEnd = end;
      isMonitoring = true;
      anomalyLevel = 0;
      latestSnapshot = null;
      _lastReportedAt = null;
      _lastAlertedAt = null;

      _updateCountdowns();

      _uiTimer?.cancel();
      _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _updateCountdowns();
        if (remainingSeconds <= 0) _onWindowExpired();
        notifyListeners();
      });

      _scheduleNextPoll();

      notifyListeners();

      // Immediate first read (don't await — let UI show fast)
      _tick();
    } catch (e) {
      error = e.toString();
      isMonitoring = false;
      notifyListeners();
    }
  }

  Future<void> stopMonitoring() async {
    _cancelTimers();
    try { await _bridge.stopMonitoring(); } catch (_) {}
    isMonitoring = false;
    activeLogId = null;
    activeMedicationName = null;
    _monitoringEnd = null;
    remainingSeconds = 0;
    nextReadSeconds = 0;
    anomalyLevel = 0;
    notifyListeners();
  }

  /// Reads a fresh snapshot regardless of whether monitoring is active.
  Future<void> manualRefresh() async {
    if (isMonitoring) {
      await _tick();
      return;
    }
    // Passive read — request permissions (no-op if already granted), then fetch.
    try {
      await _bridge.requestHealthPermissions();
      final snapshot = await _bridge.latestSnapshot();
      if (snapshot != null) {
        latestSnapshot = snapshot;
        isWatchSource = snapshot.sourceDeviceName?.toLowerCase().contains('watch') == true
            || snapshot.source.toLowerCase().contains('watch');
        notifyListeners();
      }
    } catch (_) {}
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    _nextTickAt = DateTime.now().add(pollInterval);
    _pollTimer = Timer(pollInterval, () async {
      await _tick();
      if (isMonitoring) _scheduleNextPoll();
    });
  }

  Future<void> _tick() async {
    if (!isMonitoring || activeLogId == null) return;
    if (_monitoringEnd != null && DateTime.now().isAfter(_monitoringEnd!)) {
      _onWindowExpired();
      return;
    }

    try {
      final snapshot = await _bridge.latestSnapshot();
      if (snapshot != null) {
        latestSnapshot = snapshot;
        isWatchSource = snapshot.sourceDeviceName?.toLowerCase().contains('watch') == true
            || snapshot.source.toLowerCase().contains('watch');
      }

      if (snapshot != null) {
        final result = await _bridge.predictAnomaly(
          medicationLogId: activeLogId!,
          snapshot: snapshot,
        );
        final p = result.prediction;
        anomalyLevel = (p['anomaly_level'] as num?)?.toInt() ?? 0;
        confidence = (p['confidence'] as num?)?.toDouble() ?? 0;
        anomalyType = p['anomaly_type'] as String?;

        if (anomalyLevel > 0 && confidence >= 0.6 && _canReport()) {
          _lastReportedAt = DateTime.now();
          await _api.reportAnomaly(AnomalyReport(
            medicationLogId: activeLogId!,
            anomalyLevel: _levelEnum(anomalyLevel),
            anomalyType: _typeEnum(anomalyType),
            coreMlConfidence: confidence,
            timestamp: DateTime.now().toUtc(),
          ));
        }

        if (anomalyLevel > 0 && confidence >= 0.6 && _canAlert()) {
          _lastAlertedAt = DateTime.now();
          await _sendAutoEmergencyAlert(anomalyLevel, anomalyType);
        }
      }
    } catch (e) {
      debugPrint('MonitoringService._tick error: $e');
    }
    notifyListeners();
  }

  bool _canReport() {
    if (_lastReportedAt == null) return true;
    return DateTime.now().difference(_lastReportedAt!).inMinutes >= 10;
  }

  bool _canAlert() {
    if (_lastAlertedAt == null) return true;
    return DateTime.now().difference(_lastAlertedAt!) >= _alertCooldown;
  }

  Future<void> _sendAutoEmergencyAlert(int level, String? type) async {
    try {
      final contacts = await _api.fetchEmergencyContacts();
      if (contacts.isEmpty) return;

      final typeLabel = switch (type) {
        'high_hr'       => 'elevated heart rate (${latestSnapshot?.heartRate?.round()} BPM)',
        'low_spo2'      => 'low blood oxygen (${latestSnapshot?.spo2?.round()}%)',
        'irregular_hrv' => 'irregular heart rate variability',
        'combined'      => 'multiple abnormal vital signs',
        _               => 'abnormal vital signs',
      };
      final severity = level >= 2 ? '🚨 CRITICAL' : '⚠️ WARNING';
      final medPart = activeMedicationName != null
          ? ' after taking $activeMedicationName'
          : '';
      final message =
          '$severity [MediGuard] Anomaly detected$medPart: $typeLabel. '
          'Please check on them immediately!';

      await _bridge.sendIMessage(
        contacts: contacts.map((c) => {'phone': c.phone}).toList(),
        message: message,
      );

      if (level >= 2) {
        await _bridge.emergencyCall(number: contacts.first.phone);
      }

      debugPrint('MonitoringService: auto-alerted ${contacts.length} contact(s) — level=$level');
    } catch (e) {
      debugPrint('MonitoringService._sendAutoEmergencyAlert error: $e');
    }
  }

  void _updateCountdowns() {
    if (_monitoringEnd == null) {
      remainingSeconds = 0;
    } else {
      final diff = _monitoringEnd!.difference(DateTime.now());
      remainingSeconds = diff.isNegative ? 0 : diff.inSeconds;
    }
    if (_nextTickAt == null) {
      nextReadSeconds = 0;
    } else {
      final diff = _nextTickAt!.difference(DateTime.now());
      nextReadSeconds = diff.isNegative ? 0 : diff.inSeconds;
    }
  }

  void _onWindowExpired() {
    _cancelTimers();
    isMonitoring = false;
    remainingSeconds = 0;
    notifyListeners();
  }

  void _cancelTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _uiTimer?.cancel();
    _uiTimer = null;
  }

  // ── Enum helpers ─────────────────────────────────────────────────────────────

  static AnomalyLevel _levelEnum(int level) => switch (level) {
    1 => AnomalyLevel.medium,
    2 => AnomalyLevel.high,
    _ => AnomalyLevel.low,
  };

  static AnomalyType _typeEnum(String? type) => switch (type) {
    'high_hr'       => AnomalyType.highHr,
    'low_spo2'      => AnomalyType.lowSpo2,
    'irregular_hrv' => AnomalyType.irregularHrv,
    _               => AnomalyType.combined,
  };

  // ── Formatting helpers (used by UI) ──────────────────────────────────────────

  static String formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}
