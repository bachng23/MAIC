import asyncio
import logging
from datetime import datetime, timedelta, timezone

from app.core.config import settings
from app.db.client import get_supabase
from app.models.health import AlertLevel
from app.services.notification_service import send_push, send_silent_push

logger = logging.getLogger(__name__)

# Minutes to wait before escalating to next level
_ESCALATION_DELAYS = {
    AlertLevel.PUSH_NOTIFY: 5,
    AlertLevel.IMESSAGE: 10,
}
_ESCALATION_ORDER = [
    AlertLevel.PUSH_NOTIFY,
    AlertLevel.IMESSAGE,
    AlertLevel.EMERGENCY_CALL,
]


async def start_escalation(health_event_id: str, user_id: str) -> None:
    """Non-blocking: runs escalation pipeline in background."""
    logger.info("Starting escalation pipeline for event %s", health_event_id)
    asyncio.create_task(_run_escalation(health_event_id, user_id))


async def resume_pending_escalations() -> None:
    if settings.app_env == "test":
        return

    db = get_supabase()
    cutoff = (datetime.now(timezone.utc) - timedelta(hours=24)).isoformat()
    events = (
        db.table("health_events")
        .select("id, user_id, created_at, resolved_at")
        .is_("resolved_at", "null")
        .gte("created_at", cutoff)
        .execute()
    )

    for event in events.data:
        next_level, delay_seconds = _determine_resume_plan(event["id"])
        if next_level is None:
            continue

        logger.info(
            "Resuming escalation for event %s at level %s after %s seconds",
            event["id"],
            int(next_level),
            delay_seconds,
        )
        asyncio.create_task(
            _run_escalation_from_level(
                health_event_id=event["id"],
                user_id=event["user_id"],
                start_level=next_level,
                initial_delay_seconds=delay_seconds,
            )
        )


async def _run_escalation(health_event_id: str, user_id: str) -> None:
    await _run_escalation_from_level(
        health_event_id=health_event_id,
        user_id=user_id,
        start_level=AlertLevel.PUSH_NOTIFY,
        initial_delay_seconds=0,
    )


async def _run_escalation_from_level(
    health_event_id: str,
    user_id: str,
    start_level: AlertLevel,
    initial_delay_seconds: float,
) -> None:
    db = get_supabase()

    if initial_delay_seconds > 0:
        await asyncio.sleep(initial_delay_seconds)

    user = db.table("users").select("apns_token, emergency_contacts, name").eq("id", user_id).single().execute()
    apns_token = user.data["apns_token"]
    contacts = user.data.get("emergency_contacts") or []
    user_name = user.data["name"]

    start_index = _ESCALATION_ORDER.index(start_level)
    for level in _ESCALATION_ORDER[start_index:]:
        if await _is_resolved(health_event_id):
            logger.info("Stopping escalation for resolved event %s", health_event_id)
            return

        sent = await _send_alert(level, apns_token, contacts, user_name, health_event_id)
        logger.info(
            "Escalation level %s for event %s completed with sent=%s",
            int(level),
            health_event_id,
            sent,
        )

        db.table("alert_logs").insert({
            "user_id": user_id,
            "health_event_id": health_event_id,
            "level": int(level),
            "sent_at": datetime.now(timezone.utc).isoformat(),
            "response": None,
        }).execute()

        if level in _ESCALATION_DELAYS:
            await asyncio.sleep(_ESCALATION_DELAYS[level] * 60)


async def _send_alert(
    level: AlertLevel,
    apns_token: str,
    contacts: list[dict],
    user_name: str,
    health_event_id: str,
) -> None:
    if level == AlertLevel.PUSH_NOTIFY:
        return await send_push(
            apns_token,
            title="⚠️ Health Alert",
            body="We detected an abnormal reading. Are you okay?",
            data={"action": "health_alert", "event_id": health_event_id},
        )

    elif level == AlertLevel.IMESSAGE:
        return await send_silent_push(
            apns_token,
            data={
                "action": "send_imessage",
                "contacts": contacts,
                "message": f"{user_name} may be experiencing a health issue. Please check on them.",
                "event_id": health_event_id,
            },
        )

    elif level == AlertLevel.EMERGENCY_CALL:
        return await send_silent_push(
            apns_token,
            data={
                "action": "emergency_call",
                "number": "119",
                "event_id": health_event_id,
            },
        )

    return False


async def _is_resolved(health_event_id: str) -> bool:
    db = get_supabase()
    result = db.table("health_events").select("resolved_at").eq("id", health_event_id).single().execute()
    return result.data.get("resolved_at") is not None


def _determine_resume_plan(health_event_id: str) -> tuple[AlertLevel | None, float]:
    db = get_supabase()
    alert_logs = (
        db.table("alert_logs")
        .select("level, sent_at")
        .eq("health_event_id", health_event_id)
        .order("sent_at", desc=True)
        .limit(1)
        .execute()
    )

    if not alert_logs.data:
        return AlertLevel.PUSH_NOTIFY, 0

    latest_log = alert_logs.data[0]
    latest_level = AlertLevel(latest_log["level"])
    if latest_level == AlertLevel.EMERGENCY_CALL:
        return None, 0

    sent_at = datetime.fromisoformat(latest_log["sent_at"])
    elapsed_seconds = (datetime.now(timezone.utc) - sent_at).total_seconds()
    required_delay_seconds = _ESCALATION_DELAYS[latest_level] * 60
    remaining_delay_seconds = max(0.0, required_delay_seconds - elapsed_seconds)

    next_level = _ESCALATION_ORDER[_ESCALATION_ORDER.index(latest_level) + 1]
    return next_level, remaining_delay_seconds
