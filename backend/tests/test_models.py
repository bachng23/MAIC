from datetime import datetime

import pytest
from pydantic import ValidationError

from app.models.health import AnomalyReport, AnomalyType
from app.models.medication import MedicationCreate, OCRScanResult, ScheduleCreate


def test_medication_create_allows_missing_dosage_for_ocr_fallback_flow() -> None:
    medication = MedicationCreate(name="Aspirin", dosage=None)

    assert medication.name == "Aspirin"
    assert medication.dosage is None


def test_ocr_scan_result_uses_independent_warning_lists() -> None:
    first = OCRScanResult(name="A")
    second = OCRScanResult(name="B")

    first.warnings.append("take with food")

    assert second.warnings == []


def test_schedule_create_rejects_invalid_time_format() -> None:
    with pytest.raises(ValidationError):
        ScheduleCreate(medication_id="med-123", times=["8am"])


def test_anomaly_report_requires_typed_values() -> None:
    report = AnomalyReport(
        medication_log_id="log-123",
        anomaly_level=1,
        anomaly_type="high_hr",
        core_ml_confidence=0.92,
        timestamp="2026-05-06T10:00:00+00:00",
    )

    assert report.anomaly_type == AnomalyType.HIGH_HR
    assert isinstance(report.timestamp, datetime)


def test_anomaly_report_rejects_invalid_confidence() -> None:
    with pytest.raises(ValidationError):
        AnomalyReport(
            medication_log_id="log-123",
            anomaly_level=1,
            anomaly_type="high_hr",
            core_ml_confidence=1.5,
            timestamp="2026-05-06T10:00:00+00:00",
        )
