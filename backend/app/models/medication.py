from pydantic import BaseModel


# ── OCR ──────────────────────────────────────────────────────────────────────

class OCRScanRequest(BaseModel):
    image_base64: str


class OCRScanResult(BaseModel):
    name: str
    name_zh: str | None = None
    dosage: str | None = None
    frequency: str | None = None
    expiry_date: str | None = None
    manufacturer: str | None = None
    warnings: list[str] = []
    source_image_url: str | None = None


# ── Drug Info ─────────────────────────────────────────────────────────────────

class DrugInfoRequest(BaseModel):
    drug_name: str
    drug_name_zh: str | None = None


class DrugInfo(BaseModel):
    main_effects: str
    side_effects: list[str]
    warnings: list[str]
    elderly_notes: str | None = None
    interactions: list[str] = []
    source: str


# ── Medication CRUD ───────────────────────────────────────────────────────────

class MedicationCreate(BaseModel):
    name: str
    name_zh: str | None = None
    dosage: str
    drug_info: DrugInfo | None = None
    source_image_url: str | None = None


class MedicationOut(MedicationCreate):
    id: str
    user_id: str
    is_active: bool


# ── Schedule ──────────────────────────────────────────────────────────────────

class ScheduleCreate(BaseModel):
    medication_id: str
    times: list[str]
    days_of_week: list[int] | None = None


class ScheduleOut(ScheduleCreate):
    id: str
    user_id: str
    is_active: bool


# ── Medication Log ────────────────────────────────────────────────────────────

class MedicationTakenRequest(BaseModel):
    schedule_id: str


class MedicationTakenResponse(BaseModel):
    log_id: str
    monitoring_duration_seconds: int = 7200


class MedicationSkippedRequest(BaseModel):
    schedule_id: str
    reason: str | None = None
