import 'package:flutter/foundation.dart';

import '../../shared/data/mediguard_api_service.dart';
import '../../shared/models/api_models.dart';

class HealthController extends ChangeNotifier {
  HealthController(this._api);

  final MediGuardApiService _api;

  bool isLoading = false;
  String? error;
  HealthStatus? status;

  Future<void> getStatus(String logId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      status = await _api.getHealthStatus(logId);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reportTestAnomaly(String logId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _api.reportAnomaly(
        AnomalyReport(
          medicationLogId: logId,
          anomalyLevel: AnomalyLevel.medium,
          anomalyType: AnomalyType.combined,
          coreMlConfidence: 0.78,
          timestamp: DateTime.now().toUtc(),
        ),
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resolve(String logId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _api.resolveAlert(ResolveRequest(logId: logId));
      status = await _api.getHealthStatus(logId);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
