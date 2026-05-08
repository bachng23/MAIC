import 'package:json_annotation/json_annotation.dart';

part 'api_models.g.dart';

@JsonSerializable(genericArgumentFactories: true)
class ApiResponse<T> {
  ApiResponse({required this.success, this.data, this.message});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) => _$ApiResponseFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) => _$ApiResponseToJson(this, toJsonT);

  final bool success;
  final T? data;
  final String? message;
}

@JsonSerializable()
class UserRegister {
  UserRegister({
    required this.email,
    required this.password,
    required this.name,
    this.phone,
    this.language = 'zh-TW',
  });

  factory UserRegister.fromJson(Map<String, dynamic> json) => _$UserRegisterFromJson(json);
  Map<String, dynamic> toJson() => _$UserRegisterToJson(this);

  final String email;
  final String password;
  final String name;
  final String? phone;
  final String language;
}

@JsonSerializable()
class UserLogin {
  UserLogin({required this.email, required this.password});

  factory UserLogin.fromJson(Map<String, dynamic> json) => _$UserLoginFromJson(json);
  Map<String, dynamic> toJson() => _$UserLoginToJson(this);

  final String email;
  final String password;
}

@JsonSerializable()
class APNSTokenUpdate {
  APNSTokenUpdate({required this.apnsToken});

  factory APNSTokenUpdate.fromJson(Map<String, dynamic> json) => _$APNSTokenUpdateFromJson(json);
  Map<String, dynamic> toJson() => _$APNSTokenUpdateToJson(this);

  @JsonKey(name: 'apns_token')
  final String apnsToken;
}

@JsonSerializable()
class OCRScanRequest {
  OCRScanRequest({required this.imageBase64});
  factory OCRScanRequest.fromJson(Map<String, dynamic> json) => _$OCRScanRequestFromJson(json);
  Map<String, dynamic> toJson() => _$OCRScanRequestToJson(this);

  @JsonKey(name: 'image_base64')
  final String imageBase64;
}

@JsonSerializable()
class OCRScanResult {
  OCRScanResult({
    required this.name,
    this.nameZh,
    this.dosage,
    this.frequency,
    this.expiryDate,
    this.manufacturer,
    this.warnings = const [],
    this.sourceImageUrl,
  });

  factory OCRScanResult.fromJson(Map<String, dynamic> json) => _$OCRScanResultFromJson(json);
  Map<String, dynamic> toJson() => _$OCRScanResultToJson(this);

  final String name;
  @JsonKey(name: 'name_zh')
  final String? nameZh;
  final String? dosage;
  final String? frequency;
  @JsonKey(name: 'expiry_date')
  final String? expiryDate;
  final String? manufacturer;
  final List<String> warnings;
  @JsonKey(name: 'source_image_url')
  final String? sourceImageUrl;
}

@JsonSerializable()
class DrugInfoRequest {
  DrugInfoRequest({required this.drugName, this.drugNameZh});
  factory DrugInfoRequest.fromJson(Map<String, dynamic> json) => _$DrugInfoRequestFromJson(json);
  Map<String, dynamic> toJson() => _$DrugInfoRequestToJson(this);

  @JsonKey(name: 'drug_name')
  final String drugName;
  @JsonKey(name: 'drug_name_zh')
  final String? drugNameZh;
}

@JsonSerializable()
class DrugInfo {
  DrugInfo({
    required this.mainEffects,
    required this.sideEffects,
    required this.warnings,
    this.elderlyNotes,
    this.interactions = const [],
    required this.source,
  });

  factory DrugInfo.fromJson(Map<String, dynamic> json) => _$DrugInfoFromJson(json);
  Map<String, dynamic> toJson() => _$DrugInfoToJson(this);

  @JsonKey(name: 'main_effects')
  final String mainEffects;
  @JsonKey(name: 'side_effects')
  final List<String> sideEffects;
  final List<String> warnings;
  @JsonKey(name: 'elderly_notes')
  final String? elderlyNotes;
  final List<String> interactions;
  final String source;
}

@JsonSerializable()
class MedicationCreate {
  MedicationCreate({
    required this.name,
    this.nameZh,
    this.dosage,
    this.drugInfo,
    this.sourceImageUrl,
  });
  factory MedicationCreate.fromJson(Map<String, dynamic> json) => _$MedicationCreateFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationCreateToJson(this);

  final String name;
  @JsonKey(name: 'name_zh')
  final String? nameZh;
  final String? dosage;
  @JsonKey(name: 'drug_info')
  final DrugInfo? drugInfo;
  @JsonKey(name: 'source_image_url')
  final String? sourceImageUrl;
}

@JsonSerializable()
class MedicationOut {
  MedicationOut({
    required this.id,
    required this.userId,
    required this.name,
    this.nameZh,
    this.dosage,
    this.drugInfo,
    this.sourceImageUrl,
    required this.isActive,
  });
  factory MedicationOut.fromJson(Map<String, dynamic> json) => _$MedicationOutFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationOutToJson(this);

  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final String name;
  @JsonKey(name: 'name_zh')
  final String? nameZh;
  final String? dosage;
  @JsonKey(name: 'drug_info')
  final DrugInfo? drugInfo;
  @JsonKey(name: 'source_image_url')
  final String? sourceImageUrl;
  @JsonKey(name: 'is_active')
  final bool isActive;
}

@JsonSerializable()
class ScheduleCreate {
  ScheduleCreate({
    required this.medicationId,
    required this.times,
    this.daysOfWeek,
  });
  factory ScheduleCreate.fromJson(Map<String, dynamic> json) => _$ScheduleCreateFromJson(json);
  Map<String, dynamic> toJson() => _$ScheduleCreateToJson(this);

  @JsonKey(name: 'medication_id')
  final String medicationId;
  final List<String> times;
  @JsonKey(name: 'days_of_week')
  final List<int>? daysOfWeek;
}

@JsonSerializable()
class ScheduleOut {
  ScheduleOut({
    required this.id,
    required this.userId,
    required this.medicationId,
    required this.times,
    this.daysOfWeek,
    required this.isActive,
  });
  factory ScheduleOut.fromJson(Map<String, dynamic> json) => _$ScheduleOutFromJson(json);
  Map<String, dynamic> toJson() => _$ScheduleOutToJson(this);

  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'medication_id')
  final String medicationId;
  final List<String> times;
  @JsonKey(name: 'days_of_week')
  final List<int>? daysOfWeek;
  @JsonKey(name: 'is_active')
  final bool isActive;
}

@JsonSerializable()
class MedicationTakenRequest {
  MedicationTakenRequest({required this.scheduleId, this.scheduledAt});
  factory MedicationTakenRequest.fromJson(Map<String, dynamic> json) =>
      _$MedicationTakenRequestFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationTakenRequestToJson(this);

  @JsonKey(name: 'schedule_id')
  final String scheduleId;
  @JsonKey(name: 'scheduled_at')
  final DateTime? scheduledAt;
}

@JsonSerializable()
class MedicationTakenResponse {
  MedicationTakenResponse({
    required this.logId,
    required this.monitoringStart,
    required this.monitoringEnd,
    this.monitoringDurationSeconds = 7200,
  });
  factory MedicationTakenResponse.fromJson(Map<String, dynamic> json) =>
      _$MedicationTakenResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationTakenResponseToJson(this);

  @JsonKey(name: 'log_id')
  final String logId;
  @JsonKey(name: 'monitoring_start')
  final DateTime monitoringStart;
  @JsonKey(name: 'monitoring_end')
  final DateTime monitoringEnd;
  @JsonKey(name: 'monitoring_duration_seconds')
  final int monitoringDurationSeconds;
}

@JsonSerializable()
class MedicationSkippedRequest {
  MedicationSkippedRequest({required this.scheduleId, this.scheduledAt, this.reason});
  factory MedicationSkippedRequest.fromJson(Map<String, dynamic> json) =>
      _$MedicationSkippedRequestFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationSkippedRequestToJson(this);

  @JsonKey(name: 'schedule_id')
  final String scheduleId;
  @JsonKey(name: 'scheduled_at')
  final DateTime? scheduledAt;
  final String? reason;
}

enum AnomalyLevel { @JsonValue(0) low, @JsonValue(1) medium, @JsonValue(2) high }

enum AnomalyType { @JsonValue('high_hr') highHr, @JsonValue('low_spo2') lowSpo2, @JsonValue('irregular_hrv') irregularHrv, @JsonValue('combined') combined }

@JsonSerializable()
class AnomalyReport {
  AnomalyReport({
    required this.medicationLogId,
    required this.anomalyLevel,
    required this.anomalyType,
    required this.coreMlConfidence,
    required this.timestamp,
  });
  factory AnomalyReport.fromJson(Map<String, dynamic> json) => _$AnomalyReportFromJson(json);
  Map<String, dynamic> toJson() => _$AnomalyReportToJson(this);

  @JsonKey(name: 'medication_log_id')
  final String medicationLogId;
  @JsonKey(name: 'anomaly_level')
  final AnomalyLevel anomalyLevel;
  @JsonKey(name: 'anomaly_type')
  final AnomalyType anomalyType;
  @JsonKey(name: 'core_ml_confidence')
  final double coreMlConfidence;
  final DateTime timestamp;
}

@JsonSerializable()
class HealthStatus {
  HealthStatus({
    required this.logId,
    required this.monitoringActive,
    this.monitoringStart,
    this.monitoringEnd,
    required this.alertLevel,
    required this.resolved,
  });
  factory HealthStatus.fromJson(Map<String, dynamic> json) => _$HealthStatusFromJson(json);
  Map<String, dynamic> toJson() => _$HealthStatusToJson(this);

  @JsonKey(name: 'log_id')
  final String logId;
  @JsonKey(name: 'monitoring_active')
  final bool monitoringActive;
  @JsonKey(name: 'monitoring_start')
  final DateTime? monitoringStart;
  @JsonKey(name: 'monitoring_end')
  final DateTime? monitoringEnd;
  @JsonKey(name: 'alert_level')
  final AnomalyLevel alertLevel;
  final bool resolved;
}

@JsonSerializable()
class ResolveRequest {
  ResolveRequest({required this.logId});
  factory ResolveRequest.fromJson(Map<String, dynamic> json) => _$ResolveRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ResolveRequestToJson(this);

  @JsonKey(name: 'log_id')
  final String logId;
}

@JsonSerializable()
class EmergencyContact {
  EmergencyContact({required this.name, required this.phone, required this.relation});
  factory EmergencyContact.fromJson(Map<String, dynamic> json) => _$EmergencyContactFromJson(json);
  Map<String, dynamic> toJson() => _$EmergencyContactToJson(this);

  final String name;
  final String phone;
  final String relation;
}

@JsonSerializable()
class EmergencyContactsUpdate {
  EmergencyContactsUpdate({required this.contacts});
  factory EmergencyContactsUpdate.fromJson(Map<String, dynamic> json) =>
      _$EmergencyContactsUpdateFromJson(json);
  Map<String, dynamic> toJson() => _$EmergencyContactsUpdateToJson(this);

  final List<EmergencyContact> contacts;
}
