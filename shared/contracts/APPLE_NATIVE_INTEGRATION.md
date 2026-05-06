# Apple Native Integration Plan

## Purpose

This document defines the iOS-native part of MediGuard that cannot be implemented fully from Windows-only Flutter development.

It covers:

- Apple Vision OCR for medication scanning
- HealthKit data access for Apple Watch / iPhone health signals
- Core ML anomaly detection on-device
- Flutter to Swift integration via Platform Channels

The goal is to keep privacy-sensitive processing on-device and let the backend focus on storage, monitoring state, and escalation.

## Why This Part Must Be Native

Some key capabilities are Apple-platform specific:

- `Vision` / `VisionKit` for high-quality OCR on iOS
- `HealthKit` for heart rate, HRV, and SpO2 access
- `Core ML` for on-device anomaly prediction
- `WatchConnectivity` for iPhone and Apple Watch coordination
- native push / silent push handling for emergency workflows

Flutter remains the main app shell, but Swift must own the Apple framework bridge.

## High-Level Direction

The product should follow a `Flutter UI + Swift native services + backend orchestration` model.

Responsibilities:

- Flutter:
  - UI
  - navigation
  - state management
  - API calls to backend
  - user-facing medication and monitoring screens

- Swift:
  - OCR using Apple Vision
  - HealthKit read access
  - Core ML inference
  - Watch-related native integration
  - exposing native functions to Flutter through Platform Channels

- Backend:
  - auth
  - medication storage
  - schedule storage
  - monitoring window lifecycle
  - anomaly logging
  - escalation logic

## Core Principle

Raw health data should stay on-device whenever possible.

Recommended data flow:

- Apple Watch / iPhone collects health data
- Swift processes and transforms it
- Core ML predicts anomaly locally
- Flutter sends only anomaly result to backend

This keeps the architecture aligned with the original privacy-first design.

## Target Outcome

The target for this module is:

1. OCR works fully on-device using Apple Vision.
2. The app can start a medication monitoring session after `POST /logs/taken`.
3. HealthKit can read the required signals during the monitoring window.
4. Core ML can classify simple anomaly levels on-device.
5. Flutter can send structured anomaly results to backend through the existing `/health/anomaly` API.

## Native Modules To Build

### 1. OCR Module

**Purpose**

Extract raw medication text from camera images on-device.

**Technology**

- `Vision`
- optional `VisionKit` for document scanning UX

**Output**

- raw recognized text
- optional grouped lines / blocks
- optional confidence metadata

**Backend relationship**

- Flutter can send OCR result to backend for parsing or enrichment
- or use the OCR result directly to populate medication draft fields

### 2. Health Monitoring Module

**Purpose**

Read health signals after a medication intake event.

**Technology**

- `HealthKit`
- possibly `HKObserverQuery`, `HKSampleQuery`, or anchored queries

**Initial signals**

- heart rate
- HRV
- SpO2

**Monitoring trigger**

- starts after backend returns `log_id`, `monitoring_start`, and `monitoring_end`

### 3. Core ML Anomaly Module

**Purpose**

Run anomaly prediction on-device from HealthKit-derived features.

**Technology**

- `Core ML`
- optional preprocessing in Swift before model inference

**Expected output**

- `anomaly_level`
  - `0 = normal`
  - `1 = warning`
  - `2 = critical`
- `anomaly_type`
  - `high_hr`
  - `low_spo2`
  - `irregular_hrv`
  - `combined`
- `core_ml_confidence`
- timestamp

### 4. Watch / Native Coordination Module

**Purpose**

Coordinate watch-originated signals and native device actions.

**Technology**

- `WatchConnectivity`
- native iOS app lifecycle handling

**Later optional responsibilities**

- support silent push actions
- trigger native emergency UX flows

## Recommended Flutter Platform Channels

The Flutter app should talk to Swift using stable channel names.

### OCR Channel

```text
com.mediguard/vision_ocr
```

Suggested methods:

- `recognizeTextFromImage`
- `recognizeTextFromFile`

### Health Monitoring Channel

```text
com.mediguard/health_monitor
```

Suggested methods:

- `requestHealthPermissions`
- `startMonitoring`
- `stopMonitoring`
- `getLatestHealthSnapshot`

### Core ML Channel

```text
com.mediguard/core_ml
```

Suggested methods:

- `predictAnomaly`
- `loadModelStatus`

### Emergency Channel

```text
com.mediguard/emergency
```

Suggested methods:

- `handleSilentPushAction`
- `openEmergencyCall`
- `openCheckOnContactFlow`

## Recommended End-to-End Flow

### OCR Flow

1. Flutter captures or selects image.
2. Flutter calls native OCR channel.
3. Swift returns recognized text.
4. Flutter sends parsed content or medication name to backend.
5. Flutter presents medication draft for user confirmation.

### Monitoring Flow

1. User confirms `Taken`.
2. Flutter calls `POST /api/v1/logs/taken`.
3. Backend returns:
   - `log_id`
   - `monitoring_start`
   - `monitoring_end`
4. Flutter calls Swift `startMonitoring`.
5. Swift reads HealthKit signals during active window.
6. Swift runs Core ML prediction.
7. Flutter sends anomaly result to `POST /api/v1/health/anomaly`.
8. Backend handles logging and escalation.

## Backend Contract Already Available

The backend is already prepared for the on-device ML architecture.

Relevant endpoints:

- `POST /api/v1/logs/taken`
- `POST /api/v1/health/anomaly`
- `GET /api/v1/health/status/{log_id}`
- `POST /api/v1/health/resolve`

Expected anomaly payload:

```json
{
  "medication_log_id": "uuid",
  "anomaly_level": 1,
  "anomaly_type": "high_hr",
  "core_ml_confidence": 0.92,
  "timestamp": "2026-05-06T10:00:00+00:00"
}
```

## MVP Implementation Order

Recommended build order:

1. Apple Vision OCR
2. HealthKit permission and heart-rate read
3. mock anomaly classification in Swift
4. wire `/logs/taken -> startMonitoring -> /health/anomaly`
5. replace mock anomaly logic with Core ML model
6. expand to HRV and SpO2

This order reduces integration risk and gives a demoable flow early.

## Team Split Recommendation

### Flutter Developer

- build screens
- build medication flow UI
- build monitoring status UI
- integrate backend APIs
- consume Platform Channel responses

### iOS Native Developer

- write Swift bridge code
- implement Vision OCR
- implement HealthKit access
- implement Core ML runner
- implement watch-facing native integration

## Success Criteria

This module is successful when:

- OCR works on a real iPhone
- medication intake can start monitoring
- heart-rate data can be read after intake
- Core ML emits anomaly results locally
- backend receives anomaly payload and updates monitoring state correctly

## Non-Goals For The First Iteration

- full raw health-data upload to backend
- backend-hosted anomaly ML
- perfect watch streaming infrastructure
- advanced multilingual OCR correction

## Summary

The correct near-term architecture is:

- `Flutter` for app flow
- `Swift` for Apple-only capabilities
- `Core ML` and `Vision` on-device
- backend only for coordination and escalation

This is both technically practical and aligned with the original product vision.
