import sys
from pathlib import Path

from dotenv import load_dotenv

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

load_dotenv()

from app.db.client import get_supabase
from app.services.demo_seed import (
    DEMO_USER,
    build_demo_alert_log,
    build_demo_health_event,
    build_demo_logs,
    build_demo_medications,
    build_demo_schedules,
)


def main() -> None:
    db = get_supabase()
    user_id = ensure_demo_user(db)
    print(f"Demo user ready: {DEMO_USER['email']} ({user_id})")

    medication_rows = reset_and_insert_medications(db, user_id)
    medication_ids = {row["name"]: row["id"] for row in medication_rows}
    print(f"Seeded {len(medication_rows)} medications")

    schedule_rows = reset_and_insert_schedules(db, user_id, medication_ids)
    schedule_ids = [row["id"] for row in schedule_rows]
    print(f"Seeded {len(schedule_rows)} schedules")

    log_rows = reset_and_insert_logs(db, user_id, schedule_ids)
    print(f"Seeded {len(log_rows)} medication logs")

    health_event = reset_and_insert_health_event(db, user_id, log_rows[-1]["id"])
    reset_and_insert_alert_log(db, user_id, health_event["id"])
    print("Seeded 1 active health event and 1 alert log")


def ensure_demo_user(db) -> str:
    existing = db.auth.admin.list_users()
    matched_user = next((user for user in existing if user.email == DEMO_USER["email"]), None)
    if matched_user is None:
        created = db.auth.admin.create_user(
            {
                "email": DEMO_USER["email"],
                "password": DEMO_USER["password"],
                "email_confirm": True,
                "user_metadata": {"name": DEMO_USER["name"]},
            }
        )
        matched_user = created.user

    user_id = matched_user.id
    db.table("users").update(
        {
            "name": DEMO_USER["name"],
            "phone": DEMO_USER["phone"],
            "language": DEMO_USER["language"],
            "emergency_contacts": DEMO_USER["emergency_contacts"],
        }
    ).eq("id", user_id).execute()
    return user_id


def reset_and_insert_medications(db, user_id: str) -> list[dict]:
    db.table("medications").delete().eq("user_id", user_id).execute()
    inserted = db.table("medications").insert(build_demo_medications(user_id)).execute()
    return inserted.data


def reset_and_insert_schedules(db, user_id: str, medication_ids: dict[str, str]) -> list[dict]:
    db.table("schedules").delete().eq("user_id", user_id).execute()
    inserted = db.table("schedules").insert(build_demo_schedules(user_id, medication_ids)).execute()
    return inserted.data


def reset_and_insert_logs(db, user_id: str, schedule_ids: list[str]) -> list[dict]:
    db.table("medication_logs").delete().eq("user_id", user_id).execute()
    inserted = db.table("medication_logs").insert(build_demo_logs(user_id, schedule_ids)).execute()
    return inserted.data


def reset_and_insert_health_event(db, user_id: str, medication_log_id: str) -> dict:
    db.table("health_events").delete().eq("user_id", user_id).execute()
    inserted = db.table("health_events").insert(build_demo_health_event(user_id, medication_log_id)).execute()
    return inserted.data[0]


def reset_and_insert_alert_log(db, user_id: str, health_event_id: str) -> None:
    db.table("alert_logs").delete().eq("user_id", user_id).execute()
    db.table("alert_logs").insert(build_demo_alert_log(user_id, health_event_id)).execute()


if __name__ == "__main__":
    main()
