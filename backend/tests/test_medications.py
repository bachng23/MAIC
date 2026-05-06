from datetime import UTC, datetime

from fastapi.testclient import TestClient

from app.api.deps import get_current_user
from main import app


class _FakeResponse:
    def __init__(self, data):
        self.data = data


class _FakeQuery:
    def __init__(self, table_name: str, db) -> None:
        self.table_name = table_name
        self.db = db
        self.filters: list[tuple[str, object]] = []
        self.insert_payload = None
        self.update_payload = None

    def select(self, _fields: str):
        return self

    def eq(self, field: str, value):
        self.filters.append((field, value))
        return self

    def insert(self, payload: dict):
        self.insert_payload = payload
        self.db.insert_payloads[self.table_name] = payload
        return self

    def update(self, payload: dict):
        self.update_payload = payload
        self.db.update_payloads[self.table_name] = payload
        return self

    def execute(self):
        if self.table_name == "medications":
            medication_id = dict(self.filters).get("id")
            if medication_id == "med-123":
                return _FakeResponse([{"id": "med-123"}])
            return _FakeResponse([])

        if self.table_name == "schedules":
            if self.insert_payload is not None:
                return _FakeResponse([{
                    "id": "schedule-123",
                    "user_id": "user-123",
                    "medication_id": self.insert_payload["medication_id"],
                    "times": self.insert_payload["times"],
                    "days_of_week": self.insert_payload.get("days_of_week"),
                    "is_active": True,
                }])
            return _FakeResponse([{
                "id": "schedule-123",
                "user_id": "user-123",
                "medication_id": "med-123",
                "times": ["08:00"],
                "days_of_week": [1, 3, 5],
                "is_active": True,
            }])

        if self.table_name == "medication_logs":
            return _FakeResponse([{"id": "log-123"}])

        raise AssertionError(f"Unexpected table: {self.table_name}")


class _FakeSupabase:
    def __init__(self) -> None:
        self.insert_payloads: dict[str, dict] = {}
        self.update_payloads: dict[str, dict] = {}

    def table(self, name: str) -> _FakeQuery:
        return _FakeQuery(name, self)


def test_create_schedule_rejects_medication_outside_user_scope(monkeypatch) -> None:
    fake_db = _FakeSupabase()
    client = TestClient(app)

    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    response = client.post(
        "/api/v1/schedules",
        json={
            "medication_id": "someone-elses-medication",
            "times": ["08:00"],
            "days_of_week": [1, 3, 5],
        },
    )

    app.dependency_overrides.clear()

    assert response.status_code == 404
    assert response.json()["detail"] == "Medication not found"


def test_log_taken_persists_scheduled_at(monkeypatch) -> None:
    fake_db = _FakeSupabase()
    client = TestClient(app)
    scheduled_at = datetime(2026, 5, 6, 8, 0, tzinfo=UTC)

    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    response = client.post(
        "/api/v1/logs/taken",
        json={
            "schedule_id": "schedule-123",
            "scheduled_at": scheduled_at.isoformat(),
        },
    )

    app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["data"]["log_id"] == "log-123"
    assert fake_db.insert_payloads["medication_logs"]["scheduled_at"] == scheduled_at.isoformat()


def test_create_schedule_refreshes_scheduler_jobs(monkeypatch) -> None:
    fake_db = _FakeSupabase()
    client = TestClient(app)
    refresh_calls = {"count": 0}

    async def _fake_refresh_schedule_jobs() -> None:
        refresh_calls["count"] += 1

    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.medications.refresh_schedule_jobs", _fake_refresh_schedule_jobs)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    response = client.post(
        "/api/v1/schedules",
        json={
            "medication_id": "med-123",
            "times": ["08:00", "20:00"],
            "days_of_week": [1, 3, 5],
        },
    )

    app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["data"]["id"] == "schedule-123"
    assert refresh_calls["count"] == 1


def test_delete_schedule_refreshes_scheduler_jobs(monkeypatch) -> None:
    fake_db = _FakeSupabase()
    client = TestClient(app)
    refresh_calls = {"count": 0}

    async def _fake_refresh_schedule_jobs() -> None:
        refresh_calls["count"] += 1

    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.medications.refresh_schedule_jobs", _fake_refresh_schedule_jobs)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    response = client.delete("/api/v1/schedules/schedule-123")

    app.dependency_overrides.clear()

    assert response.status_code == 200
    assert fake_db.update_payloads["schedules"] == {"is_active": False}
    assert refresh_calls["count"] == 1
