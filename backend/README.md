# MediGuard Backend

FastAPI backend for MediGuard, an AI-assisted medication and health monitoring app for elderly users in Taiwan.

## Stack

- FastAPI
- Supabase Auth + PostgreSQL + Storage
- OpenRouter
- OpenFDA
- Taiwan FDA
- APNs

## Project Structure

```text
backend/
  app/
    api/         # API routes
    core/        # settings and security
    db/          # Supabase client
    models/      # Pydantic schemas
    services/    # OCR, drug info, notifications, emergency
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

## Environment Variables

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

## Install Dependencies

```bash
cd /Users/bachng/Coding/MAIC/backend
uv sync
```

## Run Database Migration

Run the SQL in [supabase/migration.sql](/Users/bachng/Coding/MAIC/backend/supabase/migration.sql:1) once in the Supabase SQL editor.

This migration creates:

- `users`
- `medications`
- `schedules`
- `medication_logs`
- `health_events`
- `alert_logs`

It also enables RLS, creates indexes, and adds a trigger to auto-create `public.users` rows from `auth.users`.

## Run The API

```bash
cd /Users/bachng/Coding/MAIC/backend
uv run uvicorn main:app --reload
```

Docs:

- Swagger UI: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- Health check: [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health)

## Seed Demo Data

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

## Deploy Readiness

Deployment notes and production checklist are in [DEPLOY.md](/Users/bachng/Coding/MAIC/backend/DEPLOY.md:1).

## Week 1 Smoke Test

Recommended order:

1. `POST /api/v1/auth/register`
2. `POST /api/v1/auth/login`
3. `POST /api/v1/medications/scan`
4. `POST /api/v1/medications/drug-info`
5. `POST /api/v1/medications`
6. `GET /api/v1/medications`
7. `POST /api/v1/schedules`
8. `GET /api/v1/schedules`
9. `GET /api/v1/auth/apns-status`

For authenticated endpoints, pass:

```text
Authorization: Bearer <access_token>
```

## Quick OCR Test

There is a simple service-level OCR test script:

```bash
cd /Users/bachng/Coding/MAIC/backend
PYTHONPATH=. python3 tests/test_ocr.py
```

Optional custom image:

```bash
cd /Users/bachng/Coding/MAIC/backend
PYTHONPATH=. python3 tests/test_ocr.py /absolute/path/to/image.jpg
```

## Current Scope

Implemented now:

- Auth endpoints
- OCR scan endpoint
- Drug info endpoint
- Medication CRUD
- Schedule CRUD
- Medication taken/skipped logs
- Health anomaly reporting
- Emergency contacts CRUD
- APNs push helpers
- Reminder scheduler bootstrapping and schedule sync
- APNs status inspection endpoint
- Basic in-memory rate limiting for sensitive routes

Not fully production-ready yet:

- Reminder scheduler is not wired up yet
- Escalation currently runs in-process
- Automated tests are still minimal
- Rate limiting is not implemented
