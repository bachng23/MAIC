import base64
import json
import uuid

import httpx

from app.core.config import settings
from app.db.client import get_supabase
from app.models.medication import OCRScanResult

# Free vision models on OpenRouter — ordered by preference for Chinese text
# Switch to Apple Vision (on-device) when frontend Platform Channel is ready
_OCR_MODEL = "baidu/qianfan-ocr-fast:free"
_FALLBACK_MODEL = "nvidia/nemotron-nano-12b-v2-vl:free"

_BUCKET = "medication-images"

_PROMPT = """Extract medication information from this image of a medicine box or pharmacy receipt.
Return ONLY valid JSON with this exact schema, no explanation:
{
  "name": "drug name in Latin/English",
  "name_zh": "Chinese name if visible, else null",
  "dosage": "dosage per intake e.g. 500mg, null if not found",
  "frequency": "frequency e.g. 3 times/day, null if not found",
  "expiry_date": "YYYY-MM format or null",
  "manufacturer": "manufacturer name or null",
  "warnings": ["important warnings visible on box"]
}"""

def _detect_media_type(image_data: str) -> str:
    if image_data.startswith("/9j/"):
        return "image/jpeg"
    if image_data.startswith("iVBORw"):
        return "image/png"
    if image_data.startswith("UklGR"):
        return "image/webp"
    return "image/jpeg"


async def _upload_to_storage(image_data: str, user_id: str) -> str | None:
    try:
        raw_bytes = base64.b64decode(image_data)
        media_type = _detect_media_type(image_data)
        ext = media_type.split("/")[1]
        path = f"{user_id}/{uuid.uuid4()}.{ext}"

        db = get_supabase()
        db.storage.from_(_BUCKET).upload(
            path=path,
            file=raw_bytes,
            file_options={"content-type": media_type},
        )
        signed = db.storage.from_(_BUCKET).create_signed_url(path, expires_in=31536000)
        return signed.get("signedURL")
    except Exception:
        return None  # Storage failure không block OCR


async def _call_openrouter(image_data: str, media_type: str, model: str) -> dict:
    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {settings.openrouter_api_key}",
                "HTTP-Referer": "https://mediguard.app",
            },
            json={
                "model": model,
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "image_url",
                                "image_url": {"url": f"data:{media_type};base64,{image_data}"},
                            },
                            {"type": "text", "text": _PROMPT},
                        ],
                    }
                ],
            },
        )
        if not resp.is_success:
            print(f"OpenRouter [{model}] error {resp.status_code}: {resp.text}")
            resp.raise_for_status()
        return resp.json()


async def parse_medication_image(image_base64: str, user_id: str) -> OCRScanResult:
    image_data = image_base64.split(",")[-1]  # strip data URI prefix if present
    media_type = _detect_media_type(image_data)

    image_url = await _upload_to_storage(image_data, user_id)

    try:
        result = await _call_openrouter(image_data, media_type, _OCR_MODEL)
    except Exception:
        result = await _call_openrouter(image_data, media_type, _FALLBACK_MODEL)

    raw_text = result["choices"][0]["message"]["content"].strip()

    # Strip markdown code block if model wraps output in ```json ... ```
    if raw_text.startswith("```"):
        raw_text = raw_text.split("```")[1]
        if raw_text.startswith("json"):
            raw_text = raw_text[4:]

    data = json.loads(raw_text.strip())
    return OCRScanResult(**data, source_image_url=image_url)
