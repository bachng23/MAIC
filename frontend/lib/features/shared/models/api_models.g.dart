// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiResponse<T> _$ApiResponseFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) => ApiResponse<T>(
  success: json['success'] as bool,
  data: _$nullableGenericFromJson(json['data'], fromJsonT),
  message: json['message'] as String?,
);

Map<String, dynamic> _$ApiResponseToJson<T>(
  ApiResponse<T> instance,
  Object? Function(T value) toJsonT,
) => <String, dynamic>{
  'success': instance.success,
  'data': _$nullableGenericToJson(instance.data, toJsonT),
  'message': instance.message,
};

T? _$nullableGenericFromJson<T>(
  Object? input,
  T Function(Object? json) fromJson,
) => input == null ? null : fromJson(input);

Object? _$nullableGenericToJson<T>(
  T? input,
  Object? Function(T value) toJson,
) => input == null ? null : toJson(input);

UserRegister _$UserRegisterFromJson(Map<String, dynamic> json) => UserRegister(
  email: json['email'] as String,
  password: json['password'] as String,
  name: json['name'] as String,
  phone: json['phone'] as String?,
  language: json['language'] as String? ?? 'zh-TW',
);

Map<String, dynamic> _$UserRegisterToJson(UserRegister instance) =>
    <String, dynamic>{
      'email': instance.email,
      'password': instance.password,
      'name': instance.name,
      'phone': instance.phone,
      'language': instance.language,
    };

UserLogin _$UserLoginFromJson(Map<String, dynamic> json) => UserLogin(
  email: json['email'] as String,
  password: json['password'] as String,
);

Map<String, dynamic> _$UserLoginToJson(UserLogin instance) => <String, dynamic>{
  'email': instance.email,
  'password': instance.password,
};

APNSTokenUpdate _$APNSTokenUpdateFromJson(Map<String, dynamic> json) =>
    APNSTokenUpdate(apnsToken: json['apns_token'] as String);

Map<String, dynamic> _$APNSTokenUpdateToJson(APNSTokenUpdate instance) =>
    <String, dynamic>{'apns_token': instance.apnsToken};

OCRScanRequest _$OCRScanRequestFromJson(Map<String, dynamic> json) =>
    OCRScanRequest(imageBase64: json['image_base64'] as String);

Map<String, dynamic> _$OCRScanRequestToJson(OCRScanRequest instance) =>
    <String, dynamic>{'image_base64': instance.imageBase64};

OCRScanResult _$OCRScanResultFromJson(Map<String, dynamic> json) =>
    OCRScanResult(
      name: json['name'] as String,
      nameZh: json['name_zh'] as String?,
      dosage: json['dosage'] as String?,
      frequency: json['frequency'] as String?,
      expiryDate: json['expiry_date'] as String?,
      manufacturer: json['manufacturer'] as String?,
      warnings:
          (json['warnings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      sourceImageUrl: json['source_image_url'] as String?,
    );

Map<String, dynamic> _$OCRScanResultToJson(OCRScanResult instance) =>
    <String, dynamic>{
      'name': instance.name,
      'name_zh': instance.nameZh,
      'dosage': instance.dosage,
      'frequency': instance.frequency,
      'expiry_date': instance.expiryDate,
      'manufacturer': instance.manufacturer,
      'warnings': instance.warnings,
      'source_image_url': instance.sourceImageUrl,
    };

DrugInfoRequest _$DrugInfoRequestFromJson(Map<String, dynamic> json) =>
    DrugInfoRequest(
      drugName: json['drug_name'] as String,
      drugNameZh: json['drug_name_zh'] as String?,
    );

Map<String, dynamic> _$DrugInfoRequestToJson(DrugInfoRequest instance) =>
    <String, dynamic>{
      'drug_name': instance.drugName,
      'drug_name_zh': instance.drugNameZh,
    };

DrugInfo _$DrugInfoFromJson(Map<String, dynamic> json) => DrugInfo(
  mainEffects: json['main_effects'] as String,
  sideEffects: (json['side_effects'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  warnings: (json['warnings'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  elderlyNotes: json['elderly_notes'] as String?,
  interactions:
      (json['interactions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  source: json['source'] as String,
);

Map<String, dynamic> _$DrugInfoToJson(DrugInfo instance) => <String, dynamic>{
  'main_effects': instance.mainEffects,
  'side_effects': instance.sideEffects,
  'warnings': instance.warnings,
  'elderly_notes': instance.elderlyNotes,
  'interactions': instance.interactions,
  'source': instance.source,
};

MedicationCreate _$MedicationCreateFromJson(Map<String, dynamic> json) =>
    MedicationCreate(
      name: json['name'] as String,
      nameZh: json['name_zh'] as String?,
      dosage: json['dosage'] as String?,
      drugInfo: json['drug_info'] == null
          ? null
          : DrugInfo.fromJson(json['drug_info'] as Map<String, dynamic>),
      sourceImageUrl: json['source_image_url'] as String?,
    );

Map<String, dynamic> _$MedicationCreateToJson(MedicationCreate instance) =>
    <String, dynamic>{
      'name': instance.name,
      'name_zh': instance.nameZh,
      'dosage': instance.dosage,
      'drug_info': instance.drugInfo,
      'source_image_url': instance.sourceImageUrl,
    };

MedicationOut _$MedicationOutFromJson(Map<String, dynamic> json) =>
    MedicationOut(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      nameZh: json['name_zh'] as String?,
      dosage: json['dosage'] as String?,
      drugInfo: json['drug_info'] == null
          ? null
          : DrugInfo.fromJson(json['drug_info'] as Map<String, dynamic>),
      sourceImageUrl: json['source_image_url'] as String?,
      isActive: json['is_active'] as bool,
    );

Map<String, dynamic> _$MedicationOutToJson(MedicationOut instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'name': instance.name,
      'name_zh': instance.nameZh,
      'dosage': instance.dosage,
      'drug_info': instance.drugInfo,
      'source_image_url': instance.sourceImageUrl,
      'is_active': instance.isActive,
    };

ScheduleCreate _$ScheduleCreateFromJson(Map<String, dynamic> json) =>
    ScheduleCreate(
      medicationId: json['medication_id'] as String,
      times: (json['times'] as List<dynamic>).map((e) => e as String).toList(),
      daysOfWeek: (json['days_of_week'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$ScheduleCreateToJson(ScheduleCreate instance) =>
    <String, dynamic>{
      'medication_id': instance.medicationId,
      'times': instance.times,
      'days_of_week': instance.daysOfWeek,
    };

ScheduleOut _$ScheduleOutFromJson(Map<String, dynamic> json) => ScheduleOut(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  medicationId: json['medication_id'] as String,
  times: (json['times'] as List<dynamic>).map((e) => e as String).toList(),
  daysOfWeek: (json['days_of_week'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  isActive: json['is_active'] as bool,
);

Map<String, dynamic> _$ScheduleOutToJson(ScheduleOut instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'medication_id': instance.medicationId,
      'times': instance.times,
      'days_of_week': instance.daysOfWeek,
      'is_active': instance.isActive,
    };

MedicationTakenRequest _$MedicationTakenRequestFromJson(
  Map<String, dynamic> json,
) => MedicationTakenRequest(
  scheduleId: json['schedule_id'] as String,
  scheduledAt: json['scheduled_at'] == null
      ? null
      : DateTime.parse(json['scheduled_at'] as String),
);

Map<String, dynamic> _$MedicationTakenRequestToJson(
  MedicationTakenRequest instance,
) => <String, dynamic>{
  'schedule_id': instance.scheduleId,
  'scheduled_at': instance.scheduledAt?.toIso8601String(),
};

MedicationTakenResponse _$MedicationTakenResponseFromJson(
  Map<String, dynamic> json,
) => MedicationTakenResponse(
  logId: json['log_id'] as String,
  monitoringStart: DateTime.parse(json['monitoring_start'] as String),
  monitoringEnd: DateTime.parse(json['monitoring_end'] as String),
  monitoringDurationSeconds:
      (json['monitoring_duration_seconds'] as num?)?.toInt() ?? 7200,
);

Map<String, dynamic> _$MedicationTakenResponseToJson(
  MedicationTakenResponse instance,
) => <String, dynamic>{
  'log_id': instance.logId,
  'monitoring_start': instance.monitoringStart.toIso8601String(),
  'monitoring_end': instance.monitoringEnd.toIso8601String(),
  'monitoring_duration_seconds': instance.monitoringDurationSeconds,
};

MedicationSkippedRequest _$MedicationSkippedRequestFromJson(
  Map<String, dynamic> json,
) => MedicationSkippedRequest(
  scheduleId: json['schedule_id'] as String,
  scheduledAt: json['scheduled_at'] == null
      ? null
      : DateTime.parse(json['scheduled_at'] as String),
  reason: json['reason'] as String?,
);

Map<String, dynamic> _$MedicationSkippedRequestToJson(
  MedicationSkippedRequest instance,
) => <String, dynamic>{
  'schedule_id': instance.scheduleId,
  'scheduled_at': instance.scheduledAt?.toIso8601String(),
  'reason': instance.reason,
};

AnomalyReport _$AnomalyReportFromJson(Map<String, dynamic> json) =>
    AnomalyReport(
      medicationLogId: json['medication_log_id'] as String,
      anomalyLevel: $enumDecode(_$AnomalyLevelEnumMap, json['anomaly_level']),
      anomalyType: $enumDecode(_$AnomalyTypeEnumMap, json['anomaly_type']),
      coreMlConfidence: (json['core_ml_confidence'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$AnomalyReportToJson(AnomalyReport instance) =>
    <String, dynamic>{
      'medication_log_id': instance.medicationLogId,
      'anomaly_level': _$AnomalyLevelEnumMap[instance.anomalyLevel]!,
      'anomaly_type': _$AnomalyTypeEnumMap[instance.anomalyType]!,
      'core_ml_confidence': instance.coreMlConfidence,
      'timestamp': instance.timestamp.toIso8601String(),
    };

const _$AnomalyLevelEnumMap = {
  AnomalyLevel.low: 0,
  AnomalyLevel.medium: 1,
  AnomalyLevel.high: 2,
};

const _$AnomalyTypeEnumMap = {
  AnomalyType.highHr: 'high_hr',
  AnomalyType.lowSpo2: 'low_spo2',
  AnomalyType.irregularHrv: 'irregular_hrv',
  AnomalyType.combined: 'combined',
};

HealthStatus _$HealthStatusFromJson(Map<String, dynamic> json) => HealthStatus(
  logId: json['log_id'] as String,
  monitoringActive: json['monitoring_active'] as bool,
  monitoringStart: json['monitoring_start'] == null
      ? null
      : DateTime.parse(json['monitoring_start'] as String),
  monitoringEnd: json['monitoring_end'] == null
      ? null
      : DateTime.parse(json['monitoring_end'] as String),
  alertLevel: $enumDecode(_$AnomalyLevelEnumMap, json['alert_level']),
  resolved: json['resolved'] as bool,
);

Map<String, dynamic> _$HealthStatusToJson(HealthStatus instance) =>
    <String, dynamic>{
      'log_id': instance.logId,
      'monitoring_active': instance.monitoringActive,
      'monitoring_start': instance.monitoringStart?.toIso8601String(),
      'monitoring_end': instance.monitoringEnd?.toIso8601String(),
      'alert_level': _$AnomalyLevelEnumMap[instance.alertLevel]!,
      'resolved': instance.resolved,
    };

ResolveRequest _$ResolveRequestFromJson(Map<String, dynamic> json) =>
    ResolveRequest(logId: json['log_id'] as String);

Map<String, dynamic> _$ResolveRequestToJson(ResolveRequest instance) =>
    <String, dynamic>{'log_id': instance.logId};

EmergencyContact _$EmergencyContactFromJson(Map<String, dynamic> json) =>
    EmergencyContact(
      name: json['name'] as String,
      phone: json['phone'] as String,
      relation: json['relation'] as String,
    );

Map<String, dynamic> _$EmergencyContactToJson(EmergencyContact instance) =>
    <String, dynamic>{
      'name': instance.name,
      'phone': instance.phone,
      'relation': instance.relation,
    };

EmergencyContactsUpdate _$EmergencyContactsUpdateFromJson(
  Map<String, dynamic> json,
) => EmergencyContactsUpdate(
  contacts: (json['contacts'] as List<dynamic>)
      .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$EmergencyContactsUpdateToJson(
  EmergencyContactsUpdate instance,
) => <String, dynamic>{'contacts': instance.contacts};
