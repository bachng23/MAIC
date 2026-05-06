from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.api.deps import get_current_user
from main import app


class _FakeResponse:
    def __init__(self, data):
        self.data = data


class _FakeSingleQuery:
    def __init__(self, db, table_name: str) -> None:
        self.db = db
        self.table_name = table_name
        self.filters: list[tuple[str, object]] = []
        self.update_payload = None

    def select(self, _fields: str):
        return self

    def eq(self, field: str, value):
        self.filters.append((field, value))
        return self

    def order(self, *_args, **_kwargs):
        return self

    def limit(self, _value: int):
        return self

    def insert(self, payload: dict):
        self.db.insert_payloads[self.table_name] = payload
        return self

    def update(self, payload: dict):
        self.update_payload = payload
        self.db.update_payloads[self.table_name] = payload
        return self

    def is_(self, _field: str, _value):
        return self

    def execute(self):
        if self.table_name == "medication_logs":
            return _FakeResponse(self.db.medication_logs)
        if self.table_name == "health_events":
            if self.update_payload is not None:
                return _FakeResponse([{"id": "event-123"}])
            if self.table_name in self.db.insert_payloads:
                return _FakeResponse([{"id": "event-123"}])
            return _FakeResponse(self.db.health_events)
        raise AssertionError(f"Unexpected table: {self.table_name}")


class _FakeSupabase:
    def __init__(self, medication_logs: list[dict], health_events: list[dict] | None = None) -> None:
        self.medication_logs = medication_logs
        self.health_events = health_events or []
        self.insert_payloads: dict[str, dict] = {}
        self.update_payloads: dict[str, dict] = {}

    def table(self, name: str) -> _FakeSingleQuery:
        return _FakeSingleQuery(self, name)


def test_log_taken_response_includes_monitoring_window(monkeypatch) -> None:
    from tests.test_medications import _FakeSupabase as MedicationDb

    fake_db = MedicationDb()
    client = TestClient(app)

    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    response = client.post("/api/v1/logs/taken", json={"schedule_id": "schedule-123"})

    app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["data"]["monitoring_duration_seconds"] == 7200
    assert response.json()["data"]["monitoring_start"]
    assert response.json()["data"]["monitoring_end"]


def test_report_anomaly_rejects_expired_monitoring_window(monkeypatch) -> None:
    client = TestClient(app)
    now = datetime.now(UTC)
    fake_db = _FakeSupabase([
        {
            "id": "log-123",
            "user_id": "user-123",
            "schedule_id": "schedule-123",
            "status": "taken",
            "monitoring_start": (now - timedelta(hours=3)).isoformat(),
            "monitoring_end": (now - timedelta(hours=1)).isoformat(),
        }
    ])

    async def _fake_start_escalation(_event_id: str, _user_id: str) -> None:
        raise AssertionError("Escalation should not start for expired monitoring windows")

    monkeypatch.setattr("app.api.v1.health.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.health.start_escalation", _fake_start_escalation)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    response = client.post(
        "/api/v1/health/anomaly",
        json={
            "medication_log_id": "log-123",
            "anomaly_level": 1,
            "anomaly_type": "high_hr",
            "core_ml_confidence": 0.9,
            "timestamp": now.isoformat(),
        },
    )

    app.dependency_overrides.clear()

    assert response.status_code == 409
    assert response.json()["detail"] == "Monitoring window has ended"


def test_health_status_returns_monitoring_window(monkeypatch) -> None:
    client = TestClient(app)
    now = datetime.now(UTC)
    fake_db = _FakeSupabase(
        [
            {
                "id": "log-123",
                "user_id": "user-123",
                "schedule_id": "schedule-123",
                "status": "taken",
                "monitoring_start": (now - timedelta(minutes=30)).isoformat(),
                "monitoring_end": (now + timedelta(minutes=90)).isoformat(),
            }
        ],
        health_events=[{"anomaly_level": 1, "resolved_at": None}],
    )

    monkeypatch.setattr("app.api.v1.health.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    response = client.get("/api/v1/health/status/log-123")

    app.dependency_overrides.clear()

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["monitoring_active"] is True
    assert data["monitoring_start"]
    assert data["monitoring_end"]
    assert data["alert_level"] == 1
