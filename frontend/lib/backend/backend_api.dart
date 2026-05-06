import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'backend_models.dart';

class BackendApiClient {
  const BackendApiClient({
    this.timeout = const Duration(seconds: 15),
  });

  final Duration timeout;

  Future<LoginResponse> login({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    final response = await _sendJsonRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: {
        'email': email,
        'password': password,
      },
    );

    final data = _unwrapData(response) as Map<String, dynamic>;
    return LoginResponse.fromJson(data);
  }

  Future<Map<String, dynamic>> healthCheck({
    required String baseUrl,
  }) async {
    final response = await _sendJsonRequest(
      'GET',
      Uri.parse('$baseUrl/health'),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        statusCode: response.statusCode,
        message: (json['detail'] ?? json['error'] ?? 'Health check failed')
            .toString(),
        body: response.body,
      );
    }
    return json;
  }

  Future<BackendMedication> createMedication({
    required String baseUrl,
    required String accessToken,
    required MedicationDraft draft,
  }) async {
    final response = await _sendJsonRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/medications'),
      headers: _headers(accessToken),
      body: draft.toCreateMedicationPayload(),
    );

    final data = _unwrapData(response) as Map<String, dynamic>;
    return BackendMedication.fromJson(data);
  }

  Future<BackendSchedule> createSchedule({
    required String baseUrl,
    required String accessToken,
    required String medicationId,
    required List<String> times,
    List<int>? daysOfWeek,
  }) async {
    final response = await _sendJsonRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/schedules'),
      headers: _headers(accessToken),
      body: {
        'medication_id': medicationId,
        'times': times,
        'days_of_week': daysOfWeek,
      },
    );

    final data = _unwrapData(response) as Map<String, dynamic>;
    return BackendSchedule.fromJson(data);
  }

  Future<List<BackendSchedule>> listSchedules({
    required String baseUrl,
    required String accessToken,
  }) async {
    final response = await _sendJsonRequest(
      'GET',
      Uri.parse('$baseUrl/api/v1/schedules'),
      headers: _headers(accessToken),
    );

    final data = _unwrapData(response) as List<dynamic>;
    return data
        .cast<Map<String, dynamic>>()
        .map(BackendSchedule.fromJson)
        .toList();
  }

  Future<MedicationTakenResponse> logTaken({
    required String baseUrl,
    required String accessToken,
    required String scheduleId,
  }) async {
    final response = await _sendJsonRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/logs/taken'),
      headers: _headers(accessToken),
      body: {'schedule_id': scheduleId},
    );

    final data = _unwrapData(response) as Map<String, dynamic>;
    return MedicationTakenResponse.fromJson(data);
  }

  Future<void> reportAnomaly({
    required String baseUrl,
    required String accessToken,
    required Map<Object?, Object?> backendReport,
  }) async {
    final response = await _sendJsonRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/health/anomaly'),
      headers: _headers(accessToken),
      body: _stringKeyedMap(backendReport),
    );

    _unwrapData(response, allowNullData: true);
  }

  Future<Map<String, dynamic>> scanMedicationImage({
    required String baseUrl,
    required String accessToken,
    required String imagePath,
  }) async {
    final imageBase64 = base64Encode(await File(imagePath).readAsBytes());
    final response = await _sendJsonRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/medications/scan'),
      headers: _headers(accessToken),
      body: {'image_base64': imageBase64},
    );

    final data = _unwrapData(response) as Map<String, dynamic>;
    return data;
  }

  static Map<String, String> _headers(String accessToken) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  Future<_BackendResponse> _sendJsonRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = timeout
      ..findProxy = (_) => 'DIRECT';

    try {
      final request = await client.openUrl(method, uri).timeout(timeout);
      final mergedHeaders = {
        if (body != null) 'Content-Type': 'application/json',
        ...?headers,
      };

      for (final entry in mergedHeaders.entries) {
        request.headers.set(entry.key, entry.value);
      }

      if (body != null) {
        request.add(
          utf8.encode(
            body is String ? body : jsonEncode(body),
          ),
        );
      }

      final response = await request.close().timeout(timeout);
      final responseBody = await utf8.decoder.bind(response).join().timeout(timeout);

      return _BackendResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } on TimeoutException catch (error) {
      final details = await probeConnection(uri: uri);
      throw TimeoutException(
        '${error.message ?? 'HTTP request timed out'}\n$details',
        timeout,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<String> probeConnection({required Uri uri}) async {
    final host = uri.host;
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      final address = socket.remoteAddress.address;
      final remotePort = socket.remotePort;
      await socket.close();
      return 'TCP probe succeeded: $host:$port -> $address:$remotePort';
    } on SocketException catch (error) {
      return 'TCP probe failed for $host:$port: $error';
    } catch (error) {
      return 'TCP probe error for $host:$port: $error';
    }
  }

  static Object? _unwrapData(_BackendResponse response, {bool allowNullData = false}) {
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        statusCode: response.statusCode,
        message: (json['detail'] ?? json['error'] ?? 'Request failed').toString(),
        body: response.body,
      );
    }

    final data = json['data'];
    if (data == null && !allowNullData) {
      throw BackendApiException(
        statusCode: response.statusCode,
        message: 'Response data is empty',
        body: response.body,
      );
    }
    return data;
  }

  static Map<String, dynamic> _stringKeyedMap(Map<Object?, Object?> source) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }
}

class _BackendResponse {
  const _BackendResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}
