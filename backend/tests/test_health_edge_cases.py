"""Edge-case tests for the /health endpoints."""

from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.api.deps import get_current_user
from main import app


# ---------------------------------------------------------------------------
# Shared fake infrastructure (mirrors test_health.py pattern)
# ---------------------------------------------------------------------------

class _FakeResponse:
    def __init__(self, data):
        self.data = data


class _FakeSingleQuery:
    def __init__(self, db, table_name: str) -> None:
        self.db = db
        self.table_name = table_name
        self.update_payload = None
        self._is_insert = False

    def select(self, _fields: str):
        return self

    def eq(self, _field: str, _value):
        return self

    def order(self, *_args, **_kwargs):
        return self

    def limit(self, _value: int):
        return self

    def insert(self, payload: dict):
        self._is_insert = True
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
            if self._is_insert:
                return _FakeResponse([{"id": "event-123"}])
            return _FakeResponse(self.db.health_events)
        raise AssertionError(f"Unexpected table: {self.table_name}")


class _FakeSupabase:
    def __init__(
        self,
        medication_logs: list[dict],
        health_events: list[dict] | None = None,
    ) -> None:
        self.medication_logs = medication_logs
        self.health_events = health_events or []
        self.insert_payloads: dict[str, dict] = {}
        self.update_payloads: dict[str, dict] = {}

    def table(self, name: str) -> _FakeSingleQuery:
        return _FakeSingleQuery(self, name)


# ---------------------------------------------------------------------------
# 1. test_anomaly_report_outside_monitoring_window_rejected
# ---------------------------------------------------------------------------

def test_anomaly_report_outside_monitoring_window_rejected(monkeypatch) -> None:
    """Reporting an anomaly whose timestamp is past monitoring_end returns 409."""
    client = TestClient(app)
    now = datetime.now(UTC)

    fake_db = _FakeSupabase([
        {
            "id": "log-expired",
            "user_id": "user-123",
            "schedule_id": "sched-1",
            "status": "taken",
            "monitoring_start": (now - timedelta(hours=3)).isoformat(),
            "monitoring_end": (now - timedelta(hours=1)).isoformat(),  # ended 1 hour ago
        }
    ])

    async def _no_escalation(*_args, **_kwargs):
        raise AssertionError("Escalation must not start for an expired monitoring window")

    monkeypatch.setattr("app.api.v1.health.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.health.start_escalation", _no_escalation)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    response = client.post(
        "/api/v1/health/anomaly",
        json={
            "medication_log_id": "log-expired",
            "anomaly_level": 1,
            "anomaly_type": "high_hr",
            "core_ml_confidence": 0.9,
            "timestamp": now.isoformat(),  # now > monitoring_end
        },
    )

    app.dependency_overrides.clear()

    assert response.status_code == 409
    assert response.json()["detail"] == "Monitoring window has ended"


# ---------------------------------------------------------------------------
# 2. test_anomaly_report_with_invalid_log_id_returns_404
# ---------------------------------------------------------------------------

def test_anomaly_report_with_invalid_log_id_returns_404(monkeypatch) -> None:
    """Reporting an anomaly for a non-existent medication_log_id returns 404."""
    client = TestClient(app)
    now = datetime.now(UTC)

    # Empty medication_logs — the log_id won't be found
    fake_db = _FakeSupabase(medication_logs=[])

    async def _no_escalation(*_args, **_kwargs):
        raise AssertionError("Escalation must not start for a missing log")

    monkeypatch.setattr("app.api.v1.health.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.health.start_escalation", _no_escalation)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    response = client.post(
        "/api/v1/health/anomaly",
        json={
            "medication_log_id": "nonexistent-log-id",
            "anomaly_level": 1,
            "anomaly_type": "high_hr",
            "core_ml_confidence": 0.8,
            "timestamp": now.isoformat(),
        },
    )

    app.dependency_overrides.clear()

    assert response.status_code == 404
    assert response.json()["detail"] == "Medication log not found"


# ---------------------------------------------------------------------------
# 3. test_health_status_returns_monitoring_window_times
# ---------------------------------------------------------------------------

def test_health_status_returns_monitoring_window_times(monkeypatch) -> None:
    """GET /health/status/{log_id} includes monitoring_start and monitoring_end in the response."""
    client = TestClient(app)
    now = datetime.now(UTC)

    start = (now - timedelta(minutes=20)).isoformat()
    end = (now + timedelta(hours=1, minutes=40)).isoformat()

    fake_db = _FakeSupabase(
        [
            {
                "id": "log-window",
                "user_id": "user-123",
                "schedule_id": "sched-win",
                "status": "taken",
                "monitoring_start": start,
                "monitoring_end": end,
            }
        ],
        health_events=[],
    )

    monkeypatch.setattr("app.api.v1.health.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    response = client.get("/api/v1/health/status/log-window")

    app.dependency_overrides.clear()

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["monitoring_start"] is not None, "monitoring_start should be present"
    assert data["monitoring_end"] is not None, "monitoring_end should be present"
    assert data["monitoring_active"] is True


# ---------------------------------------------------------------------------
# 4. test_anomaly_level_critical_sets_alert_level_2
# ---------------------------------------------------------------------------

def test_anomaly_level_critical_sets_alert_level_2(monkeypatch) -> None:
    """Reporting a level=2 (CRITICAL) anomaly stores anomaly_level=2 in health_events
    and the subsequent GET /health/status returns alert_level=2."""
    client = TestClient(app)
    now = datetime.now(UTC)

    fake_db = _FakeSupabase(
        [
            {
                "id": "log-critical",
                "user_id": "user-123",
                "schedule_id": "sched-crit",
                "status": "taken",
                "monitoring_start": (now - timedelta(minutes=5)).isoformat(),
                "monitoring_end": (now + timedelta(hours=2)).isoformat(),
            }
        ],
        health_events=[{"id": "event-critical", "anomaly_level": 2, "resolved_at": None}],
    )

    async def _noop_escalation(_event_id: str, _user_id: str) -> None:
        pass

    monkeypatch.setattr("app.api.v1.health.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.health.start_escalation", _noop_escalation)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    # POST a CRITICAL anomaly
    post_response = client.post(
        "/api/v1/health/anomaly",
        json={
            "medication_log_id": "log-critical",
            "anomaly_level": 2,
            "anomaly_type": "combined",
            "core_ml_confidence": 0.95,
            "timestamp": now.isoformat(),
        },
    )
    assert post_response.status_code == 200

    # Verify the inserted payload captured anomaly_level=2
    stored = fake_db.insert_payloads.get("health_events", {})
    assert stored.get("anomaly_level") == 2, (
        f"Expected anomaly_level=2 in health_events insert payload, got: {stored}"
    )

    # GET status — should reflect alert_level=2
    get_response = client.get("/api/v1/health/status/log-critical")
    app.dependency_overrides.clear()

    assert get_response.status_code == 200
    assert get_response.json()["data"]["alert_level"] == 2


# ---------------------------------------------------------------------------
# 5. test_duplicate_anomaly_report_within_cooldown
# ---------------------------------------------------------------------------

def test_duplicate_anomaly_report_within_cooldown(monkeypatch) -> None:
    """Two rapid anomaly reports for the same log_id are both accepted (201/200).
    Cooldown enforcement is the client's responsibility; the backend stores all reports."""
    client = TestClient(app)
    now = datetime.now(UTC)

    fake_db = _FakeSupabase(
        [
            {
                "id": "log-dup",
                "user_id": "user-123",
                "schedule_id": "sched-dup",
                "status": "taken",
                "monitoring_start": (now - timedelta(minutes=2)).isoformat(),
                "monitoring_end": (now + timedelta(hours=2)).isoformat(),
            }
        ],
        health_events=[{"id": "event-dup"}],
    )

    escalation_calls: list[str] = []

    async def _noop_escalation(event_id: str, _user_id: str) -> None:
        escalation_calls.append(event_id)

    monkeypatch.setattr("app.api.v1.health.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.health.start_escalation", _noop_escalation)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    payload = {
        "medication_log_id": "log-dup",
        "anomaly_level": 1,
        "anomaly_type": "high_hr",
        "core_ml_confidence": 0.75,
        "timestamp": now.isoformat(),
    }

    r1 = client.post("/api/v1/health/anomaly", json=payload)
    r2 = client.post("/api/v1/health/anomaly", json=payload)

    app.dependency_overrides.clear()

    assert r1.status_code == 200, f"First report failed: {r1.json()}"
    assert r2.status_code == 200, f"Second report (within cooldown window) should also succeed: {r2.json()}"
    assert len(escalation_calls) == 2, (
        "Both reports should trigger escalation start independently; "
        f"got {len(escalation_calls)} escalation call(s)"
    )
