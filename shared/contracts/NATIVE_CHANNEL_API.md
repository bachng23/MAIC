# Native Channel API

This document locks the iOS-native MVP contract between Flutter and Apple-native Swift services.

## Channels

### `com.mediguard/vision_ocr`

Methods:

- `recognizeTextFromImage`
- `recognizeTextFromFile`

Request:

```json
{
  "image_path": "/absolute/path/to/photo.jpg"
}
```

Success response:

```json
{
  "lines": [
    "Panadol 500mg",
    "Take twice daily"
  ],
  "raw_text": "Panadol 500mg\nTake twice daily"
}
```

### `com.mediguard/health_monitor`

Methods:

- `requestHealthPermissions`
- `startMonitoring`
- `stopMonitoring`
- `getLatestHealthSnapshot`
- `getCurrentMonitoringSession`
- `getCurrentBaseline`

`startMonitoring` request:

```json
{
  "log_id": "log-123",
  "start": "2026-05-06T08:00:00Z",
  "end": "2026-05-06T10:00:00Z",
  "medication_name": "Panadol",
  "medication_category": "analgesic"
}
```

`getLatestHealthSnapshot` response:

```json
{
  "snapshot": {
    "heart_rate": 94.0,
    "hrv": 32.0,
    "spo2": 97.0,
    "timestamp": "2026-05-06T08:30:00Z",
    "activity_state": "resting",
    "source": "watch"
  }
}
```

### `com.mediguard/core_ml`

Methods:

- `predictAnomaly`
- `loadModelStatus`

`predictAnomaly` request:

```json
{
  "medication_log_id": "log-123",
  "snapshot": {
    "heart_rate": 128.0,
    "hrv": 18.0,
    "spo2": 95.0,
    "timestamp": "2026-05-06T08:42:00Z",
    "activity_state": "resting",
    "source": "watch"
  }
}
```

`predictAnomaly` response:

```json
{
  "prediction": {
    "medication_log_id": "log-123",
    "anomaly_level": 2,
    "anomaly_type": "high_hr",
    "confidence": 0.95,
    "timestamp": "2026-05-06T08:42:00Z",
    "deviations": [
      {
        "signal": "heart_rate",
        "current_value": 128.0,
        "baseline_median": 82.0,
        "delta": 46.0,
        "percent_delta": 56.1
      }
    ],
    "baseline_status": "ready"
  },
  "backend_report": {
    "medication_log_id": "log-123",
    "anomaly_level": 2,
    "anomaly_type": "high_hr",
    "core_ml_confidence": 0.95,
    "timestamp": "2026-05-06T08:42:00Z"
  }
}
```

`loadModelStatus` response:

```json
{
  "loaded": true,
  "model_name": "RuleBasedAnomalyPredictor",
  "model_version": "mvp-1",
  "mode": "rule_based"
}
```

## Error contract

Native handlers return `FlutterError` with:

- `code`: stable short code such as `vision_ocr_error`
- `message`: human-readable summary
- `details`: a structured payload using this schema

```json
{
  "code": "start_monitoring_error",
  "message": "Failed to start health monitoring",
  "details": "permissionsNotRequested",
  "timestamp": "2026-05-06T08:00:00Z"
}
```

## Backend handoff

When `backend_report` is non-null, Flutter can send it directly to:

- `POST /api/v1/health/anomaly`

Current backend-compatible values:

- `anomaly_level`: `0 | 1 | 2`
- `anomaly_type`: `high_hr | low_spo2 | irregular_hrv | combined`
