class MedicationDraft {
  const MedicationDraft({
    required this.name,
    this.nameZh,
    this.dosage,
    this.frequency,
    this.warnings = const [],
    this.sourceRawText,
  });

  final String name;
  final String? nameZh;
  final String? dosage;
  final String? frequency;
  final List<String> warnings;
  final String? sourceRawText;

  Map<String, Object?> toCreateMedicationPayload() {
    return {
      'name': name,
      'name_zh': nameZh,
      'dosage': dosage,
    };
  }

  @override
  String toString() {
    return 'name: $name\nnameZh: ${nameZh ?? '-'}\ndosage: ${dosage ?? '-'}\nfrequency: ${frequency ?? '-'}\nwarnings: ${warnings.join(', ')}';
  }
}

class MedicationTakenResponse {
  const MedicationTakenResponse({
    required this.logId,
    required this.monitoringStart,
    required this.monitoringEnd,
    required this.monitoringDurationSeconds,
  });

  final String logId;
  final DateTime monitoringStart;
  final DateTime monitoringEnd;
  final int monitoringDurationSeconds;

  factory MedicationTakenResponse.fromJson(Map<String, dynamic> json) {
    return MedicationTakenResponse(
      logId: json['log_id'] as String,
      monitoringStart: DateTime.parse(json['monitoring_start'] as String),
      monitoringEnd: DateTime.parse(json['monitoring_end'] as String),
      monitoringDurationSeconds:
          (json['monitoring_duration_seconds'] as num?)?.toInt() ?? 7200,
    );
  }
}

class BackendMedication {
  const BackendMedication({
    required this.id,
    required this.name,
    this.nameZh,
    this.dosage,
  });

  final String id;
  final String name;
  final String? nameZh;
  final String? dosage;

  factory BackendMedication.fromJson(Map<String, dynamic> json) {
    return BackendMedication(
      id: json['id'] as String,
      name: json['name'] as String,
      nameZh: json['name_zh'] as String?,
      dosage: json['dosage'] as String?,
    );
  }
}

class LoginResponse {
  const LoginResponse({
    required this.accessToken,
  });

  final String accessToken;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] as String,
    );
  }
}

class BackendSchedule {
  const BackendSchedule({
    required this.id,
    required this.medicationId,
    required this.times,
    required this.daysOfWeek,
  });

  final String id;
  final String medicationId;
  final List<String> times;
  final List<int>? daysOfWeek;

  factory BackendSchedule.fromJson(Map<String, dynamic> json) {
    return BackendSchedule(
      id: json['id'] as String,
      medicationId: json['medication_id'] as String,
      times: ((json['times'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      daysOfWeek: (json['days_of_week'] as List<dynamic>?)
          ?.map((item) => (item as num).toInt())
          .toList(),
    );
  }

  @override
  String toString() {
    return 'id: $id\nmedicationId: $medicationId\ntimes: ${times.join(', ')}\ndaysOfWeek: ${daysOfWeek?.join(', ') ?? '-'}';
  }
}

class BackendApiException implements Exception {
  const BackendApiException({
    required this.statusCode,
    required this.message,
    this.body,
  });

  final int statusCode;
  final String message;
  final String? body;

  @override
  String toString() => 'HTTP $statusCode: $message';
}
