import 'package:flutter/services.dart';

import 'apple_native_models.dart';

class AppleNativeBridge {
  AppleNativeBridge();

  static const MethodChannel _ocrChannel = MethodChannel(
    'com.mediguard/vision_ocr',
  );
  static const MethodChannel _healthChannel = MethodChannel(
    'com.mediguard/health_monitor',
  );
  static const MethodChannel _coreMlChannel = MethodChannel(
    'com.mediguard/core_ml',
  );
  static const MethodChannel _emergencyChannel = MethodChannel(
    'com.mediguard/emergency',
  );

  Future<OcrResult> recognizeTextFromFile(String imagePath) async {
    final json = await _invokeMap(
      _ocrChannel,
      'recognizeTextFromFile',
      {'image_path': imagePath},
    );
    return OcrResult.fromJson(json);
  }

  Future<String> pickImageFromLibrary() async {
    final json = await _invokeMap(
      _ocrChannel,
      'pickImageFromLibrary',
    );
    return (json['image_path'] as String?) ?? '';
  }

  Future<HealthPermissionResponse> requestHealthPermissions() async {
    final json = await _invokeMap(
      _healthChannel,
      'requestHealthPermissions',
    );
    return HealthPermissionResponse.fromJson(json);
  }

  Future<MonitoringSessionResponse> startMonitoring({
    required String logId,
    required DateTime start,
    required DateTime end,
    String? medicationName,
    String? medicationCategory,
  }) async {
    final json = await _invokeMap(
      _healthChannel,
      'startMonitoring',
      {
        'log_id': logId,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'medication_name': medicationName,
        'medication_category': medicationCategory,
      },
    );
    return MonitoringSessionResponse.fromJson(json);
  }

  Future<Map<Object?, Object?>> stopMonitoring() {
    return _invokeMap(_healthChannel, 'stopMonitoring');
  }

  Future<HealthSnapshot?> latestSnapshot() async {
    final json = await _invokeMap(_healthChannel, 'getLatestHealthSnapshot');
    final snapshotJson = json['snapshot'] as Map<Object?, Object?>?;
    if (snapshotJson == null) return null;
    return HealthSnapshot.fromJson(snapshotJson);
  }

  Future<MonitoringSessionResponse> currentMonitoringSession() async {
    final json = await _invokeMap(
      _healthChannel,
      'getCurrentMonitoringSession',
    );
    return MonitoringSessionResponse.fromJson(json);
  }

  Future<BaselineResponse> currentBaseline() async {
    final json = await _invokeMap(_healthChannel, 'getCurrentBaseline');
    return BaselineResponse.fromJson(json);
  }

  Future<ModelStatusResponse> loadModelStatus() async {
    final json = await _invokeMap(_coreMlChannel, 'loadModelStatus');
    return ModelStatusResponse.fromJson(json);
  }

  Future<PredictAnomalyResponse> predictAnomaly({
    required String medicationLogId,
    required HealthSnapshot snapshot,
  }) async {
    final json = await _invokeMap(
      _coreMlChannel,
      'predictAnomaly',
      {
        'medication_log_id': medicationLogId,
        'snapshot': snapshot.toJson(),
      },
    );
    return PredictAnomalyResponse.fromJson(json);
  }

  /// Opens iMessage pre-filled with [contacts] phone numbers and [message].
  /// Each contact is a map with key `phone`.
  Future<bool> sendIMessage({
    required List<Map<String, String>> contacts,
    required String message,
  }) async {
    try {
      final result = await _emergencyChannel.invokeMethod<bool>(
        'sendIMessage',
        {'contacts': contacts, 'message': message},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw AppleNativeBridgeException(
        code: e.code,
        message: e.message ?? 'sendIMessage failed',
        details: e.details,
      );
    }
  }

  /// Opens the Phone app to dial [number]. Defaults to 119 if empty.
  Future<bool> emergencyCall({String number = '119'}) async {
    try {
      final result = await _emergencyChannel.invokeMethod<bool>(
        'emergencyCall',
        {'number': number},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw AppleNativeBridgeException(
        code: e.code,
        message: e.message ?? 'emergencyCall failed',
        details: e.details,
      );
    }
  }

  Future<Map<Object?, Object?>> _invokeMap(
    MethodChannel channel,
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      final response = await channel.invokeMethod<Object?>(method, arguments);
      if (response is Map<Object?, Object?>) {
        return response;
      }
      return <Object?, Object?>{};
    } on PlatformException catch (error) {
      throw AppleNativeBridgeException(
        code: error.code,
        message: error.message ?? 'Platform channel error',
        details: error.details,
      );
    }
  }
}
