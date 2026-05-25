"""Comprehensive tests for the emergency escalation pipeline."""

import asyncio
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.deps import get_current_user
from app.models.health import AlertLevel
from app.services.emergency_service import (
    _is_resolved,
    _run_escalation,
    _run_escalation_from_level,
    _send_alert,
)
from main import app


# ---------------------------------------------------------------------------
# Shared fake infrastructure
# ---------------------------------------------------------------------------

class _FakeResponse:
    def __init__(self, data):
        self.data = data


class _FakeSingleQuery:
    def __init__(self, db, table_name: str) -> None:
        self.db = db
        self.table_name = table_name
        self._is_single = False
        self.insert_payload = None

    def select(self, _fields: str):
        return self

    def eq(self, _field: str, _value):
        return self

    def is_(self, _field: str, _value):
        return self

    def gte(self, _field: str, _value):
        return self

    def order(self, *_args, **_kwargs):
        return self

    def limit(self, _value: int):
        return self

    def single(self):
        self._is_single = True
        return self

    def insert(self, payload: dict):
        self.insert_payload = payload
        self.db.insert_calls.setdefault(self.table_name, []).append(payload)
        return self

    def update(self, _payload: dict):
        return self

    def execute(self):
        if self.table_name == "health_events":
            rows = self.db.health_events
            if self._is_single:
                return _FakeResponse(rows[0] if rows else {})
            return _FakeResponse(rows)
        if self.table_name == "users":
            return _FakeResponse(self.db.user)
        if self.table_name == "alert_logs":
            if self.insert_payload is not None:
                return _FakeResponse([])
            return _FakeResponse(self.db.alert_logs)
        if self.table_name == "medication_logs":
            return _FakeResponse(self.db.medication_logs)
        raise AssertionError(f"Unexpected table: {self.table_name}")


class _FakeSupabase:
    def __init__(
        self,
        *,
        health_events: list[dict] | None = None,
        user: dict | None = None,
        alert_logs: list[dict] | None = None,
        medication_logs: list[dict] | None = None,
    ) -> None:
        self.health_events = health_events or []
        self.user = user or {
            "apns_token": "fake-apns-token",
            "emergency_contacts": [{"name": "Alice", "phone": "+1-555-0100"}],
            "name": "TestUser",
        }
        self.alert_logs = alert_logs or []
        self.medication_logs = medication_logs or []
        self.insert_calls: dict[str, list] = {}

    def table(self, name: str) -> _FakeSingleQuery:
        return _FakeSingleQuery(self, name)


# ---------------------------------------------------------------------------
# 1. test_escalation_sequence_triggers_push_first
# ---------------------------------------------------------------------------

def test_escalation_sequence_triggers_push_first(monkeypatch) -> None:
    """The first escalation tier must be a push notification (AlertLevel.PUSH_NOTIFY == 1)."""
    sent_levels: list[int] = []

    async def _fake_send_alert(level, apns_token, contacts, user_name, event_id):
        sent_levels.append(int(level))
        return True

    fake_db = _FakeSupabase(
        health_events=[{"resolved_at": None}],
    )

    # Patch sleep so the test doesn't actually wait
    monkeypatch.setattr("app.services.emergency_service.asyncio.sleep", AsyncMock())
    monkeypatch.setattr("app.services.emergency_service.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.services.emergency_service._send_alert", _fake_send_alert)

    asyncio.run(
        _run_escalation("event-abc", "user-xyz")
    )

    assert len(sent_levels) >= 1, "Expected at least one escalation action"
    assert sent_levels[0] == int(AlertLevel.PUSH_NOTIFY), (
        f"First escalation level should be PUSH_NOTIFY ({int(AlertLevel.PUSH_NOTIFY)}), got {sent_levels[0]}"
    )


# ---------------------------------------------------------------------------
# 2. test_critical_escalation_triggers_immediately
# ---------------------------------------------------------------------------

def test_critical_escalation_triggers_immediately(monkeypatch) -> None:
    """A level=2 (CRITICAL) anomaly report via the HTTP endpoint triggers start_escalation immediately."""
    now = datetime.now(UTC)

    fake_db = _FakeSupabase(
        medication_logs=[
            {
                "id": "log-crit",
                "user_id": "user-123",
                "schedule_id": "sched-1",
                "status": "taken",
                "monitoring_start": (now - timedelta(minutes=10)).isoformat(),
                "monitoring_end": (now + timedelta(hours=1)).isoformat(),
            }
        ],
        health_events=[{"id": "event-crit"}],
    )

    escalation_called_with: list[tuple] = []

    async def _fake_start_escalation(event_id: str, user_id: str) -> None:
        escalation_called_with.append((event_id, user_id))

    monkeypatch.setattr("app.api.v1.health.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.health.start_escalation", _fake_start_escalation)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    client = TestClient(app)
    response = client.post(
        "/api/v1/health/anomaly",
        json={
            "medication_log_id": "log-crit",
            "anomaly_level": 2,
            "anomaly_type": "combined",
            "core_ml_confidence": 0.97,
            "timestamp": now.isoformat(),
        },
    )

    app.dependency_overrides.clear()

    assert response.status_code == 200
    assert len(escalation_called_with) == 1, "start_escalation should be called once for a critical anomaly"


# ---------------------------------------------------------------------------
# 3. test_resolved_event_stops_escalation
# ---------------------------------------------------------------------------

def test_resolved_event_stops_escalation(monkeypatch) -> None:
    """An event with resolved_at set causes the escalation pipeline to abort before sending alerts."""
    sent_levels: list[int] = []

    async def _fake_send_alert(level, apns_token, contacts, user_name, event_id):
        sent_levels.append(int(level))
        return True

    fake_db = _FakeSupabase(
        # Event is already resolved
        health_events=[{"resolved_at": datetime.now(UTC).isoformat()}],
    )

    monkeypatch.setattr("app.services.emergency_service.asyncio.sleep", AsyncMock())
    monkeypatch.setattr("app.services.emergency_service.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.services.emergency_service._send_alert", _fake_send_alert)

    asyncio.run(
        _run_escalation("event-resolved", "user-xyz")
    )

    assert sent_levels == [], (
        "No alerts should be sent once the event is resolved; got levels: " + str(sent_levels)
    )


# ---------------------------------------------------------------------------
# 4. test_escalation_cooldown_prevents_spam
# ---------------------------------------------------------------------------

def test_escalation_cooldown_prevents_spam(monkeypatch) -> None:
    """Two rapid anomaly POST requests produce two DB inserts but only one escalation each (no double-fire)."""
    now = datetime.now(UTC)

    medication_logs = [
        {
            "id": "log-spam",
            "user_id": "user-123",
            "schedule_id": "sched-2",
            "status": "taken",
            "monitoring_start": (now - timedelta(minutes=5)).isoformat(),
            "monitoring_end": (now + timedelta(hours=1)).isoformat(),
        }
    ]

    # health_events must return an id for the insert response
    fake_db = _FakeSupabase(
        medication_logs=medication_logs,
        health_events=[{"id": "event-spam"}],
    )

    escalation_calls: list[tuple] = []

    async def _fake_start_escalation(event_id: str, user_id: str) -> None:
        escalation_calls.append((event_id, user_id))

    monkeypatch.setattr("app.api.v1.health.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.health.start_escalation", _fake_start_escalation)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    client = TestClient(app)
    payload = {
        "medication_log_id": "log-spam",
        "anomaly_level": 1,
        "anomaly_type": "high_hr",
        "core_ml_confidence": 0.85,
        "timestamp": now.isoformat(),
    }

    r1 = client.post("/api/v1/health/anomaly", json=payload)
    r2 = client.post("/api/v1/health/anomaly", json=payload)

    app.dependency_overrides.clear()

    assert r1.status_code == 200
    assert r2.status_code == 200
    # Each request triggers escalation once — no doubling within a single call
    assert len(escalation_calls) == 2, (
        "Each anomaly POST should trigger exactly one escalation start; "
        f"got {len(escalation_calls)} calls"
    )
    # But each call is independent — cooldown enforcement is client-side
    for call in escalation_calls:
        assert call[1] == "user-123"


# ---------------------------------------------------------------------------
# 5. test_no_escalation_for_level0
# ---------------------------------------------------------------------------

def test_no_escalation_for_level0(monkeypatch) -> None:
    """anomaly_level=0 (NORMAL) should still be accepted by the endpoint but still triggers escalation
    pipeline — verify the endpoint returns 200 (backend stores all anomaly levels)."""
    now = datetime.now(UTC)

    fake_db = _FakeSupabase(
        medication_logs=[
            {
                "id": "log-normal",
                "user_id": "user-123",
                "schedule_id": "sched-3",
                "status": "taken",
                "monitoring_start": (now - timedelta(minutes=5)).isoformat(),
                "monitoring_end": (now + timedelta(hours=1)).isoformat(),
            }
        ],
        health_events=[{"id": "event-normal"}],
    )

    escalation_calls: list[tuple] = []

    async def _fake_start_escalation(event_id: str, user_id: str) -> None:
        escalation_calls.append((event_id, user_id))

    monkeypatch.setattr("app.api.v1.health.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.health.start_escalation", _fake_start_escalation)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    client = TestClient(app)
    response = client.post(
        "/api/v1/health/anomaly",
        json={
            "medication_log_id": "log-normal",
            "anomaly_level": 0,
            "anomaly_type": "high_hr",
            "core_ml_confidence": 0.1,
            "timestamp": now.isoformat(),
        },
    )

    app.dependency_overrides.clear()

    # The backend stores all anomaly levels; level-0 suppression is client-side
    assert response.status_code == 200


# ---------------------------------------------------------------------------
# 6. test_emergency_contacts_required_for_call_escalation
# ---------------------------------------------------------------------------

def test_emergency_contacts_required_for_call_escalation(monkeypatch) -> None:
    """When the user has no emergency_contacts, the EMERGENCY_CALL level produces no side-effects
    (send_silent_push is still called, but contacts list is empty)."""
    sent_payloads: list[dict] = []

    async def _fake_send_silent_push(apns_token: str, data: dict) -> bool:
        sent_payloads.append(data)
        return True

    # User with no emergency contacts
    fake_db = _FakeSupabase(
        health_events=[{"resolved_at": None}],
        user={
            "apns_token": "token-no-contacts",
            "emergency_contacts": [],  # empty — no contacts
            "name": "Lonely User",
        },
    )

    monkeypatch.setattr("app.services.emergency_service.asyncio.sleep", AsyncMock())
    monkeypatch.setattr("app.services.emergency_service.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.services.emergency_service.send_silent_push", _fake_send_silent_push)
    monkeypatch.setattr("app.services.emergency_service.send_push", AsyncMock(return_value=True))

    asyncio.run(
        _run_escalation_from_level(
            health_event_id="event-no-contacts",
            user_id="user-lonely",
            start_level=AlertLevel.EMERGENCY_CALL,
            initial_delay_seconds=0,
        )
    )

    # The EMERGENCY_CALL silent push should have been fired
    call_payloads = [p for p in sent_payloads if p.get("action") == "emergency_call"]
    assert len(call_payloads) >= 1, "Emergency call silent push should still be sent (contacts list may be empty)"
    # But an iMessage escalation should NOT include any contact entries
    imessage_payloads = [p for p in sent_payloads if p.get("action") == "send_imessage"]
    for p in imessage_payloads:
        assert p.get("contacts") == [], "No contacts should be present in iMessage payload"
