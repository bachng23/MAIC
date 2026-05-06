import pytest

from app.services import notification_service


def test_can_send_apns_returns_false_without_token() -> None:
    assert notification_service._can_send_apns(None) is False


def test_can_send_apns_returns_false_when_key_file_is_missing(monkeypatch) -> None:
    notification_service._load_apns_private_key.cache_clear()
    monkeypatch.setattr("app.services.notification_service.settings.apns_key_path", "./missing-apns-key.p8")

    assert notification_service._can_send_apns("device-token") is False


@pytest.mark.anyio
async def test_send_push_short_circuits_when_apns_is_unavailable(monkeypatch) -> None:
    monkeypatch.setattr("app.services.notification_service._can_send_apns", lambda _token: False)

    assert await notification_service.send_push(
        "device-token",
        title="Hello",
        body="World",
    ) is False
