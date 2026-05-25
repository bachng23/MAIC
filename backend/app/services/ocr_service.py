import base64
import json
import re
import uuid

import httpx

from app.core.config import settings
from app.db.client import get_supabase
from app.models.medication import OCRScanResult

# ---------------------------------------------------------------------------
# Model selection — only IDs confirmed available on OpenRouter free tier
#   Vision primary : baidu/qianfan-ocr-fast  — strong on Chinese pharmacy labels
#   Vision fallback: nvidia/nemotron-nano-12b — multimodal fallback
#   Text-only      : google/gemma-3-12b-it   — fast text parser (no vision needed)
# ---------------------------------------------------------------------------
_VISION_PRIMARY  = "baidu/qianfan-ocr-fast:free"
_VISION_FALLBACK = "nvidia/nemotron-nano-12b-v2-vl:free"
_TEXT_MODEL      = "google/gemma-3-12b-it:free"

_BUCKET = "medication-images"

# ---------------------------------------------------------------------------
# Shared parsing prompt — used for both vision and text-only paths.
# Handles Taiwanese pharmacy receipt format:
#   • "#" suffix  → grams per dose (e.g. "Amoxicillin 9.00#" = 9 g total / 3 days)
#   • "(NxM)"     → N tablets per intake × M times per day  (e.g. "(3x3)")
#   • A.C. / P.C. → before / after meals
#   • P.R.N.      → as needed
#   • Shared frequency lines (e.g. "以下藥物 每天3次") apply to following meds
# ---------------------------------------------------------------------------
_SHARED_RULES = """
EXTRACTION RULES (Taiwanese pharmacy format):
- "#" after a number = grams total (e.g. "Amoxicillin 9.00#(3x3)" → dosage "9g total", frequency "3 times/day")
- "(NxM)" = N tablets per dose × M times per day (e.g. "(1x3)" → "1 tablet 3 times/day")
- A.C. = before meals; P.C. = after meals; P.R.N. = as needed; Q.D. = once/day; B.I.D. = twice/day; T.I.D. = 3×/day
- A shared frequency line (e.g. "每天三次" or "3 times/day") applies to all following medications until a new frequency appears
- Ignore lot numbers, barcodes, patient IDs, and dispensing-date lines
- If a medication has a condition trigger (e.g. "fever ≥38°C"), put it in frequency as a note
- Return an empty array [] if no medication names are found
"""

_VISION_PROMPT = f"""You are a pharmacy OCR assistant. Extract ALL medications listed on this prescription or pharmacy receipt label.
{_SHARED_RULES}
Return ONLY a valid JSON array — no markdown, no explanation:
[
  {{
    "name": "drug name in Latin/English",
    "name_zh": "Chinese name if visible, else null",
    "dosage": "dose per intake e.g. '500mg' or '1 tablet', null if unknown",
    "frequency": "e.g. '3 times/day after meals', null if unknown",
    "expiry_date": "YYYY-MM or null",
    "manufacturer": "manufacturer name or null",
    "warnings": ["any warnings visible on label"]
  }}
]"""

_TEXT_PROMPT = f"""You are a pharmacy OCR assistant. Extract ALL medications from the following raw text from a pharmacy label or prescription.
{_SHARED_RULES}
RAW TEXT:
{{ocr_text}}

Return ONLY a valid JSON array — no markdown, no explanation:
[
  {{
    "name": "drug name in Latin/English",
    "name_zh": "Chinese name if visible, else null",
    "dosage": "dose per intake, null if unknown",
    "frequency": "e.g. '3 times/day after meals', null if unknown",
    "expiry_date": "YYYY-MM or null",
    "manufacturer": null,
    "warnings": []
  }}
]"""


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
        return None  # Storage failure doesn't block OCR


async def _call_openrouter_vision(image_data: str, media_type: str, model: str) -> dict:
    """Send base64 image to OpenRouter vision model."""
    async with httpx.AsyncClient(timeout=90) as client:
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
                            {"type": "text", "text": _VISION_PROMPT},
                        ],
                    }
                ],
            },
        )
        if not resp.is_success:
            print(f"OpenRouter vision [{model}] error {resp.status_code}: {resp.text}")
            resp.raise_for_status()
        return resp.json()


async def _call_openrouter_text(ocr_text: str, model: str) -> dict:
    """Parse pre-extracted OCR text using a text-only LLM (cheaper, faster)."""
    prompt = _TEXT_PROMPT.replace("{ocr_text}", ocr_text)
    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {settings.openrouter_api_key}",
                "HTTP-Referer": "https://mediguard.app",
            },
            json={
                "model": model,
                "messages": [{"role": "user", "content": prompt}],
            },
        )
        if not resp.is_success:
            print(f"OpenRouter text [{model}] error {resp.status_code}: {resp.text}")
            resp.raise_for_status()
        return resp.json()


def _parse_llm_response(raw_text: str, image_url: str | None) -> list[OCRScanResult]:
    """Parse LLM JSON output → list[OCRScanResult]. Tolerates single-object responses."""
    # Strip markdown code fences
    text = raw_text.strip()
    if text.startswith("```"):
        # ```json\n...\n``` → extract inner content
        text = re.sub(r"^```[a-z]*\n?", "", text)
        text = re.sub(r"\n?```$", "", text.strip())

    data = json.loads(text.strip())

    # LLM sometimes returns a single object instead of array — normalise
    if isinstance(data, dict):
        data = [data]

    results = []
    for item in data:
        if not isinstance(item, dict):
            continue
        name = (item.get("name") or "").strip()
        if not name:
            continue  # skip empty entries
        results.append(
            OCRScanResult(
                name=name,
                name_zh=item.get("name_zh") or None,
                dosage=item.get("dosage") or None,
                frequency=item.get("frequency") or None,
                expiry_date=item.get("expiry_date") or None,
                manufacturer=item.get("manufacturer") or None,
                warnings=item.get("warnings") or [],
                source_image_url=image_url,
            )
        )
    return results


async def parse_medication_image(
    image_base64: str | None,
    user_id: str,
    ocr_text: str | None = None,
) -> list[OCRScanResult]:
    """
    Extract medications from a pharmacy image or pre-extracted OCR text.

    Two paths:
    1. ocr_text is provided (from on-device Apple Vision OCR):
       → skip image upload/vision model → text-only LLM parse (fast, cheap)
    2. image_base64 is provided:
       → upload image to storage → vision LLM parse with fallback
    """
    image_url: str | None = None

    if ocr_text:
        # ── Text-only path (Apple Vision pre-extracted) ──────────────────────
        result = await _call_openrouter_text(ocr_text, _TEXT_MODEL)
    else:
        # ── Vision path ──────────────────────────────────────────────────────
        if not image_base64:
            raise ValueError("Either image_base64 or ocr_text must be provided")

        image_data = image_base64.split(",")[-1]  # strip data URI prefix if present
        media_type = _detect_media_type(image_data)
        image_url = await _upload_to_storage(image_data, user_id)

        try:
            result = await _call_openrouter_vision(image_data, media_type, _VISION_PRIMARY)
        except Exception as e:
            print(f"Primary vision model failed ({e}), trying fallback…")
            result = await _call_openrouter_vision(image_data, media_type, _VISION_FALLBACK)

    raw_text = result["choices"][0]["message"]["content"].strip()
    return _parse_llm_response(raw_text, image_url)
