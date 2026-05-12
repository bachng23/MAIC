import 'package:dio/dio.dart';

import '../../../core/storage/token_storage.dart';
import '../models/api_models.dart';

String _dioFailureMessage(DioException e) {
  final status = e.response?.statusCode;
  final raw = e.response?.data;
  if (raw is Map) {
    final detail = raw['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map) {
        final msg = first['msg'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
    }
    final message = raw['message'];
    if (message is String && message.isNotEmpty) return message;
  }
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Request timed out. Check your connection and try again.';
    case DioExceptionType.connectionError:
      return 'Could not reach the server. Check your connection and try again.';
    default:
      break;
  }
  if (status == 401) {
    return 'Invalid email or password.';
  }
  if (status != null) {
    return 'Request failed (HTTP $status).';
  }
  return e.message?.isNotEmpty == true ? e.message! : 'Something went wrong. Please try again.';
}

Options get _jsonOptions => Options(
      contentType: 'application/json',
      headers: const {'Accept': 'application/json'},
    );

class MediGuardApiService {
  MediGuardApiService(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  Future<void> setToken(String token) => _tokenStorage.writeToken(token);
  Future<String?> getToken() => _tokenStorage.readToken();
  Future<void> clearToken() => _tokenStorage.clearToken();

  Future<Map<String, dynamic>> login(UserLogin payload) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: payload.toJson(),
        options: _jsonOptions,
      );
      final parsed = ApiResponse<Map<String, dynamic>>.fromJson(response.data!, (json) {
        return Map<String, dynamic>.from(json! as Map);
      });
      if (parsed.data == null || parsed.data!['access_token'] == null) {
        throw Exception(parsed.message ?? 'Login failed.');
      }
      return parsed.data!;
    } on DioException catch (e) {
      throw Exception(_dioFailureMessage(e));
    }
  }

  Future<void> register(UserRegister payload) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/register',
        data: payload.toJson(),
        options: _jsonOptions,
      );
    } on DioException catch (e) {
      throw Exception(_dioFailureMessage(e));
    }
  }

  Future<OCRScanResult> scanMedication(OCRScanRequest payload) async {
    final token = await getToken();
    if (token == null) throw Exception('Please log in first.');
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/medications/scan',
      data: payload.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final parsed = ApiResponse<OCRScanResult>.fromJson(
      response.data!,
      (json) => OCRScanResult.fromJson(Map<String, dynamic>.from(json! as Map)),
    );
    if (parsed.data == null) throw Exception(parsed.message ?? 'Scan failed.');
    return parsed.data!;
  }

  Future<DrugInfo> fetchDrugInfo(DrugInfoRequest payload) async {
    final token = await getToken();
    if (token == null) throw Exception('Please log in first.');
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/medications/drug-info',
      data: payload.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final parsed = ApiResponse<DrugInfo>.fromJson(
      response.data!,
      (json) => DrugInfo.fromJson(Map<String, dynamic>.from(json! as Map)),
    );
    if (parsed.data == null) throw Exception(parsed.message ?? 'Drug info request failed.');
    return parsed.data!;
  }

  Future<MedicationOut> createMedication(MedicationCreate payload) async {
    final token = await getToken();
    if (token == null) throw Exception('Please log in first.');
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/medications',
      data: payload.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final parsed = ApiResponse<MedicationOut>.fromJson(
      response.data!,
      (json) => MedicationOut.fromJson(Map<String, dynamic>.from(json! as Map)),
    );
    if (parsed.data == null) throw Exception(parsed.message ?? 'Create medication failed.');
    return parsed.data!;
  }

  Future<HealthStatus> getHealthStatus(String logId) async {
    final token = await getToken();
    if (token == null) throw Exception('Please log in first.');
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/health/status/$logId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final parsed = ApiResponse<HealthStatus>.fromJson(
      response.data!,
      (json) => HealthStatus.fromJson(Map<String, dynamic>.from(json! as Map)),
    );
    if (parsed.data == null) throw Exception(parsed.message ?? 'Health status request failed.');
    return parsed.data!;
  }

  Future<void> reportAnomaly(AnomalyReport payload) async {
    final token = await getToken();
    if (token == null) throw Exception('Please log in first.');
    await _dio.post<Map<String, dynamic>>(
      '/api/v1/health/anomaly',
      data: payload.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> resolveAlert(ResolveRequest payload) async {
    final token = await getToken();
    if (token == null) throw Exception('Please log in first.');
    await _dio.post<Map<String, dynamic>>(
      '/api/v1/health/resolve',
      data: payload.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<Map<String, dynamic>> healthCheck() async {
    final response = await _dio.get<Map<String, dynamic>>('/health');
    return response.data ?? <String, dynamic>{};
  }

  Future<DashboardViewData> loadDashboard() async {
    final token = await getToken();
    if (token == null) throw Exception('Please log in first.');
    final headers = {'Authorization': 'Bearer $token'};
    final medsRes = await _dio.get<Map<String, dynamic>>('/api/v1/medications', options: Options(headers: headers));
    final schedulesRes = await _dio.get<Map<String, dynamic>>('/api/v1/schedules', options: Options(headers: headers));
    final contactsRes =
        await _dio.get<Map<String, dynamic>>('/api/v1/emergency/contacts', options: Options(headers: headers));

    final medications = ApiResponse<List<MedicationOut>>.fromJson(
      medsRes.data!,
      (json) => (json! as List).map((e) => MedicationOut.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    ).data ??
        [];
    final schedules = ApiResponse<List<ScheduleOut>>.fromJson(
      schedulesRes.data!,
      (json) => (json! as List).map((e) => ScheduleOut.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    ).data ??
        [];
    final contacts = ApiResponse<List<EmergencyContact>>.fromJson(
      contactsRes.data!,
      (json) =>
          (json! as List).map((e) => EmergencyContact.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    ).data ??
        [];

    return DashboardViewData(medications: medications, schedules: schedules, contacts: contacts);
  }
}

class DashboardViewData {
  DashboardViewData({
    required this.medications,
    required this.schedules,
    required this.contacts,
  });

  final List<MedicationOut> medications;
  final List<ScheduleOut> schedules;
  final List<EmergencyContact> contacts;
}
