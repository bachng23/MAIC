from fastapi.testclient import TestClient

from app.api.deps import get_current_user
from main import app


class _AuthUser:
    def __init__(self, user_id: str, email: str) -> None:
        self.id = user_id
        self.email = email


class _AuthSession:
    def __init__(self, access_token: str) -> None:
        self.access_token = access_token


class _AuthResponse:
    def __init__(self, user_id: str = "user-123", email: str = "elder@example.com", access_token: str = "token-123") -> None:
        self.user = _AuthUser(user_id, email)
        self.session = _AuthSession(access_token)


class _AuthOnlyClient:
    def __init__(self) -> None:
        self.auth = self
        self.login_payload = None
        self.users_table = _UsersUpdateTable()

    def sign_in_with_password(self, payload: dict) -> _AuthResponse:
        self.login_payload = payload
        return _AuthResponse(access_token="login-token-123")

    def table(self, name: str):
        assert name == "users"
        return self.users_table


class _UsersUpdateTable:
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


class _Response:
    def __init__(self, data):
        self.data = data


class _MedicationsTable:
    def __init__(self) -> None:
        self.insert_payload = None
        self.update_payload = None
        self.filters: list[tuple[str, object]] = []

    def insert(self, payload: dict):
        self.insert_payload = payload
        return self

    def update(self, payload: dict):
        self.update_payload = payload
        return self

    def select(self, _fields: str):
        return self

    def eq(self, field: str, value):
        self.filters.append((field, value))
        return self

    def execute(self):
        if self.insert_payload is not None:
            row = {"id": "med-123", "is_active": True, **self.insert_payload}
            return _Response([row])

        if self.update_payload is not None:
            return _Response([{"id": "med-123"}])

        return _Response([{
            "id": "med-123",
            "user_id": "user-123",
            "name": "Aspirin",
            "name_zh": "阿斯匹靈",
            "dosage": "100mg",
            "drug_info": None,
            "source_image_url": None,
            "is_active": True,
        }])


class _ScheduleLookupTable:
    def __init__(self, rows: list[dict]) -> None:
        self.rows = rows
        self.insert_payload = None
        self.filters: list[tuple[str, object]] = []

    def select(self, _fields: str):
        return self

    def eq(self, field: str, value):
        self.filters.append((field, value))
        return self

    def insert(self, payload: dict):
        self.insert_payload = payload
        return self

    def execute(self):
        if self.insert_payload is not None:
            return _Response([{"id": "schedule-123", "user_id": "user-123", "is_active": True, **self.insert_payload}])
        return _Response(self.rows)


class _LogsTable:
    def __init__(self) -> None:
        self.insert_payload = None

    def select(self, _fields: str):
        return self

    def eq(self, _field: str, _value):
        return self

    def insert(self, payload: dict):
        self.insert_payload = payload
        return self

    def execute(self):
        if self.insert_payload is not None:
            return _Response([{"id": "log-456"}])
        return _Response([{
            "id": "log-456",
            "user_id": "user-123",
            "schedule_id": "schedule-123",
            "status": "taken",
            "monitoring_start": "2026-05-06T08:00:00+00:00",
            "monitoring_end": "2026-05-06T10:00:00+00:00",
        }])


class _HealthEventsTable:
    def __init__(self) -> None:
        self.update_payload = None

    def update(self, payload: dict):
        self.update_payload = payload
        return self

    def eq(self, _field: str, _value):
        return self

    def is_(self, _field: str, _value):
        return self

    def execute(self):
        return _Response([{"id": "event-123"}])


class _EmergencyUsersTable:
    def __init__(self) -> None:
        self.updated_payload = None

    def select(self, _fields: str):
        return self

    def update(self, payload: dict):
        self.updated_payload = payload
        return self

    def eq(self, _field: str, _value):
        return self

    def single(self):
        return self

    def execute(self):
        if self.updated_payload is not None:
            return _Response({"id": "user-123"})
        return _Response({
            "emergency_contacts": [
                {"name": "Li Wei", "phone": "+886923456789", "relation": "son"},
                {"name": "Wang Shu-Hua", "phone": "+886934567890", "relation": "daughter"},
            ]
        })


class _CrudSupabase:
    def __init__(self) -> None:
        self.medications = _MedicationsTable()
        self.schedules = _ScheduleLookupTable([{
            "id": "schedule-123",
            "user_id": "user-123",
            "medication_id": "med-123",
            "times": ["08:00"],
            "days_of_week": [1, 3, 5],
            "is_active": True,
        }])
        self.logs = _LogsTable()
        self.health_events = _HealthEventsTable()
        self.users = _EmergencyUsersTable()

    def table(self, name: str):
        mapping = {
            "medications": self.medications,
            "schedules": self.schedules,
            "medication_logs": self.logs,
            "health_events": self.health_events,
            "users": self.users,
        }
        return mapping[name]


def test_login_returns_access_token(monkeypatch) -> None:
    client = TestClient(app)
    fake_db = _AuthOnlyClient()
    monkeypatch.setattr("app.api.v1.auth.get_supabase", lambda: fake_db)

    response = client.post(
        "/api/v1/auth/login",
        json={"email": "elder@example.com", "password": "strong-password"},
    )

    assert response.status_code == 200
    assert response.json()["data"]["access_token"] == "login-token-123"
    assert fake_db.login_payload == {"email": "elder@example.com", "password": "strong-password"}


def test_update_apns_token_persists_value(monkeypatch) -> None:
    client = TestClient(app)
    fake_db = _AuthOnlyClient()
    monkeypatch.setattr("app.api.v1.auth.get_supabase", lambda: fake_db)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    response = client.put("/api/v1/auth/apns-token", json={"apns_token": "device-token-123"})

    app.dependency_overrides.clear()

    assert response.status_code == 200
    assert fake_db.users_table.updated_payload == {"apns_token": "device-token-123"}


def test_scan_medication_returns_mocked_ocr_result(monkeypatch) -> None:
    client = TestClient(app)

    async def _fake_parse_medication_image(_image_base64: str, _user_id: str):
        return {
            "name": "Aspirin",
            "name_zh": "阿斯匹靈",
            "dosage": "100mg",
            "frequency": "once daily",
            "expiry_date": None,
            "manufacturer": None,
            "warnings": ["take with food"],
            "source_image_url": None,
        }

    monkeypatch.setattr("app.api.v1.medications.parse_medication_image", _fake_parse_medication_image)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    response = client.post("/api/v1/medications/scan", json={"image_base64": "abc"})

    app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["data"]["name"] == "Aspirin"


def test_drug_info_returns_mocked_agent_result(monkeypatch) -> None:
    client = TestClient(app)

    async def _fake_get_drug_info(_drug_name: str, _drug_name_zh: str | None):
        return {
            "main_effects": "Pain relief",
            "side_effects": ["nausea"],
            "warnings": ["take with food"],
            "elderly_notes": "Monitor stomach upset.",
            "interactions": ["warfarin"],
            "source": "Combined",
        }

    monkeypatch.setattr("app.api.v1.medications.get_drug_info", _fake_get_drug_info)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    response = client.post("/api/v1/medications/drug-info", json={"drug_name": "Aspirin"})

    app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["data"]["source"] == "Combined"


def test_medication_crud_and_list_routes(monkeypatch) -> None:
    client = TestClient(app)
    fake_db = _CrudSupabase()
    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    create_response = client.post(
        "/api/v1/medications",
        json={"name": "Aspirin", "name_zh": "阿斯匹靈", "dosage": "100mg"},
    )
    list_response = client.get("/api/v1/medications")
    delete_response = client.delete("/api/v1/medications/med-123")

    app.dependency_overrides.clear()

    assert create_response.status_code == 200
    assert create_response.json()["data"]["id"] == "med-123"
    assert list_response.status_code == 200
    assert list_response.json()["data"][0]["name"] == "Aspirin"
    assert delete_response.status_code == 200
    assert fake_db.medications.update_payload == {"is_active": False}


def test_list_schedules_and_log_skipped(monkeypatch) -> None:
    client = TestClient(app)
    fake_db = _CrudSupabase()

    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    list_response = client.get("/api/v1/schedules")
    skip_response = client.post("/api/v1/logs/skipped", json={"schedule_id": "schedule-123"})

    app.dependency_overrides.clear()

    assert list_response.status_code == 200
    assert list_response.json()["data"][0]["id"] == "schedule-123"
    assert skip_response.status_code == 200
    assert fake_db.logs.insert_payload["status"] == "skipped"


def test_emergency_contacts_routes(monkeypatch) -> None:
    client = TestClient(app)
    fake_db = _CrudSupabase()

    monkeypatch.setattr("app.api.v1.emergency.get_supabase", lambda: fake_db)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    get_response = client.get("/api/v1/emergency/contacts")
    put_response = client.put(
        "/api/v1/emergency/contacts",
        json={"contacts": [{"name": "New Contact", "phone": "+886900000000", "relation": "friend"}]},
    )

    app.dependency_overrides.clear()

    assert get_response.status_code == 200
    assert len(get_response.json()["data"]) == 2
    assert put_response.status_code == 200
    assert fake_db.users.updated_payload == {
        "emergency_contacts": [{"name": "New Contact", "phone": "+886900000000", "relation": "friend"}]
    }


def test_resolve_health_alert_updates_event(monkeypatch) -> None:
    client = TestClient(app)
    fake_db = _CrudSupabase()

    monkeypatch.setattr("app.api.v1.health.get_supabase", lambda: fake_db)
    monkeypatch.setattr("app.api.v1.medications.get_supabase", lambda: fake_db)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    response = client.post("/api/v1/health/resolve", json={"log_id": "log-456"})

    app.dependency_overrides.clear()

    assert response.status_code == 200
    assert "resolved_at" in fake_db.health_events.update_payload
