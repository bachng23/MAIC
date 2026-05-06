from app.services.demo_seed import (
    DEMO_USER,
    build_demo_alert_log,
    build_demo_health_event,
    build_demo_logs,
    build_demo_medications,
    build_demo_schedules,
)
from scripts.seed_demo_data import ensure_demo_user


class _FakeUser:
    def __init__(self, user_id: str, email: str) -> None:
        self.id = user_id
        self.email = email


class _FakeUserResponse:
    def __init__(self, user: _FakeUser) -> None:
        self.user = user


class _FakeAdmin:
    def __init__(self, users: list[_FakeUser]) -> None:
        self.users = users
        self.create_payload = None

    def list_users(self):
        return self.users

    def create_user(self, payload: dict):
        self.create_payload = payload
        user = _FakeUser("demo-user-id", payload["email"])
        self.users.append(user)
        return _FakeUserResponse(user)


class _FakeAuth:
    def __init__(self, users: list[_FakeUser]) -> None:
        self.admin = _FakeAdmin(users)


class _FakeTable:
    def __init__(self) -> None:
        self.updated_payload = None
        self.eq_calls: list[tuple[str, str]] = []

    def update(self, payload: dict):
        self.updated_payload = payload
        return self

    def eq(self, field: str, value: str):
        self.eq_calls.append((field, value))
        return self

    def execute(self):
        return self


class _FakeSupabase:
    def __init__(self, users: list[_FakeUser]) -> None:
        self.auth = _FakeAuth(users)
        self.users_table = _FakeTable()

    def table(self, name: str) -> _FakeTable:
        assert name == "users"
        return self.users_table


def test_build_demo_medications_returns_two_items() -> None:
    medications = build_demo_medications("user-123")

    assert len(medications) == 2
    assert {item["name"] for item in medications} == {"Amlodipine", "Metformin"}


def test_build_demo_schedules_uses_medication_ids() -> None:
    schedules = build_demo_schedules(
        "user-123",
        {"Amlodipine": "med-1", "Metformin": "med-2"},
    )

    assert [item["medication_id"] for item in schedules] == ["med-1", "med-2"]


def test_build_demo_logs_returns_two_taken_logs() -> None:
    logs = build_demo_logs("user-123", ["schedule-1", "schedule-2"])

    assert len(logs) == 2
    assert all(item["status"] == "taken" for item in logs)


def test_build_demo_health_event_and_alert_log_have_expected_links() -> None:
    health_event = build_demo_health_event("user-123", "log-123")
    alert_log = build_demo_alert_log("user-123", "event-123")

    assert health_event["medication_log_id"] == "log-123"
    assert alert_log["health_event_id"] == "event-123"


def test_ensure_demo_user_reuses_existing_auth_user() -> None:
    existing_user = _FakeUser("existing-user-id", DEMO_USER["email"])
    fake_db = _FakeSupabase([existing_user])

    user_id = ensure_demo_user(fake_db)

    assert user_id == "existing-user-id"
    assert fake_db.auth.admin.create_payload is None
    assert fake_db.users_table.updated_payload["name"] == DEMO_USER["name"]


def test_ensure_demo_user_creates_missing_auth_user() -> None:
    fake_db = _FakeSupabase([])

    user_id = ensure_demo_user(fake_db)

    assert user_id == "demo-user-id"
    assert fake_db.auth.admin.create_payload["email"] == DEMO_USER["email"]
    assert fake_db.users_table.eq_calls == [("id", "demo-user-id")]
