# Setup Notes

## Purpose

This package is a staging area for Apple-native logic before it is integrated into the Flutter iOS runner.

## Suggested Integration Path

1. Develop shared native services in this package.
2. Validate interfaces and models here first.
3. Move or link the code into `frontend/ios` when the Flutter app is ready to consume it.

## Native Modules

- `OCR/VisionOCRService.swift`
- `Health/HealthMonitoringService.swift`
- `ML/AnomalyPredictor.swift`
- `Watch/WatchSessionManager.swift`
- `Bridge/FlutterBridgeContracts.swift`

## Constraints

- Build and runtime verification still require Xcode on macOS.
- HealthKit, Vision, and WatchConnectivity cannot be fully exercised on Windows.
