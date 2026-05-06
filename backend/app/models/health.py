from datetime import datetime
from enum import IntEnum, StrEnum

from pydantic import BaseModel, Field


class AnomalyLevel(IntEnum):
    NORMAL = 0
    WARNING = 1
    CRITICAL = 2


class AnomalyType(StrEnum):
    HIGH_HR = "high_hr"
    LOW_SPO2 = "low_spo2"
    IRREGULAR_HRV = "irregular_hrv"
    COMBINED = "combined"


class AnomalyReport(BaseModel):
    """Sent by Flutter after Core ML detects anomaly. No raw health data."""
    medication_log_id: str
    anomaly_level: AnomalyLevel
    anomaly_type: AnomalyType
    core_ml_confidence: float = Field(ge=0, le=1)
    timestamp: datetime


class HealthStatus(BaseModel):
    log_id: str
    monitoring_active: bool
    monitoring_start: datetime | None = None
    monitoring_end: datetime | None = None
    alert_level: AnomalyLevel
    resolved: bool


class ResolveRequest(BaseModel):
    log_id: str


# ── Emergency ─────────────────────────────────────────────────────────────────

class EmergencyContact(BaseModel):
    name: str
    phone: str
    relation: str


class EmergencyContactsUpdate(BaseModel):
    contacts: list[EmergencyContact]


class AlertLevel(IntEnum):
    PUSH_NOTIFY = 1
    IMESSAGE = 2
    EMERGENCY_CALL = 3
