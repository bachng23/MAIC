from datetime import UTC, datetime, timedelta

from app.services.emergency_service import _determine_resume_plan
from app.models.health import AlertLevel


class _FakeResponse:
    def __init__(self, data):
        self.data = data


class _FakeQuery:
    def __init__(self, data) -> None:
        self.data = data

    def select(self, _fields: str):
        return self

    def eq(self, _field: str, _value):
        return self

    def order(self, *_args, **_kwargs):
        return self

    def limit(self, _value: int):
        return self

    def execute(self):
        return _FakeResponse(self.data)


class _FakeSupabase:
    def __init__(self, alert_logs: list[dict]) -> None:
        self.alert_logs = alert_logs

    def table(self, name: str) -> _FakeQuery:
        assert name == "alert_logs"
        return _FakeQuery(self.alert_logs)


def test_determine_resume_plan_starts_from_level_one_when_no_alert_logs(monkeypatch) -> None:
    monkeypatch.setattr("app.services.emergency_service.get_supabase", lambda: _FakeSupabase([]))

    next_level, delay_seconds = _determine_resume_plan("event-123")

    assert next_level == AlertLevel.PUSH_NOTIFY
    assert delay_seconds == 0


def test_determine_resume_plan_resumes_next_level_after_remaining_delay(monkeypatch) -> None:
    sent_at = datetime.now(UTC) - timedelta(minutes=3)
    monkeypatch.setattr(
        "app.services.emergency_service.get_supabase",
        lambda: _FakeSupabase([{"level": 1, "sent_at": sent_at.isoformat()}]),
    )

    next_level, delay_seconds = _determine_resume_plan("event-123")

    assert next_level == AlertLevel.IMESSAGE
    assert 0 < delay_seconds <= 120


def test_determine_resume_plan_stops_after_final_level(monkeypatch) -> None:
    sent_at = datetime.now(UTC) - timedelta(minutes=1)
    monkeypatch.setattr(
        "app.services.emergency_service.get_supabase",
        lambda: _FakeSupabase([{"level": 3, "sent_at": sent_at.isoformat()}]),
    )

    next_level, delay_seconds = _determine_resume_plan("event-123")

    assert next_level is None
    assert delay_seconds == 0
