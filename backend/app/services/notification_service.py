import logging
import time
from functools import lru_cache
from pathlib import Path

import httpx
import jwt

from app.core.config import settings

logger = logging.getLogger(__name__)


def is_apns_configured() -> bool:
    return bool(
        settings.apns_key_id
        and settings.apns_team_id
        and settings.apns_bundle_id
        and settings.apns_key_path
    )


def get_apns_status() -> dict:
    key_path = Path(settings.apns_key_path)
    return {
        "configured": is_apns_configured(),
        "key_path": settings.apns_key_path,
        "key_file_exists": key_path.exists(),
        "bundle_id": settings.apns_bundle_id,
        "sandbox": settings.apns_use_sandbox,
    }


@lru_cache(maxsize=1)
def _load_apns_private_key() -> str | None:
    key_path = Path(settings.apns_key_path)
    if not key_path.exists():
        logger.warning("APNs key file not found at %s", key_path)
        return None

    return key_path.read_text()


def _build_apns_jwt() -> str:
    private_key = _load_apns_private_key()
    if not private_key:
        raise RuntimeError("APNs private key is not available")

    return jwt.encode(
        payload={"iss": settings.apns_team_id, "iat": int(time.time())},
        key=private_key,
        algorithm="ES256",
        headers={"kid": settings.apns_key_id},
    )


async def send_push(apns_token: str, title: str, body: str, data: dict | None = None) -> bool:
    if not _can_send_apns(apns_token):
        return False

    host = "api.sandbox.push.apple.com" if settings.apns_use_sandbox else "api.push.apple.com"
    url = f"https://{host}/3/device/{apns_token}"

    payload = {
        "aps": {
            "alert": {"title": title, "body": body},
            "sound": "default",
            "badge": 1,
        },
        **(data or {}),
    }

    headers = {
        "authorization": f"bearer {_build_apns_jwt()}",
        "apns-topic": settings.apns_bundle_id,
        "apns-push-type": "alert",
    }

    return await _post_apns_payload(url, payload, headers)


async def send_silent_push(apns_token: str, data: dict) -> bool:
    """Silent push for emergency triggers — app handles the action."""
    if not _can_send_apns(apns_token):
        return False

    host = "api.sandbox.push.apple.com" if settings.apns_use_sandbox else "api.push.apple.com"
    url = f"https://{host}/3/device/{apns_token}"

    payload = {
        "aps": {"content-available": 1, "sound": ""},
        **data,
    }

    headers = {
        "authorization": f"bearer {_build_apns_jwt()}",
        "apns-topic": settings.apns_bundle_id,
        "apns-push-type": "background",
        "apns-priority": "5",
    }

    return await _post_apns_payload(url, payload, headers)


async def send_medication_reminder_push(
    apns_token: str,
    medication_name: str,
    dosage: str | None,
    schedule_id: str,
    scheduled_time: str,
) -> bool:
    body = medication_name if not dosage else f"{medication_name} ({dosage})"
    return await send_push(
        apns_token,
        title="Medication Reminder",
        body=f"It's time to take {body}.",
        data={
            "action": "medication_reminder",
            "schedule_id": schedule_id,
            "scheduled_time": scheduled_time,
        },
    )


def _can_send_apns(apns_token: str | None) -> bool:
    if not apns_token:
        logger.warning("Skipping APNs push because device token is missing")
        return False

    if not is_apns_configured():
        logger.warning("Skipping APNs push because APNs settings are incomplete")
        return False

    try:
        _build_apns_jwt()
    except Exception as exc:
        logger.warning("Skipping APNs push because JWT generation failed: %s", exc)
        return False

    return True


async def _post_apns_payload(url: str, payload: dict, headers: dict[str, str]) -> bool:
    try:
        async with httpx.AsyncClient(http2=True) as client:
            resp = await client.post(url, json=payload, headers=headers, timeout=10)
    except httpx.HTTPError as exc:
        logger.warning("APNs request failed: %s", exc)
        return False

    if resp.status_code != 200:
        logger.warning("APNs rejected request with status %s: %s", resp.status_code, resp.text)
        return False

    return True
