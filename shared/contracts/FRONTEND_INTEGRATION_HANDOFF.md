# Frontend Integration Handoff

This document is the handoff summary for frontend integration against the current MediGuard backend and iOS-native bridge.

## Current status

The end-to-end integration has been verified on a real iPhone for this flow:

1. Pick image from Photos
2. Run Apple Vision OCR on-device
3. Parse OCR text into a medication draft
4. Create medication via backend
5. Create schedule via backend
6. Log medication taken via backend
7. Start native health monitoring
8. Predict anomaly
9. Send anomaly report to backend

Notes:

- OCR uses Apple Vision and runs on-device.
- Health monitoring uses HealthKit on iPhone.
- Apple Watch data is available when Watch samples have synced into HealthKit.
- Anomaly prediction is currently rule-based, not Core ML.

## Integration paths

There are two integration surfaces:

1. Backend HTTP API
2. iOS native method channels

Backend HTTP should be treated as the source of truth for app data.
The iOS native bridge should be treated as the source of truth for OCR and Apple health access.

## Recommended flow

### Flow A: Scan medication image -> create medication

1. Pick image on device
2. Call native OCR
3. Parse OCR text into a draft
4. Let user review/edit the draft
5. Call backend `POST /api/v1/medications`

### Flow B: Take dose -> start monitoring -> send anomaly

1. Ensure user is logged in
2. Ensure a `schedule_id` exists
3. Call backend `POST /api/v1/logs/taken`
4. Read `log_id`, `monitoring_start`, `monitoring_end`
5. Call native `startMonitoring`
6. Later call native `predictAnomaly`
7. If `backend_report` is non-null, send it to backend `POST /api/v1/health/anomaly`

## Backend endpoints used

### Health check

- `GET /health`

Expected response:

```json
{
  "status": "ok"
}
```

### Login

- `POST /api/v1/auth/login`

Request:

```json
{
  "email": "demo@mediguard.app",
  "password": "DemoPass123!"
}
```

Response:

```json
{
  "data": {
    "access_token": "<jwt>"
  }
}
```

### Create medication

- `POST /api/v1/medications`

Authorization:

- `Bearer <access_token>`

Request:

```json
{
  "name": "ASPIRIN",
  "name_zh": "痛み・熱に",
  "dosage": "30錠"
}
```

Response:

```json
{
  "data": {
    "id": "<medication_id>",
    "name": "ASPIRIN",
    "name_zh": "痛み・熱に",
    "dosage": "30錠"
  }
}
```

### Create schedule

- `POST /api/v1/schedules`

Authorization:

- `Bearer <access_token>`

Request:

```json
{
  "medication_id": "<medication_id>",
  "times": ["08:00"],
  "days_of_week": null
}
```

Response:

```json
{
  "data": {
    "id": "<schedule_id>",
    "medication_id": "<medication_id>",
    "times": ["08:00"],
    "days_of_week": null
  }
}
```

### List schedules

- `GET /api/v1/schedules`

Authorization:

- `Bearer <access_token>`

Response:

```json
{
  "data": [
    {
      "id": "<schedule_id>",
      "medication_id": "<medication_id>",
      "times": ["08:00"],
      "days_of_week": null
    }
  ]
}
```

### Log medication taken

- `POST /api/v1/logs/taken`

Authorization:

- `Bearer <access_token>`

Request:

```json
{
  "schedule_id": "<schedule_id>"
}
```

Response:

```json
{
  "data": {
    "log_id": "<log_id>",
    "monitoring_start": "2026-05-06T08:00:00Z",
    "monitoring_end": "2026-05-06T10:00:00Z",
    "monitoring_duration_seconds": 7200
  }
}
```

Important:

- `log_id` is required later for native monitoring and anomaly reporting.
- `monitoring_start` and `monitoring_end` must be passed into native `startMonitoring`.

### Send anomaly report

- `POST /api/v1/health/anomaly`

Authorization:

- `Bearer <access_token>`

Request:

```json
{
  "medication_log_id": "<log_id>",
  "anomaly_level": 2,
  "anomaly_type": "high_hr",
  "core_ml_confidence": 0.95,
  "timestamp": "2026-05-06T08:42:00Z"
}
```

Allowed values:

- `anomaly_level`: `0 | 1 | 2`
- `anomaly_type`: `high_hr | low_spo2 | irregular_hrv | combined`

## Native method channels

See full contract here:

- [NATIVE_CHANNEL_API.md](/Users/bachng/Coding/MAIC/shared/contracts/NATIVE_CHANNEL_API.md)

### OCR channel

- channel: `com.mediguard/vision_ocr`
- important methods:
  - `pickImageFromLibrary`
  - `recognizeTextFromFile`

`recognizeTextFromFile` request:

```json
{
  "image_path": "/sandbox/path/to/file.webp"
}
```

Success response:

```json
{
  "raw_text": "ASPIRIN\n30錠\n1回1錠",
  "lines": ["ASPIRIN", "30錠", "1回1錠"]
}
```

### Health monitoring channel

- channel: `com.mediguard/health_monitor`
- important methods:
  - `requestHealthPermissions`
  - `startMonitoring`
  - `stopMonitoring`
  - `getLatestHealthSnapshot`
  - `getCurrentMonitoringSession`
  - `getCurrentBaseline`

`startMonitoring` request:

```json
{
  "log_id": "<log_id>",
  "start": "2026-05-06T08:00:00Z",
  "end": "2026-05-06T10:00:00Z",
  "medication_name": "ASPIRIN"
}
```

`getLatestHealthSnapshot` response:

```json
{
  "snapshot": {
    "heart_rate": 94.0,
    "hrv": 32.0,
    "spo2": 97.0,
    "timestamp": "2026-05-06T08:30:05.000Z",
    "sample_timestamp": "2026-05-06T08:29:42.000Z",
    "activity_state": "unknown",
    "source": "watch",
    "source_device_name": "Apple Watch",
    "source_device_model": "Watch",
    "source_app_name": "Health"
  }
}
```

Field meanings:

- `timestamp`: when the app collected the snapshot
- `sample_timestamp`: when the HealthKit sample itself was recorded
- `source`: `watch | iphone | merged | unknown`
- `source_device_name`: device name from HealthKit if available
- `source_device_model`: device model from HealthKit if available
- `source_app_name`: originating Health source if available

### Anomaly prediction channel

- channel: `com.mediguard/core_ml`
- important methods:
  - `predictAnomaly`
  - `loadModelStatus`

`predictAnomaly` request:

```json
{
  "medication_log_id": "<log_id>",
  "snapshot": {
    "heart_rate": 126.0,
    "hrv": 20.0,
    "spo2": 95.0,
    "timestamp": "2026-05-06T08:42:00Z",
    "activity_state": "resting",
    "source": "watch"
  }
}
```

Response:

```json
{
  "prediction": {
    "medication_log_id": "<log_id>",
    "anomaly_level": 2,
    "anomaly_type": "high_hr",
    "confidence": 0.95,
    "timestamp": "2026-05-06T08:42:00Z",
    "deviations": [
      {
        "signal": "heart_rate",
        "current_value": 126.0,
        "baseline_median": 82.0,
        "delta": 44.0,
        "percent_delta": 53.7
      }
    ],
    "baseline_status": "ready"
  },
  "backend_report": {
    "medication_log_id": "<log_id>",
    "anomaly_level": 2,
    "anomaly_type": "high_hr",
    "core_ml_confidence": 0.95,
    "timestamp": "2026-05-06T08:42:00Z"
  }
}
```

Important:

- `backend_report` is already backend-aligned and can be sent directly to `/api/v1/health/anomaly`.
- despite the channel name `core_ml`, the current implementation is still rule-based.

## Known constraints

### OCR

- OCR is iOS-only and Apple-native.
- The frontend should not expect the Windows developer machine to run Apple Vision locally.
- The frontend integration should treat OCR as an iOS capability.

### Health data

- Health data is read through HealthKit on iPhone.
- Apple Watch data is available when samples have synced into HealthKit.
- This is not a direct realtime WatchConnectivity stream.

### Permissions

- Health monitoring requires `requestHealthPermissions` first.
- Photo-based OCR requires photo library access.

### Networking on iPhone during local development

- Do not use `127.0.0.1` or `localhost` from the phone.
- Use the Mac LAN IP, for example `http://192.168.1.124:8000`.
- Backend should run with:

```bash
uv run uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## Frontend implementation checklist

1. Implement backend auth and store `access_token`
2. Implement medication draft review UI
3. Implement create medication
4. Implement create schedule or choose existing schedule
5. Implement `log taken`
6. Pass `log_id`, `monitoring_start`, and `monitoring_end` into native `startMonitoring`
7. Read native snapshot/session state when needed
8. Call `predictAnomaly`
9. Forward `backend_report` to `/api/v1/health/anomaly`

## Current recommendation

Frontend can start integration now.

The backend-facing flow is stable enough for implementation, with these caveats:

- anomaly prediction is still rule-based
- health monitoring is HealthKit-based, not direct watch streaming
- OCR and Health features are iOS-native and should be abstracted behind platform-specific interfaces
