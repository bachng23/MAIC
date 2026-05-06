from fastapi.testclient import TestClient

from app.api.deps import get_current_user
from main import app


class _FakeUser:
    def __init__(self, user_id: str, email: str) -> None:
        self.id = user_id
        self.email = email


class _FakeSession:
    def __init__(self, access_token: str) -> None:
        self.access_token = access_token


class _FakeAuthResponse:
    def __init__(self, user_id: str, email: str, access_token: str) -> None:
        self.user = _FakeUser(user_id, email)
        self.session = _FakeSession(access_token)


class _FakeTable:
    def __init__(self) -> None:
        self.updated_payload = None
        self.eq_calls: list[tuple[str, str]] = []
        self.execute_called = False
        self.insert_called = False

    def update(self, payload: dict):
        self.updated_payload = payload
        return self

    def insert(self, payload: dict):
        self.insert_called = True
        raise AssertionError("register should not insert into public.users directly")

    def eq(self, field: str, value: str):
        self.eq_calls.append((field, value))
        return self

    def execute(self):
        self.execute_called = True
        return self


class _FakeAuth:
    def __init__(self, response: _FakeAuthResponse) -> None:
        self.response = response
        self.sign_up_payload = None

    def sign_up(self, payload: dict) -> _FakeAuthResponse:
        self.sign_up_payload = payload
        return self.response


class _FakeSupabase:
    def __init__(self) -> None:
        self.users_table = _FakeTable()
        self.auth = _FakeAuth(
            _FakeAuthResponse(
                user_id="user-123",
                email="elder@example.com",
                access_token="access-token-123",
            )
        )

    def table(self, name: str) -> _FakeTable:
        assert name == "users"
        return self.users_table


def test_register_updates_profile_row_created_by_trigger(monkeypatch) -> None:
    fake_db = _FakeSupabase()
    client = TestClient(app)

    def _fake_get_supabase():
        return fake_db

    monkeypatch.setattr("app.api.v1.auth.get_supabase", _fake_get_supabase)

    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "elder@example.com",
            "password": "strong-password",
            "name": "Elder User",
            "phone": "0912345678",
            "language": "zh-TW",
        },
    )

    assert response.status_code == 200
    assert response.json()["data"]["access_token"] == "access-token-123"
    assert fake_db.auth.sign_up_payload == {
        "email": "elder@example.com",
        "password": "strong-password",
    }
    assert fake_db.users_table.updated_payload == {
        "name": "Elder User",
        "phone": "0912345678",
        "language": "zh-TW",
    }
    assert fake_db.users_table.eq_calls == [("id", "user-123")]
    assert fake_db.users_table.execute_called is True


def test_apns_status_returns_configuration_snapshot(monkeypatch) -> None:
    client = TestClient(app)

    monkeypatch.setattr(
        "app.api.v1.auth.get_apns_status",
        lambda: {
            "configured": True,
            "key_path": "./apns_key.p8",
            "key_file_exists": True,
            "bundle_id": "com.example.mediguard",
            "sandbox": True,
        },
    )
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-123", "email": "elder@example.com"}

    response = client.get("/api/v1/auth/apns-status")

    app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["data"]["configured"] is True
    assert response.json()["data"]["user_id"] == "user-123"
