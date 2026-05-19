import 'package:flutter/foundation.dart';

/// Frontend-only today's dose confirmations and Meds UI flags (cleared on logout).
class MedicationIntakeController extends ChangeNotifier {
  final Set<String> _confirmedDoseKeys = {};
  final Set<String> _takenMedicationIds = {};
  bool _sideEffectWatchDismissed = false;

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _doseKey(String scheduleId) => '$scheduleId|${_todayKey()}';

  bool isDosePendingToday(String scheduleId) => !_confirmedDoseKeys.contains(_doseKey(scheduleId));

  bool isMedicationTakenToday(String medicationId) => _takenMedicationIds.contains(medicationId);

  bool get showSideEffectWatch => !_sideEffectWatchDismissed;

  void confirmIntake({
    required String scheduleId,
    required String medicationId,
  }) {
    _confirmedDoseKeys.add(_doseKey(scheduleId));
    _takenMedicationIds.add(medicationId);
    notifyListeners();
  }

  void dismissSideEffectWatch() {
    _sideEffectWatchDismissed = true;
    notifyListeners();
  }

  void reset() {
    _confirmedDoseKeys.clear();
    _takenMedicationIds.clear();
    _sideEffectWatchDismissed = false;
    notifyListeners();
  }
}
