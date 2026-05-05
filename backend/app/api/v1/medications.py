from fastapi import APIRouter, Depends

from app.api.deps import get_current_user
from app.db.client import get_supabase
from app.models.base import APIResponse
from app.models.medication import (
    DrugInfo,
    DrugInfoRequest,
    MedicationCreate,
    MedicationOut,
    MedicationSkippedRequest,
    MedicationTakenRequest,
    MedicationTakenResponse,
    OCRScanRequest,
    OCRScanResult,
    ScheduleCreate,
    ScheduleOut,
)
from app.services.drug_agent import get_drug_info
from app.services.ocr_service import parse_medication_image

router = APIRouter(prefix="/medications", tags=["medications"])


@router.post("/scan", response_model=APIResponse[OCRScanResult])
async def scan_medication(body: OCRScanRequest, user: dict = Depends(get_current_user)):
    result = await parse_medication_image(body.image_base64, user["id"])
    return APIResponse(data=result)


@router.post("/drug-info", response_model=APIResponse[DrugInfo])
async def drug_info(body: DrugInfoRequest, user: dict = Depends(get_current_user)):
    info = await get_drug_info(body.drug_name, body.drug_name_zh)
    return APIResponse(data=info)


@router.post("", response_model=APIResponse[MedicationOut])
async def create_medication(body: MedicationCreate, user: dict = Depends(get_current_user)):
    db = get_supabase()
    row = db.table("medications").insert({"user_id": user["id"], **body.model_dump()}).execute()
    return APIResponse(data=MedicationOut(**row.data[0]))


@router.get("", response_model=APIResponse[list[MedicationOut]])
async def list_medications(user: dict = Depends(get_current_user)):
    db = get_supabase()
    rows = db.table("medications").select("*").eq("user_id", user["id"]).eq("is_active", True).execute()
    return APIResponse(data=[MedicationOut(**r) for r in rows.data])


@router.delete("/{medication_id}", response_model=APIResponse[None])
async def delete_medication(medication_id: str, user: dict = Depends(get_current_user)):
    db = get_supabase()
    db.table("medications").update({"is_active": False}).eq("id", medication_id).eq("user_id", user["id"]).execute()
    return APIResponse(message="Medication removed")


# ── Schedules ─────────────────────────────────────────────────────────────────

schedules_router = APIRouter(prefix="/schedules", tags=["schedules"])


@schedules_router.post("", response_model=APIResponse[ScheduleOut])
async def create_schedule(body: ScheduleCreate, user: dict = Depends(get_current_user)):
    db = get_supabase()
    row = db.table("schedules").insert({"user_id": user["id"], **body.model_dump()}).execute()
    return APIResponse(data=ScheduleOut(**row.data[0]))


@schedules_router.get("", response_model=APIResponse[list[ScheduleOut]])
async def list_schedules(user: dict = Depends(get_current_user)):
    db = get_supabase()
    rows = db.table("schedules").select("*").eq("user_id", user["id"]).eq("is_active", True).execute()
    return APIResponse(data=[ScheduleOut(**r) for r in rows.data])


@schedules_router.delete("/{schedule_id}", response_model=APIResponse[None])
async def delete_schedule(schedule_id: str, user: dict = Depends(get_current_user)):
    db = get_supabase()
    db.table("schedules").update({"is_active": False}).eq("id", schedule_id).eq("user_id", user["id"]).execute()
    return APIResponse(message="Schedule removed")


# ── Medication Logs ───────────────────────────────────────────────────────────

logs_router = APIRouter(prefix="/logs", tags=["logs"])


@logs_router.post("/taken", response_model=APIResponse[MedicationTakenResponse])
async def log_taken(body: MedicationTakenRequest, user: dict = Depends(get_current_user)):
    from datetime import datetime, timedelta, timezone
    db = get_supabase()
    now = datetime.now(timezone.utc)
    row = db.table("medication_logs").insert({
        "user_id": user["id"],
        "schedule_id": body.schedule_id,
        "status": "taken",
        "taken_at": now.isoformat(),
        "monitoring_start": now.isoformat(),
        "monitoring_end": (now + timedelta(hours=2)).isoformat(),
    }).execute()
    return APIResponse(data=MedicationTakenResponse(log_id=row.data[0]["id"]))


@logs_router.post("/skipped", response_model=APIResponse[None])
async def log_skipped(body: MedicationSkippedRequest, user: dict = Depends(get_current_user)):
    db = get_supabase()
    db.table("medication_logs").insert({
        "user_id": user["id"],
        "schedule_id": body.schedule_id,
        "status": "skipped",
    }).execute()
    return APIResponse(message="Logged as skipped")
