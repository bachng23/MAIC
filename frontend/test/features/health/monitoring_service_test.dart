import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/apple_native/apple_native_bridge.dart';
import 'package:frontend/apple_native/apple_native_models.dart';
import 'package:frontend/features/health/data/monitoring_service.dart';
import 'package:frontend/features/shared/data/mediguard_api_service.dart';
import 'package:frontend/features/shared/models/api_models.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockAppleNativeBridge extends Mock implements AppleNativeBridge {}

class MockMediGuardApiService extends Mock implements MediGuardApiService {}

// ── Helpers ──────────────────────────────────────────────────────────────────

HealthSnapshot _fakeSnapshot({String? sourceDeviceName}) => HealthSnapshot(
      heartRate: 72,
      hrv: 45,
      spo2: 98,
      timestamp: DateTime.now(),
      sampleTimestamp: DateTime.now(),
      activityState: 'active',
      source: 'HealthKit',
      sourceDeviceName: sourceDeviceName,
      sourceDeviceModel: null,
      sourceAppName: null,
    );

PredictAnomalyResponse _fakeAnomalyPrediction() => PredictAnomalyResponse(
      prediction: <Object?, Object?>{
        'anomaly_level': 1,
        'confidence': 0.85,
        'anomaly_type': 'high_hr',
      },
      backendReport: null,
    );

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late MockAppleNativeBridge bridge;
  late MockMediGuardApiService api;

  setUpAll(() {
    // Register fallback values required by mocktail for any() matchers.
    registerFallbackValue(_fakeSnapshot());
    registerFallbackValue(AnomalyReport(
      medicationLogId: 'fallback',
      anomalyLevel: AnomalyLevel.low,
      anomalyType: AnomalyType.combined,
      coreMlConfidence: 0,
      timestamp: DateTime.now(),
    ));
  });

  setUp(() {
    bridge = MockAppleNativeBridge();
    api = MockMediGuardApiService();
  });

  // ── formatDuration ─────────────────────────────────────────────────────────

  group('MonitoringService.formatDuration', () {
    test('formats seconds only', () {
      expect(MonitoringService.formatDuration(45), '45s');
    });

    test('formats minutes and seconds', () {
      expect(MonitoringService.formatDuration(125), '2m 05s');
    });

    test('formats hours and minutes', () {
      expect(MonitoringService.formatDuration(3661), '1h 01m');
    });

    test('formats zero', () {
      expect(MonitoringService.formatDuration(0), '0s');
    });
  });

  // ── stopMonitoring ─────────────────────────────────────────────────────────

  group('stopMonitoring', () {
    test('clears active state without prior startMonitoring', () async {
      when(() => bridge.stopMonitoring())
          .thenAnswer((_) async => <Object?, Object?>{});

      final svc = MonitoringService(bridge, api);
      // Directly set state as if monitoring had started.
      svc.isMonitoring = true;
      svc.activeLogId = 'log-123';

      await svc.stopMonitoring();

      expect(svc.isMonitoring, isFalse);
      expect(svc.activeLogId, isNull);
    });

    test('stopMonitoring swallows bridge errors gracefully', () async {
      when(() => bridge.stopMonitoring()).thenThrow(Exception('channel error'));

      final svc = MonitoringService(bridge, api);
      svc.isMonitoring = true;
      svc.activeLogId = 'log-abc';

      // Should not throw.
      await expectLater(svc.stopMonitoring(), completes);
      expect(svc.isMonitoring, isFalse);
      expect(svc.activeLogId, isNull);
    });
  });

  // ── manualRefresh ──────────────────────────────────────────────────────────

  group('manualRefresh', () {
    test('updates latestSnapshot when bridge returns a snapshot', () async {
      final snapshot = _fakeSnapshot(sourceDeviceName: 'iPhone');
      when(() => bridge.requestHealthPermissions()).thenAnswer((_) async =>
          HealthPermissionResponse(granted: true, requestedAt: DateTime.now()));
      when(() => bridge.latestSnapshot()).thenAnswer((_) async => snapshot);

      final svc = MonitoringService(bridge, api);
      await svc.manualRefresh();

      expect(svc.latestSnapshot, isNotNull);
      expect(svc.latestSnapshot!.heartRate, 72);
    });

    test('sets isWatchSource true when sourceDeviceName contains watch', () async {
      final snapshot = _fakeSnapshot(sourceDeviceName: 'Apple Watch Series 9');
      when(() => bridge.requestHealthPermissions()).thenAnswer((_) async =>
          HealthPermissionResponse(granted: true, requestedAt: DateTime.now()));
      when(() => bridge.latestSnapshot()).thenAnswer((_) async => snapshot);

      final svc = MonitoringService(bridge, api);
      await svc.manualRefresh();

      expect(svc.isWatchSource, isTrue);
    });

    test('sets isWatchSource false when sourceDeviceName is iPhone', () async {
      final snapshot = _fakeSnapshot(sourceDeviceName: 'iPhone 15 Pro');
      when(() => bridge.requestHealthPermissions()).thenAnswer((_) async =>
          HealthPermissionResponse(granted: true, requestedAt: DateTime.now()));
      when(() => bridge.latestSnapshot()).thenAnswer((_) async => snapshot);

      final svc = MonitoringService(bridge, api);
      await svc.manualRefresh();

      expect(svc.isWatchSource, isFalse);
    });

    test('does not crash when bridge returns null snapshot', () async {
      when(() => bridge.requestHealthPermissions()).thenAnswer((_) async =>
          HealthPermissionResponse(granted: true, requestedAt: DateTime.now()));
      when(() => bridge.latestSnapshot()).thenAnswer((_) async => null);

      final svc = MonitoringService(bridge, api);
      await expectLater(svc.manualRefresh(), completes);
      expect(svc.latestSnapshot, isNull);
    });

    test('does not crash when bridge throws', () async {
      when(() => bridge.requestHealthPermissions()).thenAnswer((_) async =>
          HealthPermissionResponse(granted: true, requestedAt: DateTime.now()));
      when(() => bridge.latestSnapshot()).thenThrow(Exception('no data'));

      final svc = MonitoringService(bridge, api);
      await expectLater(svc.manualRefresh(), completes);
    });
  });

  // ── report cooldown (tested via observable state) ──────────────────────────

  group('report cooldown', () {
    test('reportAnomaly is called exactly once on first anomaly tick', () async {
      final snapshot = _fakeSnapshot();
      final anomalyPrediction = _fakeAnomalyPrediction();

      when(() => bridge.requestHealthPermissions()).thenAnswer((_) async =>
          HealthPermissionResponse(granted: true, requestedAt: DateTime.now()));
      when(() => bridge.startMonitoring(
            logId: any(named: 'logId'),
            start: any(named: 'start'),
            end: any(named: 'end'),
            medicationName: any(named: 'medicationName'),
          )).thenAnswer((_) async =>
          MonitoringSessionResponse(session: null));
      when(() => bridge.latestSnapshot()).thenAnswer((_) async => snapshot);
      when(() => bridge.predictAnomaly(
            medicationLogId: any(named: 'medicationLogId'),
            snapshot: any(named: 'snapshot'),
          )).thenAnswer((_) async => anomalyPrediction);
      when(() => bridge.stopMonitoring())
          .thenAnswer((_) async => <Object?, Object?>{});
      when(() => api.reportAnomaly(any())).thenAnswer((_) async {});
      when(() => api.fetchEmergencyContacts()).thenAnswer((_) async => []);

      final svc = MonitoringService(bridge, api);
      final now = DateTime.now();
      await svc.startMonitoring(
        logId: 'log-1',
        start: now,
        end: now.add(const Duration(hours: 2)),
      );

      // Allow the immediate _tick() to run.
      await Future<void>.delayed(Duration.zero);
      await svc.stopMonitoring();

      verify(() => api.reportAnomaly(any())).called(1);
    });
  });

  // ── alert cooldown ─────────────────────────────────────────────────────────

  group('alert cooldown', () {
    test('emergency contacts fetched on first anomaly', () async {
      final snapshot = _fakeSnapshot();
      final anomalyPrediction = _fakeAnomalyPrediction();

      when(() => bridge.requestHealthPermissions()).thenAnswer((_) async =>
          HealthPermissionResponse(granted: true, requestedAt: DateTime.now()));
      when(() => bridge.startMonitoring(
            logId: any(named: 'logId'),
            start: any(named: 'start'),
            end: any(named: 'end'),
            medicationName: any(named: 'medicationName'),
          )).thenAnswer((_) async =>
          MonitoringSessionResponse(session: null));
      when(() => bridge.latestSnapshot()).thenAnswer((_) async => snapshot);
      when(() => bridge.predictAnomaly(
            medicationLogId: any(named: 'medicationLogId'),
            snapshot: any(named: 'snapshot'),
          )).thenAnswer((_) async => anomalyPrediction);
      when(() => bridge.stopMonitoring())
          .thenAnswer((_) async => <Object?, Object?>{});
      when(() => api.reportAnomaly(any())).thenAnswer((_) async {});
      // Return empty so sendIMessage is not called (avoids registering more fallbacks).
      when(() => api.fetchEmergencyContacts()).thenAnswer((_) async => []);

      final svc = MonitoringService(bridge, api);
      final now = DateTime.now();
      await svc.startMonitoring(
        logId: 'log-2',
        start: now,
        end: now.add(const Duration(hours: 2)),
      );
      await Future<void>.delayed(Duration.zero);
      await svc.stopMonitoring();

      verify(() => api.fetchEmergencyContacts()).called(1);
    });
  });
}
