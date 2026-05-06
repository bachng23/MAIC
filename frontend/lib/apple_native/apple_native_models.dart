class HealthSnapshot {
  const HealthSnapshot({
    required this.heartRate,
    required this.hrv,
    required this.spo2,
    required this.timestamp,
    required this.sampleTimestamp,
    required this.activityState,
    required this.source,
    required this.sourceDeviceName,
    required this.sourceDeviceModel,
    required this.sourceAppName,
  });

  final double? heartRate;
  final double? hrv;
  final double? spo2;
  final DateTime timestamp;
  final DateTime? sampleTimestamp;
  final String activityState;
  final String source;
  final String? sourceDeviceName;
  final String? sourceDeviceModel;
  final String? sourceAppName;

  factory HealthSnapshot.fromJson(Map<Object?, Object?> json) {
    return HealthSnapshot(
      heartRate: (json['heart_rate'] as num?)?.toDouble(),
      hrv: (json['hrv'] as num?)?.toDouble(),
      spo2: (json['spo2'] as num?)?.toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      sampleTimestamp: (json['sample_timestamp'] as String?) == null
          ? null
          : DateTime.parse(json['sample_timestamp'] as String),
      activityState: (json['activity_state'] as String?) ?? 'unknown',
      source: (json['source'] as String?) ?? 'unknown',
      sourceDeviceName: json['source_device_name'] as String?,
      sourceDeviceModel: json['source_device_model'] as String?,
      sourceAppName: json['source_app_name'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'heart_rate': heartRate,
      'hrv': hrv,
      'spo2': spo2,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'sample_timestamp': sampleTimestamp?.toUtc().toIso8601String(),
      'activity_state': activityState,
      'source': source,
      'source_device_name': sourceDeviceName,
      'source_device_model': sourceDeviceModel,
      'source_app_name': sourceAppName,
    };
  }
}

class OcrResult {
  const OcrResult({
    required this.rawText,
    required this.lines,
  });

  final String rawText;
  final List<String> lines;

  factory OcrResult.fromJson(Map<Object?, Object?> json) {
    final lines = (json['lines'] as List<Object?>? ?? const [])
        .map((line) => line.toString())
        .toList();
    return OcrResult(
      rawText: (json['raw_text'] as String?) ?? '',
      lines: lines,
    );
  }
}

class HealthPermissionResponse {
  const HealthPermissionResponse({
    required this.granted,
    required this.requestedAt,
  });

  final bool granted;
  final DateTime requestedAt;

  factory HealthPermissionResponse.fromJson(Map<Object?, Object?> json) {
    return HealthPermissionResponse(
      granted: (json['granted'] as bool?) ?? false,
      requestedAt: DateTime.parse(json['requested_at'] as String),
    );
  }
}

class MonitoringSessionResponse {
  const MonitoringSessionResponse({
    required this.session,
  });

  final Map<Object?, Object?>? session;

  factory MonitoringSessionResponse.fromJson(Map<Object?, Object?> json) {
    return MonitoringSessionResponse(
      session: json['session'] as Map<Object?, Object?>?,
    );
  }
}

class BaselineResponse {
  const BaselineResponse({
    required this.baseline,
  });

  final Map<Object?, Object?> baseline;

  factory BaselineResponse.fromJson(Map<Object?, Object?> json) {
    return BaselineResponse(
      baseline: (json['baseline'] as Map<Object?, Object?>?) ?? const {},
    );
  }
}

class ModelStatusResponse {
  const ModelStatusResponse({
    required this.loaded,
    required this.modelName,
    required this.modelVersion,
    required this.mode,
  });

  final bool loaded;
  final String modelName;
  final String modelVersion;
  final String mode;

  factory ModelStatusResponse.fromJson(Map<Object?, Object?> json) {
    return ModelStatusResponse(
      loaded: (json['loaded'] as bool?) ?? false,
      modelName: (json['model_name'] as String?) ?? '',
      modelVersion: (json['model_version'] as String?) ?? '',
      mode: (json['mode'] as String?) ?? '',
    );
  }
}

class PredictAnomalyResponse {
  const PredictAnomalyResponse({
    required this.prediction,
    required this.backendReport,
  });

  final Map<Object?, Object?> prediction;
  final Map<Object?, Object?>? backendReport;

  factory PredictAnomalyResponse.fromJson(Map<Object?, Object?> json) {
    return PredictAnomalyResponse(
      prediction: (json['prediction'] as Map<Object?, Object?>?) ?? const {},
      backendReport: json['backend_report'] as Map<Object?, Object?>?,
    );
  }
}

class AppleNativeBridgeException implements Exception {
  const AppleNativeBridgeException({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => '$code: $message';
}
