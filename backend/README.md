# MediGuard Backend

FastAPI backend for MediGuard, an AI-assisted medication and post-dose health monitoring app for elderly users in Taiwan.

## Current status

The backend has been validated end-to-end with the current iOS-native integration on a real iPhone.

Verified flow:

1. Pick medication image on iPhone
2. Run Apple Vision OCR on-device
3. Parse OCR result into a medication draft
4. Optionally fetch drug info from backend
5. Create medication via backend
6. Create schedule via backend
7. Log medication taken via backend
8. Start HealthKit-based monitoring on iPhone
9. Predict anomaly on-device
10. Send anomaly report back to backend

Important notes:

- OCR runs on-device with Apple Vision, not in this backend.
- Drug info lookup is provided by this backend and aggregates OpenFDA plus Taiwan FDA.
- Anomaly prediction currently happens on-device and is still rule-based, not Core ML.
- Apple Watch data is available when Watch samples have synced into HealthKit on iPhone.

## Stack

- FastAPI
- Supabase Auth + PostgreSQL + Storage
- OpenRouter
- OpenFDA
- Taiwan FDA
- APNs

## Project structure

```text
backend/
  app/
    api/         # API routes
    core/        # settings and security
    db/          # Supabase client
    models/      # Pydantic schemas
    services/    # OCR-related parsing hooks, drug info, notifications, emergency
  scripts/
  supabase/
    migration.sql
  tests/
```

## Requirements

- Python 3.12+
- `uv`
- A Supabase project
- An OpenRouter API key
- Apple APNs credentials for push testing

## Environment variables

Create `backend/.env` from `backend/.env.example` and fill in the values.

Required variables:

```env
SUPABASE_URL=
SUPABASE_SERVICE_KEY=

OPENROUTER_API_KEY=

APNS_KEY_ID=
APNS_TEAM_ID=
APNS_BUNDLE_ID=
APNS_KEY_PATH=
APNS_USE_SANDBOX=true

APP_ENV=development
SCHEDULER_ENABLED=true
APP_TIMEZONE=Asia/Taipei
SECRET_KEY=
```

## Install dependencies

```bash
cd /Users/bachng/Coding/MAIC/backend
uv sync
```

## Run database migration

Run the SQL in [supabase/migration.sql](/Users/bachng/Coding/MAIC/backend/supabase/migration.sql:1) once in the Supabase SQL editor.

This migration creates:

- `users`
- `medications`
- `schedules`
- `medication_logs`
- `health_events`
- `alert_logs`

It also enables RLS, creates indexes, and adds a trigger to auto-create `public.users` rows from `auth.users`.

## Run the API

For local desktop-only work:

```bash
cd /Users/bachng/Coding/MAIC/backend
uv run uvicorn main:app --reload
```

For testing from a real iPhone on the same LAN:

```bash
cd /Users/bachng/Coding/MAIC/backend
uv run uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Docs:

- Swagger UI: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- Health check: [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health)

When testing from iPhone, use the Mac LAN IP such as:

```text
http://192.168.1.124:8000
```

Do not use `127.0.0.1` or `localhost` from the phone.

## Seed demo data

From the backend directory:

```bash
uv run python scripts/seed_demo_data.py
```

This creates or refreshes a demo account plus sample medications, schedules, logs, and one active health event.

Demo credentials:

```text
email: demo@mediguard.app
password: DemoPass123!
```

## Core API flows

### Flow A: OCR -> medication

Recommended order:

1. `POST /api/v1/auth/login`
2. `POST /api/v1/medications/drug-info` optionally, after OCR draft exists on-device
3. `POST /api/v1/medications`

Important:

- OCR itself is handled natively on iOS.
- `POST /api/v1/medications/drug-info` is enrichment only.
- Frontend should not block medication creation if drug info lookup is empty or partial.

### Flow B: Taken dose -> monitoring -> anomaly

Recommended order:

1. `POST /api/v1/auth/login`
2. `POST /api/v1/schedules`
3. `POST /api/v1/logs/taken`
4. Native iOS starts monitoring using returned `log_id`, `monitoring_start`, and `monitoring_end`
5. Native iOS predicts anomaly
6. `POST /api/v1/health/anomaly`
7. `GET /api/v1/health/status/{log_id}` optionally for status polling
8. `POST /api/v1/health/resolve` optionally when resolving an alert

For authenticated endpoints, pass:

```text
Authorization: Bearer <access_token>
```

## Key endpoints

### Health check

- `GET /health`

Response:

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

### Drug info lookup

- `POST /api/v1/medications/drug-info`

Request:

```json
{
  "drug_name": "ASPIRIN",
  "drug_name_zh": "痛み・熱に"
}
```

Behavior:

- queries OpenFDA
- queries Taiwan FDA
- merges both into a single `DrugInfo` response
- falls back gracefully if either source is unavailable

This endpoint is intended to prefill:

- `main_effects`
- `warnings`
- `side_effects`
- `elderly_notes`
- `interactions`

It should be treated as optional enrichment, not a hard dependency.

### Create medication

- `POST /api/v1/medications`

Example request:

```json
{
  "name": "ASPIRIN",
  "name_zh": "痛み・熱に",
  "dosage": "30錠"
}
```

### Create schedule

- `POST /api/v1/schedules`

Example request:

```json
{
  "medication_id": "<medication_id>",
  "times": ["08:00"],
  "days_of_week": null
}
```

### Log taken

- `POST /api/v1/logs/taken`

Example request:

```json
{
  "schedule_id": "<schedule_id>"
}
```

Important response fields:

- `log_id`
- `monitoring_start`
- `monitoring_end`
- `monitoring_duration_seconds`

These fields are required by the native iOS monitoring flow.

### Report anomaly

- `POST /api/v1/health/anomaly`

Example request:

```json
{
  "medication_log_id": "<log_id>",
  "anomaly_level": 2,
  "anomaly_type": "high_hr",
  "core_ml_confidence": 0.95,
  "timestamp": "2026-05-06T08:42:00Z"
}
```

Current accepted values:

- `anomaly_level`: `0 | 1 | 2`
- `anomaly_type`: `high_hr | low_spo2 | irregular_hrv | combined`

### Health status

- `GET /api/v1/health/status/{log_id}`

Useful for checking whether monitoring is still active and whether the latest alert has been resolved.

### Resolve alert

- `POST /api/v1/health/resolve`

Useful for marking unresolved health events as resolved.

## Useful scripts

### Seed demo data

```bash
uv run python scripts/seed_demo_data.py
```

### OCR -> drug-info pipeline check

```bash
cd /Users/bachng/Coding/MAIC/backend
uv run python scripts/test_drug_pipeline.py \
  --base-url http://127.0.0.1:8000 \
  --email demo@mediguard.app \
  --password DemoPass123!
```

You can also use environment variables:

```bash
export MEDIGUARD_BASE_URL=http://127.0.0.1:8000
export MEDIGUARD_EMAIL=demo@mediguard.app
export MEDIGUARD_PASSWORD=DemoPass123!
uv run python scripts/test_drug_pipeline.py
```

### OpenFDA debug helper

```bash
cd /Users/bachng/Coding/MAIC/backend
uv run python scripts/debug_openfda.py Aspirin
```

## Tests

Run route and service tests:

```bash
cd /Users/bachng/Coding/MAIC/backend
uv run pytest
```

Relevant recent tests include:

- `tests/test_routes_additional.py`
- `tests/test_drug_agent.py`

## Related docs

- Backend deployment notes: [DEPLOY.md](/Users/bachng/Coding/MAIC/backend/DEPLOY.md:1)
- Frontend handoff: [FRONTEND_INTEGRATION_HANDOFF.md](/Users/bachng/Coding/MAIC/shared/contracts/FRONTEND_INTEGRATION_HANDOFF.md)
- Native channel contract: [NATIVE_CHANNEL_API.md](/Users/bachng/Coding/MAIC/shared/contracts/NATIVE_CHANNEL_API.md)

## Production caveats

Working now:

- auth
- medication CRUD
- schedule CRUD
- taken/skipped logs
- drug info lookup via OpenFDA + Taiwan FDA
- health anomaly reporting
- health status and resolve flows
- APNs token endpoints
- reminder scheduler bootstrap
- basic in-memory rate limiting for sensitive routes

Not fully production-ready yet:

- anomaly prediction is still rule-based on-device
- Apple Watch ingestion is via HealthKit sync, not direct realtime streaming
- escalation still runs in-process
- tests are improving but not yet comprehensive
- some fallback flows still depend on frontend UX quality for best user experience
