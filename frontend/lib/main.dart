import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'apple_native/apple_native_bridge.dart';
import 'apple_native/apple_native_models.dart';
import 'backend/backend_api.dart';
import 'backend/backend_models.dart';
import 'backend/medication_draft_parser.dart';

void main() {
  runApp(const MediGuardNativeApp());
}

class MediGuardNativeApp extends StatelessWidget {
  const MediGuardNativeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediGuard Native Bridge',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: const NativeBridgeDemoPage(),
    );
  }
}

class NativeBridgeDemoPage extends StatefulWidget {
  const NativeBridgeDemoPage({super.key});

  @override
  State<NativeBridgeDemoPage> createState() => _NativeBridgeDemoPageState();
}

class _NativeBridgeDemoPageState extends State<NativeBridgeDemoPage> {
  final AppleNativeBridge _bridge = AppleNativeBridge();
  final BackendApiClient _backendApi = const BackendApiClient();
  final MedicationDraftParser _draftParser = const MedicationDraftParser();
  final TextEditingController _imagePathController = TextEditingController();
  final TextEditingController _logIdController = TextEditingController(
    text: 'log-123',
  );
  final TextEditingController _baseUrlController = TextEditingController(
    text: 'http://192.168.1.2:8000',
  );
  final TextEditingController _emailController = TextEditingController(
    text: 'demo@mediguard.app',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: 'DemoPass123!',
  );
  final TextEditingController _accessTokenController = TextEditingController();
  final TextEditingController _scheduleIdController = TextEditingController();
  final TextEditingController _scheduleTimeController = TextEditingController(
    text: '08:00',
  );

  String _status = 'Ready';
  String _output = 'No calls yet.';
  String _selectedImageSummary = 'No image selected.';
  MedicationDraft? _lastDraft;
  BackendMedication? _lastMedication;

  @override
  void dispose() {
    _imagePathController.dispose();
    _logIdController.dispose();
    _baseUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _accessTokenController.dispose();
    _scheduleIdController.dispose();
    _scheduleTimeController.dispose();
    super.dispose();
  }

  Future<void> _pickImageAndPopulatePath() async {
    await _run('Pick image', () async {
      final imagePath = await _bridge.pickImageFromLibrary();
      _imagePathController.text = imagePath;
      setState(() {
        _selectedImageSummary = imagePath;
      });
      return {'image_path': imagePath};
    });
  }

  Future<void> _runNativeOcrAndParseDraft() async {
    await _run('OCR and parse draft', () async {
      final result = await _bridge.recognizeTextFromFile(
        _imagePathController.text.trim(),
      );
      final draft = _draftParser.parse(result.rawText);
      _lastDraft = draft;
      return 'OCR RESULT\n${_formatResult(result)}\n\nDRAFT\n$draft';
    });
  }

  String? _validateBackendBaseUrl() {
    final baseUrl = _baseUrlController.text.trim();
    if (baseUrl.isEmpty) {
      return 'Backend base URL is required.';
    }
    if (baseUrl.contains('127.0.0.1') || baseUrl.contains('localhost')) {
      return 'On iPhone, do not use 127.0.0.1 or localhost. Use your Mac LAN IP like http://192.168.x.x:8000.';
    }
    return null;
  }

  bool _requireBackendBaseUrl() {
    final validationError = _validateBackendBaseUrl();
    if (validationError == null) {
      return true;
    }

    setState(() {
      _status = 'Validation failed';
      _output = validationError;
    });
    return false;
  }

  Future<void> _pingBackend() async {
    if (!_requireBackendBaseUrl()) {
      return;
    }

    await _run('Ping backend', () async {
      final result = await _backendApi.healthCheck(
        baseUrl: _baseUrlController.text.trim(),
      );
      return result;
    });
  }

  Future<void> _loginToBackend() async {
    if (!_requireBackendBaseUrl()) {
      return;
    }

    await _run('Login', () async {
      final response = await _backendApi.login(
        baseUrl: _baseUrlController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      _accessTokenController.text = response.accessToken;
      return {
        'access_token': response.accessToken,
      };
    });
  }

  Future<void> _createMedicationFromDraft() async {
    if (!_requireBackendBaseUrl()) {
      return;
    }

    final draft = _lastDraft;
    if (draft == null) {
      setState(() {
        _status = 'Create medication failed';
        _output = 'No medication draft available. Run OCR and parse draft first.';
      });
      return;
    }

    await _run('Create medication', () async {
      final medication = await _backendApi.createMedication(
        baseUrl: _baseUrlController.text.trim(),
        accessToken: _accessTokenController.text.trim(),
        draft: draft,
      );
      _lastMedication = medication;
      return {
        'id': medication.id,
        'name': medication.name,
        'name_zh': medication.nameZh,
        'dosage': medication.dosage,
      };
    });
  }

  Future<void> _createScheduleForLastMedication() async {
    if (!_requireBackendBaseUrl()) {
      return;
    }

    final medication = _lastMedication;
    if (medication == null) {
      setState(() {
        _status = 'Create schedule failed';
        _output = 'No medication available. Create a medication first.';
      });
      return;
    }

    await _run('Create schedule', () async {
      final schedule = await _backendApi.createSchedule(
        baseUrl: _baseUrlController.text.trim(),
        accessToken: _accessTokenController.text.trim(),
        medicationId: medication.id,
        times: [_scheduleTimeController.text.trim()],
      );
      _scheduleIdController.text = schedule.id;
      return {
        'id': schedule.id,
        'medication_id': schedule.medicationId,
        'times': schedule.times,
      };
    });
  }

  Future<void> _listSchedulesAndSelectLatest() async {
    if (!_requireBackendBaseUrl()) {
      return;
    }

    await _run('List schedules', () async {
      final schedules = await _backendApi.listSchedules(
        baseUrl: _baseUrlController.text.trim(),
        accessToken: _accessTokenController.text.trim(),
      );
      if (schedules.isNotEmpty) {
        _scheduleIdController.text = schedules.first.id;
      }
      return schedules.map((schedule) => schedule.toString()).join('\n\n');
    });
  }

  Future<void> _logTakenAndStartMonitoring() async {
    if (!_requireBackendBaseUrl()) {
      return;
    }
    if (_scheduleIdController.text.trim().isEmpty) {
      setState(() {
        _status = 'Validation failed';
        _output =
            'Schedule id is empty. Create a schedule first or use List Schedules to fill it.';
      });
      return;
    }

    await _run('Log taken and start monitoring', () async {
      await _bridge.requestHealthPermissions();

      final response = await _backendApi.logTaken(
        baseUrl: _baseUrlController.text.trim(),
        accessToken: _accessTokenController.text.trim(),
        scheduleId: _scheduleIdController.text.trim(),
      );

      _logIdController.text = response.logId;

      final session = await _bridge.startMonitoring(
        logId: response.logId,
        start: response.monitoringStart,
        end: response.monitoringEnd,
        medicationName: _lastDraft?.name,
      );

      return {
        'log_taken': {
          'log_id': response.logId,
          'monitoring_start': response.monitoringStart.toIso8601String(),
          'monitoring_end': response.monitoringEnd.toIso8601String(),
        },
        'native_session': session.session,
      };
    });
  }

  Future<void> _predictAndSendAnomaly() async {
    if (!_requireBackendBaseUrl()) {
      return;
    }
    if (_logIdController.text.trim().isEmpty || _logIdController.text.trim() == 'log-123') {
      setState(() {
        _status = 'Validation failed';
        _output =
            'Medication log id is missing or still using the placeholder. Run Log Taken + Start Monitoring first.';
      });
      return;
    }

    await _run('Predict and send anomaly', () async {
      final prediction = await _bridge.predictAnomaly(
        medicationLogId: _logIdController.text.trim(),
        snapshot: HealthSnapshot(
          heartRate: 126,
          hrv: 20,
          spo2: 95,
          timestamp: DateTime.now().toUtc(),
          sampleTimestamp: DateTime.now().toUtc(),
          activityState: 'resting',
          source: 'watch',
          sourceDeviceName: 'Apple Watch',
          sourceDeviceModel: 'Watch',
          sourceAppName: 'Health',
        ),
      );

      if (prediction.backendReport != null) {
        await _backendApi.reportAnomaly(
          baseUrl: _baseUrlController.text.trim(),
          accessToken: _accessTokenController.text.trim(),
          backendReport: prediction.backendReport!,
        );
      }

      return {
        'prediction': prediction.prediction,
        'backend_report': prediction.backendReport,
        'sent_to_backend': prediction.backendReport != null,
      };
    });
  }

  Future<void> _run(String label, Future<Object?> Function() action) async {
    setState(() {
      _status = 'Running $label...';
    });

    try {
      final result = await action();
      setState(() {
        _status = '$label completed';
        _output = _formatResult(result);
      });
    } on AppleNativeBridgeException catch (error) {
      setState(() {
        _status = '$label failed';
        _output = '${error.code}\n${error.message}\n${error.details ?? ''}';
      });
    } on SocketException catch (error) {
      setState(() {
        _status = '$label failed';
        _output =
            'Network error\n$label could not reach the backend.\nCheck that:\n1. Backend base URL uses your Mac LAN IP, not 127.0.0.1\n2. iPhone and Mac are on the same Wi-Fi\n3. Backend server is running and listening on port 8000\n\n$error';
      });
    } on HttpException catch (error) {
      setState(() {
        _status = '$label failed';
        _output = 'HTTP error\n$error';
      });
    } on FormatException catch (error) {
      setState(() {
        _status = '$label failed';
        _output = 'Response parse error\n$error';
      });
    } on TimeoutException catch (error) {
      setState(() {
        _status = '$label timed out';
        _output =
            'Request timed out.\nCheck your Backend base URL and whether the backend is reachable from iPhone.\n$error';
      });
    } catch (error) {
      setState(() {
        _status = '$label failed';
        _output = error.toString();
      });
    }
  }

  String _formatResult(Object? value) {
    if (value == null) return 'null';
    return switch (value) {
      OcrResult ocr => 'rawText:\n${ocr.rawText}\n\nlines:\n${ocr.lines.join('\n')}',
      HealthPermissionResponse response =>
        'granted: ${response.granted}\nrequestedAt: ${response.requestedAt.toIso8601String()}',
      HealthSnapshot snapshot =>
        'heartRate: ${snapshot.heartRate}\nhrv: ${snapshot.hrv}\nspo2: ${snapshot.spo2}\nsource: ${snapshot.source}\nsourceDeviceName: ${snapshot.sourceDeviceName ?? '-'}\nsourceDeviceModel: ${snapshot.sourceDeviceModel ?? '-'}\nsourceAppName: ${snapshot.sourceAppName ?? '-'}\nsampleTimestamp: ${snapshot.sampleTimestamp?.toIso8601String() ?? '-'}\ncollectedAt: ${snapshot.timestamp.toIso8601String()}',
      MonitoringSessionResponse session => session.session.toString(),
      BaselineResponse baseline => baseline.baseline.toString(),
      ModelStatusResponse status =>
        'loaded: ${status.loaded}\nmodelName: ${status.modelName}\nmodelVersion: ${status.modelVersion}\nmode: ${status.mode}',
      PredictAnomalyResponse response =>
        'prediction: ${response.prediction}\n\nbackendReport: ${response.backendReport}',
      Map<Object?, Object?> map => map.toString(),
      String text => text,
      _ => value.toString(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediGuard Native Bridge'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Native Status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(_status),
                  const SizedBox(height: 16),
                  SelectableText(_output),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: 'Backend base URL',
              border: OutlineInputBorder(),
              hintText: 'http://127.0.0.1:8000',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accessTokenController,
            decoration: const InputDecoration(
              labelText: 'Access token',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Login email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Login password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _scheduleIdController,
            decoration: const InputDecoration(
              labelText: 'Schedule id',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _scheduleTimeController,
            decoration: const InputDecoration(
              labelText: 'Schedule time',
              border: OutlineInputBorder(),
              hintText: '08:00',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _imagePathController,
            decoration: const InputDecoration(
              labelText: 'OCR image path',
              border: OutlineInputBorder(),
              hintText: 'Use "Pick Image From Photos" on iPhone',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedImageSummary,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _logIdController,
            decoration: const InputDecoration(
              labelText: 'Medication log id',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: _pingBackend,
                child: const Text('Ping Backend'),
              ),
              FilledButton(
                onPressed: _loginToBackend,
                child: const Text('Login'),
              ),
              FilledButton(
                onPressed: _pickImageAndPopulatePath,
                child: const Text('Pick Image From Photos'),
              ),
              FilledButton(
                onPressed: _runNativeOcrAndParseDraft,
                child: const Text('OCR To Draft'),
              ),
              FilledButton(
                onPressed: _createMedicationFromDraft,
                child: const Text('Create Medication'),
              ),
              FilledButton(
                onPressed: _createScheduleForLastMedication,
                child: const Text('Create Schedule'),
              ),
              FilledButton(
                onPressed: _listSchedulesAndSelectLatest,
                child: const Text('List Schedules'),
              ),
              FilledButton(
                onPressed: () => _run(
                  'Health permissions',
                  _bridge.requestHealthPermissions,
                ),
                child: const Text('Request Health Permissions'),
              ),
              FilledButton(
                onPressed: () => _run(
                  'Model status',
                  _bridge.loadModelStatus,
                ),
                child: const Text('Load Model Status'),
              ),
              FilledButton(
                onPressed: () => _run(
                  'Latest snapshot',
                  _bridge.latestSnapshot,
                ),
                child: const Text('Get Latest Snapshot'),
              ),
              FilledButton(
                onPressed: () => _run(
                  'Current baseline',
                  _bridge.currentBaseline,
                ),
                child: const Text('Get Current Baseline'),
              ),
              FilledButton(
                onPressed: () => _run(
                  'Current session',
                  _bridge.currentMonitoringSession,
                ),
                child: const Text('Get Current Session'),
              ),
              FilledButton(
                onPressed: _logTakenAndStartMonitoring,
                child: const Text('Log Taken + Start Monitoring'),
              ),
              FilledButton(
                onPressed: () => _run(
                  'Stop monitoring',
                  _bridge.stopMonitoring,
                ),
                child: const Text('Stop Monitoring'),
              ),
              FilledButton(
                onPressed: _predictAndSendAnomaly,
                child: const Text('Predict + Send Anomaly'),
              ),
              OutlinedButton(
                onPressed: () => _run(
                  'OCR',
                  () => _bridge.recognizeTextFromFile(
                    _imagePathController.text.trim(),
                  ),
                ),
                child: const Text('Run OCR From File'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
