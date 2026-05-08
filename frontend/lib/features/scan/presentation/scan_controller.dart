import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../shared/data/mediguard_api_service.dart';
import '../../shared/models/api_models.dart';

class ScanController extends ChangeNotifier {
  ScanController(this._api);

  final MediGuardApiService _api;

  bool isLoading = false;
  String? error;
  OCRScanResult? scanResult;
  DrugInfo? drugInfo;
  MedicationOut? createdMedication;

  Future<void> scanAndCreateMedication(File imageFile) async {
    isLoading = true;
    error = null;
    scanResult = null;
    drugInfo = null;
    createdMedication = null;
    notifyListeners();
    try {
      final bytes = await imageFile.readAsBytes();
      final imageBase64 = base64Encode(bytes);
      final scanned = await _api.scanMedication(OCRScanRequest(imageBase64: imageBase64));
      scanResult = scanned;

      final info = await _api.fetchDrugInfo(
        DrugInfoRequest(drugName: scanned.name, drugNameZh: scanned.nameZh),
      );
      drugInfo = info;

      createdMedication = await _api.createMedication(
        MedicationCreate(
          name: scanned.name,
          nameZh: scanned.nameZh,
          dosage: scanned.dosage,
          sourceImageUrl: scanned.sourceImageUrl,
          drugInfo: info,
        ),
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
