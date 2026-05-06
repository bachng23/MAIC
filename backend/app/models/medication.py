from datetime import datetime

from pydantic import BaseModel, Field, field_validator


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
    warnings: list[str] = Field(default_factory=list)
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
    interactions: list[str] = Field(default_factory=list)
    source: str


# ── Medication CRUD ───────────────────────────────────────────────────────────

class MedicationCreate(BaseModel):
    name: str
    name_zh: str | None = None
    dosage: str | None = None
    drug_info: DrugInfo | None = None
    source_image_url: str | None = None


class MedicationOut(MedicationCreate):
    id: str
    user_id: str
    is_active: bool


# ── Schedule ──────────────────────────────────────────────────────────────────

class ScheduleCreate(BaseModel):
    medication_id: str
    times: list[str] = Field(min_length=1)
    days_of_week: list[int] | None = None

    @field_validator("times")
    @classmethod
    def validate_times(cls, times: list[str]) -> list[str]:
        for time_value in times:
            datetime.strptime(time_value, "%H:%M")
        return times

    @field_validator("days_of_week")
    @classmethod
    def validate_days_of_week(cls, days_of_week: list[int] | None) -> list[int] | None:
        if days_of_week is None:
            return None

        if any(day < 1 or day > 7 for day in days_of_week):
            raise ValueError("days_of_week must only contain values from 1 to 7")

        return days_of_week


class ScheduleOut(ScheduleCreate):
    id: str
    user_id: str
    is_active: bool


# ── Medication Log ────────────────────────────────────────────────────────────

class MedicationTakenRequest(BaseModel):
    schedule_id: str
    scheduled_at: datetime | None = None


class MedicationTakenResponse(BaseModel):
    log_id: str
    monitoring_start: datetime
    monitoring_end: datetime
    monitoring_duration_seconds: int = 7200


class MedicationSkippedRequest(BaseModel):
    schedule_id: str
    scheduled_at: datetime | None = None
    reason: str | None = None
