import logging
from zoneinfo import ZoneInfo

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger

from app.core.config import settings
from app.db.client import get_supabase
from app.services.notification_service import send_medication_reminder_push

logger = logging.getLogger(__name__)
_JOB_PREFIX = "medication-reminder:"
_DAY_OF_WEEK = {
    1: "mon",
    2: "tue",
    3: "wed",
    4: "thu",
    5: "fri",
    6: "sat",
    7: "sun",
}

_scheduler = AsyncIOScheduler(timezone=ZoneInfo(settings.app_timezone))


def scheduler_is_enabled() -> bool:
    return settings.scheduler_enabled and settings.app_env != "test"


def get_scheduler() -> AsyncIOScheduler:
    return _scheduler


async def start_scheduler() -> None:
    if not scheduler_is_enabled():
        return

    if not _scheduler.running:
        _scheduler.start()
        logger.info("Medication reminder scheduler started")

    await refresh_schedule_jobs()


async def shutdown_scheduler() -> None:
    if _scheduler.running:
        _scheduler.shutdown(wait=False)
        logger.info("Medication reminder scheduler stopped")


async def refresh_schedule_jobs() -> None:
    if not scheduler_is_enabled():
        return

    _remove_existing_reminder_jobs()
    db = get_supabase()
    rows = (
        db.table("schedules")
        .select("id, user_id, medication_id, times, days_of_week, is_active")
        .eq("is_active", True)
        .execute()
    )

    for schedule in rows.data:
        _schedule_jobs_for_row(schedule)

    logger.info("Refreshed medication reminder jobs for %s active schedules", len(rows.data))


def _remove_existing_reminder_jobs() -> None:
    for job in _scheduler.get_jobs():
        if job.id.startswith(_JOB_PREFIX):
            _scheduler.remove_job(job.id)


def _schedule_jobs_for_row(schedule: dict) -> None:
    schedule_id = schedule["id"]
    days_of_week = schedule.get("days_of_week")

    for time_value in schedule.get("times") or []:
        hour, minute = [int(part) for part in time_value.split(":", 1)]
        trigger_kwargs = {
            "hour": hour,
            "minute": minute,
            "timezone": ZoneInfo(settings.app_timezone),
        }
        formatted_days_of_week = _format_days_of_week(days_of_week)
        if formatted_days_of_week:
            trigger_kwargs["day_of_week"] = formatted_days_of_week

        trigger = CronTrigger(
            **trigger_kwargs,
        )
        _scheduler.add_job(
            _run_scheduled_reminder,
            trigger=trigger,
            id=_build_job_id(schedule_id, time_value, days_of_week),
            replace_existing=True,
            kwargs={"schedule_id": schedule_id, "scheduled_time": time_value},
        )


def _build_job_id(schedule_id: str, time_value: str, days_of_week: list[int] | None) -> str:
    day_suffix = "daily" if not days_of_week else "-".join(str(day) for day in days_of_week)
    return f"{_JOB_PREFIX}{schedule_id}:{day_suffix}:{time_value}"


def _format_days_of_week(days_of_week: list[int] | None) -> str | None:
    if not days_of_week:
        return None
    return ",".join(_DAY_OF_WEEK[day] for day in days_of_week)


async def _run_scheduled_reminder(schedule_id: str, scheduled_time: str) -> None:
    db = get_supabase()
    schedule_rows = (
        db.table("schedules")
        .select("id, user_id, medication_id, is_active")
        .eq("id", schedule_id)
        .eq("is_active", True)
        .execute()
    )
    if not schedule_rows.data:
        return

    schedule = schedule_rows.data[0]
    medication_rows = (
        db.table("medications")
        .select("name, dosage, is_active")
        .eq("id", schedule["medication_id"])
        .eq("user_id", schedule["user_id"])
        .eq("is_active", True)
        .execute()
    )
    if not medication_rows.data:
        return

    user_rows = (
        db.table("users")
        .select("apns_token")
        .eq("id", schedule["user_id"])
        .execute()
    )
    if not user_rows.data:
        return

    apns_token = user_rows.data[0].get("apns_token")
    if not apns_token:
        return

    medication = medication_rows.data[0]
    await send_medication_reminder_push(
        apns_token=apns_token,
        medication_name=medication["name"],
        dosage=medication.get("dosage"),
        schedule_id=schedule_id,
        scheduled_time=scheduled_time,
    )
    logger.info("Triggered medication reminder for schedule %s at %s", schedule_id, scheduled_time)
