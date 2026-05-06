from datetime import UTC, datetime, timedelta


DEMO_USER = {
    "email": "demo@mediguard.app",
    "password": "DemoPass123!",
    "name": "Chen Mei-Ling",
    "phone": "+886912345678",
    "language": "zh-TW",
    "emergency_contacts": [
        {"name": "Li Wei", "phone": "+886923456789", "relation": "son"},
        {"name": "Wang Shu-Hua", "phone": "+886934567890", "relation": "daughter"},
    ],
}


def build_demo_medications(user_id: str) -> list[dict]:
    return [
        {
            "user_id": user_id,
            "name": "Amlodipine",
            "name_zh": "脈優",
            "dosage": "5mg",
            "drug_info": {
                "main_effects": "Helps lower blood pressure and reduce strain on the heart.",
                "side_effects": ["dizziness", "ankle swelling"],
                "warnings": ["Rise slowly to avoid dizziness."],
                "elderly_notes": "Monitor for lightheadedness when standing.",
                "interactions": ["other blood pressure medications"],
                "source": "Combined",
            },
            "source_image_url": None,
            "is_active": True,
        },
        {
            "user_id": user_id,
            "name": "Metformin",
            "name_zh": "二甲雙胍",
            "dosage": "500mg",
            "drug_info": {
                "main_effects": "Helps control blood sugar levels.",
                "side_effects": ["nausea", "stomach upset"],
                "warnings": ["Take with meals to reduce stomach discomfort."],
                "elderly_notes": "Monitor kidney function during regular follow-up.",
                "interactions": ["contrast dye procedures"],
                "source": "Combined",
            },
            "source_image_url": None,
            "is_active": True,
        },
    ]


def build_demo_schedules(user_id: str, medication_ids: dict[str, str]) -> list[dict]:
    return [
        {
            "user_id": user_id,
            "medication_id": medication_ids["Amlodipine"],
            "times": ["08:00"],
            "days_of_week": None,
            "is_active": True,
        },
        {
            "user_id": user_id,
            "medication_id": medication_ids["Metformin"],
            "times": ["08:00", "20:00"],
            "days_of_week": None,
            "is_active": True,
        },
    ]


def build_demo_logs(user_id: str, schedule_ids: list[str]) -> list[dict]:
    now = datetime.now(UTC)
    earlier = now - timedelta(hours=3)
    active_start = now - timedelta(minutes=30)
    active_end = now + timedelta(minutes=90)

    return [
        {
            "user_id": user_id,
            "schedule_id": schedule_ids[0],
            "status": "taken",
            "scheduled_at": earlier.isoformat(),
            "taken_at": (earlier + timedelta(minutes=10)).isoformat(),
            "monitoring_start": earlier.isoformat(),
            "monitoring_end": (earlier + timedelta(hours=2)).isoformat(),
        },
        {
            "user_id": user_id,
            "schedule_id": schedule_ids[1],
            "status": "taken",
            "scheduled_at": active_start.isoformat(),
            "taken_at": active_start.isoformat(),
            "monitoring_start": active_start.isoformat(),
            "monitoring_end": active_end.isoformat(),
        },
    ]


def build_demo_health_event(user_id: str, medication_log_id: str) -> dict:
    return {
        "user_id": user_id,
        "medication_log_id": medication_log_id,
        "timestamp": datetime.now(UTC).isoformat(),
        "anomaly_level": 1,
        "anomaly_type": "high_hr",
        "core_ml_confidence": 0.87,
        "resolved_at": None,
    }


def build_demo_alert_log(user_id: str, health_event_id: str) -> dict:
    return {
        "user_id": user_id,
        "health_event_id": health_event_id,
        "level": 1,
        "sent_at": datetime.now(UTC).isoformat(),
        "responded_at": None,
        "response": None,
    }
