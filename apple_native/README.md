# Apple Native Workspace

This directory contains the Apple-platform-specific implementation for MediGuard.

It is intentionally separated from `backend` and `frontend` so Apple-native services can be built, tested, and versioned independently before or alongside Flutter integration.

## Current status

This package is no longer just a placeholder. The main iOS-native MVP pieces are already implemented and have been exercised through the Flutter iOS runner on a real iPhone.

Currently working:

- Apple Vision OCR on-device
- HealthKit permission requests
- Health snapshot collection for heart rate, HRV, and SpO2
- baseline storage and rolling baseline calculation
- rule-based anomaly prediction
- Flutter bridge contracts for OCR, monitoring, and anomaly prediction
- iOS image picker integration for OCR testing
- source metadata in health snapshots, including:
  - source classification: `watch`, `iphone`, `merged`, `unknown`
  - source device name
  - source device model
  - source app name
  - sample timestamp versus collection timestamp

Important:

- anomaly prediction is currently rule-based, not Core ML yet
- health data is read via HealthKit on iPhone
- Apple Watch data is available when Watch samples have synced into HealthKit
- this is not yet a direct realtime WatchConnectivity streaming pipeline

## Goals

The long-term Apple-native goals remain:

- Apple Vision OCR
- HealthKit integration
- personalized anomaly detection
- optional Core ML anomaly scoring
- WatchConnectivity support
- stable Flutter bridge contracts for iOS

## Structure

```text
apple_native/
  Package.swift
  README.md
  docs/
    SETUP.md
    PERSONALIZED_ANOMALY_DETECTION.md
  Sources/
    AppleNativeKit/
      OCR/
      Health/
      ML/
      Watch/
      Bridge/
      Shared/
```

## Implemented modules

### OCR

- [VisionOCRService.swift](/Users/bachng/Coding/MAIC/apple_native/Sources/AppleNativeKit/OCR/VisionOCRService.swift)

What it does:

- loads image files from a sandbox path
- runs Apple Vision text recognition on-device
- returns:
  - `rawText`
  - `lines`

This is real Apple Vision OCR, not a mock and not a backend OCR flow.

### Health monitoring

- [HealthMonitoringService.swift](/Users/bachng/Coding/MAIC/apple_native/Sources/AppleNativeKit/Health/HealthMonitoringService.swift)
- [BaselineStore.swift](/Users/bachng/Coding/MAIC/apple_native/Sources/AppleNativeKit/Health/BaselineStore.swift)
- [Models.swift](/Users/bachng/Coding/MAIC/apple_native/Sources/AppleNativeKit/Shared/Models.swift)

What it does:

- requests HealthKit read permissions
- reads:
  - heart rate
  - heart rate variability SDNN
  - oxygen saturation
- creates `HealthSnapshot`
- keeps session state for monitoring windows
- appends samples into a rolling baseline store
- returns source metadata so the app can distinguish watch-origin samples from iPhone-origin samples more clearly

### Anomaly prediction

- [AnomalyPredictor.swift](/Users/bachng/Coding/MAIC/apple_native/Sources/AppleNativeKit/ML/AnomalyPredictor.swift)

Current behavior:

- compares latest snapshot against personalized baseline
- uses medically cautious rules for deviations
- returns:
  - `anomaly_level`
  - `anomaly_type`
  - `confidence`
  - `deviations`
  - backend-aligned anomaly report payload

Current limitation:

- this is still rule-based
- `Core ML` scoring is not implemented yet

### Flutter bridge contracts

- [FlutterBridgeContracts.swift](/Users/bachng/Coding/MAIC/apple_native/Sources/AppleNativeKit/Bridge/FlutterBridgeContracts.swift)
- [ChannelNames.swift](/Users/bachng/Coding/MAIC/apple_native/Sources/AppleNativeKit/Shared/ChannelNames.swift)

Bridge coverage includes:

- OCR requests and responses
- image picking support
- health permission requests
- start/stop monitoring
- latest snapshot
- current monitoring session
- current baseline
- anomaly prediction
- model status
- structured error payloads

## Tested integration path

The current validated path is:

1. pick medication image on iPhone
2. run Apple Vision OCR
3. parse OCR into medication draft in Flutter
4. create medication and schedule via backend
5. log taken dose via backend
6. start native monitoring using returned monitoring window
7. read HealthKit snapshots
8. predict anomaly on-device
9. send anomaly payload to backend

## Data source behavior

Health snapshots now expose:

- `timestamp`
  - when the app collected the snapshot
- `sampleTimestamp`
  - when the HealthKit sample itself was recorded
- `source`
  - `watch | iphone | merged | unknown`
- `sourceDeviceName`
  - device name from HealthKit if available
- `sourceDeviceModel`
  - device model from HealthKit if available
- `sourceAppName`
  - Health source/app name if available

This makes it easier to verify whether data came from Apple Watch or from iPhone-local sources.

## Recommended workflow

1. Build reusable native logic inside `AppleNativeKit`
2. Keep Flutter channel names and payload contracts stable
3. Verify contracts and behavior inside the iOS runner in `frontend/ios`
4. Treat the backend as the source of truth for medication, schedule, and anomaly event data

## Related docs

- Setup notes: [SETUP.md](/Users/bachng/Coding/MAIC/apple_native/docs/SETUP.md)
- Personalized anomaly strategy: [PERSONALIZED_ANOMALY_DETECTION.md](/Users/bachng/Coding/MAIC/apple_native/docs/PERSONALIZED_ANOMALY_DETECTION.md)
- Native channel contract: [NATIVE_CHANNEL_API.md](/Users/bachng/Coding/MAIC/shared/contracts/NATIVE_CHANNEL_API.md)
- Frontend handoff: [FRONTEND_INTEGRATION_HANDOFF.md](/Users/bachng/Coding/MAIC/shared/contracts/FRONTEND_INTEGRATION_HANDOFF.md)

## What is still future work

Not finished yet:

- Core ML anomaly scoring layer
- direct WatchConnectivity-based realtime streaming
- more advanced activity and workout context
- production-grade UI integration on the Flutter side
- more extensive automated tests across native/iOS runtime behavior
