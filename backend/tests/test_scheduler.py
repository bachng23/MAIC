import pytest

from app.services.reminder_scheduler import (
    _build_job_id,
    _format_days_of_week,
    get_scheduler,
    refresh_schedule_jobs,
)


class _FakeResponse:
    def __init__(self, data):
        self.data = data


class _FakeQuery:
    def __init__(self, db) -> None:
        self.db = db

    def select(self, _fields: str):
        return self

    def eq(self, _field: str, _value):
        return self

    def execute(self):
        return _FakeResponse(self.db.schedules)


class _FakeSupabase:
    def __init__(self, schedules: list[dict]) -> None:
        self.schedules = schedules

    def table(self, name: str) -> _FakeQuery:
        assert name == "schedules"
        return _FakeQuery(self)


def test_build_job_id_is_stable() -> None:
    assert _build_job_id("schedule-123", "08:00", [1, 3, 5]) == "medication-reminder:schedule-123:1-3-5:08:00"
    assert _build_job_id("schedule-123", "20:00", None) == "medication-reminder:schedule-123:daily:20:00"


def test_format_days_of_week_maps_to_cron_aliases() -> None:
    assert _format_days_of_week([1, 3, 5]) == "mon,wed,fri"
    assert _format_days_of_week(None) is None


@pytest.mark.anyio
async def test_refresh_schedule_jobs_registers_jobs(monkeypatch) -> None:
    scheduler = get_scheduler()
    for job in scheduler.get_jobs():
        scheduler.remove_job(job.id)

    fake_db = _FakeSupabase([
        {
            "id": "schedule-123",
            "user_id": "user-123",
            "medication_id": "med-123",
            "times": ["08:00", "20:00"],
            "days_of_week": [1, 3, 5],
            "is_active": True,
        }
    ])

    monkeypatch.setattr("app.services.reminder_scheduler.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.services.reminder_scheduler.scheduler_is_enabled", lambda: True)

    await refresh_schedule_jobs()

    jobs = sorted(job.id for job in scheduler.get_jobs())

    assert jobs == [
        "medication-reminder:schedule-123:1-3-5:08:00",
        "medication-reminder:schedule-123:1-3-5:20:00",
    ]

    for job in scheduler.get_jobs():
        scheduler.remove_job(job.id)
