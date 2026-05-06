import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import get_current_user
from app.db.client import get_supabase
from app.models.base import APIResponse
from app.models.health import AnomalyLevel, AnomalyReport, HealthStatus, ResolveRequest
from app.api.v1.medications import get_medication_log_for_user
from app.services.emergency_service import start_escalation
from app.services.rate_limiter import RateLimitRule, create_rate_limit_dependency

router = APIRouter(prefix="/health", tags=["health"])
logger = logging.getLogger(__name__)
health_anomaly_rate_limit = create_rate_limit_dependency(
    RateLimitRule(name="health-anomaly", max_requests=30, window_seconds=60, scope="ip")
)
health_read_rate_limit = create_rate_limit_dependency(
    RateLimitRule(name="health-read", max_requests=120, window_seconds=60, scope="ip")
)
health_resolve_rate_limit = create_rate_limit_dependency(
    RateLimitRule(name="health-resolve", max_requests=20, window_seconds=60, scope="ip")
)


@router.post("/anomaly", response_model=APIResponse[None])
async def report_anomaly(
    body: AnomalyReport,
    user: dict = Depends(get_current_user),
    _: None = Depends(health_anomaly_rate_limit),
):
    db = get_supabase()
    medication_log = get_medication_log_for_user(db, body.medication_log_id, user["id"])
    if not medication_log:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medication log not found",
        )

    monitoring_end_raw = medication_log.get("monitoring_end")
    if monitoring_end_raw:
        monitoring_end = datetime.fromisoformat(monitoring_end_raw)
        if body.timestamp > monitoring_end:
            logger.warning("Rejected anomaly for expired monitoring window on log %s", body.medication_log_id)
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Monitoring window has ended",
            )

    event = db.table("health_events").insert({
        "user_id": user["id"],
        "medication_log_id": body.medication_log_id,
        "timestamp": body.timestamp.isoformat(),
        "anomaly_level": int(body.anomaly_level),
        "anomaly_type": body.anomaly_type.value,
        "core_ml_confidence": body.core_ml_confidence,
    }).execute()

    event_id = event.data[0]["id"]
    logger.info("Recorded anomaly event %s for log %s", event_id, body.medication_log_id)

    # Trigger escalation pipeline in background
    await start_escalation(event_id, user["id"])

    return APIResponse(message="Anomaly logged, monitoring escalation started")


@router.get("/status/{log_id}", response_model=APIResponse[HealthStatus])
async def get_health_status(
    log_id: str,
    user: dict = Depends(get_current_user),
    _: None = Depends(health_read_rate_limit),
):
    db = get_supabase()

    medication_log = get_medication_log_for_user(db, log_id, user["id"])
    if not medication_log:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medication log not found",
        )

    event = db.table("health_events").select("anomaly_level, resolved_at").eq("medication_log_id", log_id).order("timestamp", desc=True).limit(1).execute()

    now = datetime.now(timezone.utc)
    monitoring_start = _parse_datetime_or_none(medication_log.get("monitoring_start"))
    monitoring_end = _parse_datetime_or_none(medication_log.get("monitoring_end"))

    latest_event = event.data[0] if event.data else None

    return APIResponse(data=HealthStatus(
        log_id=log_id,
        monitoring_active=bool(monitoring_end and now < monitoring_end),
        monitoring_start=monitoring_start,
        monitoring_end=monitoring_end,
        alert_level=AnomalyLevel(latest_event["anomaly_level"]) if latest_event else AnomalyLevel.NORMAL,
        resolved=bool(latest_event and latest_event.get("resolved_at")),
    ))


@router.post("/resolve", response_model=APIResponse[None])
async def resolve_alert(
    body: ResolveRequest,
    user: dict = Depends(get_current_user),
    _: None = Depends(health_resolve_rate_limit),
):
    db = get_supabase()
    medication_log = get_medication_log_for_user(db, body.log_id, user["id"])
    if not medication_log:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medication log not found",
        )

    db.table("health_events").update({
        "resolved_at": datetime.now(timezone.utc).isoformat()
    }).eq("medication_log_id", body.log_id).eq("user_id", user["id"]).is_("resolved_at", "null").execute()
    logger.info("Resolved health alert for log %s", body.log_id)

    return APIResponse(message="Alert resolved")


def _parse_datetime_or_none(value: str | None) -> datetime | None:
    if not value:
        return None
    return datetime.fromisoformat(value)
