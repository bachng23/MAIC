import logging

import httpx

from app.models.medication import DrugInfo

logger = logging.getLogger(__name__)


async def _call_openfda(drug_name: str) -> dict:
    url = "https://api.fda.gov/drug/label.json"
    params = {
        "search": f'openfda.brand_name:"{drug_name}"+openfda.generic_name:"{drug_name}"',
        "limit": 1,
    }
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url, params=params)
            if resp.status_code == 200:
                results = resp.json().get("results", [])
                if results:
                    record = results[0]
                    warnings = _first_text(record, "warnings", "warnings_and_cautions", "boxed_warning")
                    side_effects = _first_text(record, "adverse_reactions")
                    indications = _first_text(record, "indications_and_usage", "purpose", "description")
                    geriatric_use = _first_text(record, "geriatric_use")
                    interactions = _first_text(record, "drug_interactions", "drug_and_or_laboratory_test_interactions")
                    return {
                        "indications": indications[:500],
                        "warnings": warnings[:500],
                        "side_effects": side_effects[:500],
                        "geriatric_use": geriatric_use[:500],
                        "interactions": interactions[:500],
                    }
    except Exception as exc:
        logger.warning("OpenFDA lookup failed for %s: %s", drug_name, exc)

    return {"error": "Not found in OpenFDA"}


async def _call_taiwan_fda(drug_name: str) -> dict:
    url = "https://data.fda.gov.tw/codedata/datadownload/datadownload10.json"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url)
            if resp.status_code == 200:
                payload = resp.json()
                items = payload.get("item", []) if isinstance(payload, dict) else payload if isinstance(payload, list) else []
                match = next(
                    (
                        item
                        for item in items
                        if isinstance(item, dict) and drug_name.lower() in str(item.get("drug_name", "")).lower()
                    ),
                    None,
                )
                if match:
                    return {"drug_name": match.get("drug_name"), "ingredients": match.get("ingredient")}
    except Exception as exc:
        logger.warning("Taiwan FDA lookup failed for %s: %s", drug_name, exc)

    return {"error": "Not found in Taiwan FDA"}


def _first_text(record: dict, *field_names: str) -> str:
    for field_name in field_names:
        value = record.get(field_name)
        if isinstance(value, list) and value:
            text = str(value[0]).strip()
            if text:
                return text
        elif isinstance(value, str):
            text = value.strip()
            if text:
                return text
    return ""


def _to_list(value: object) -> list[str]:
    if not value:
        return []
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    return [part.strip() for part in str(value).split(";") if part.strip()]


def _build_direct_drug_info(drug_name: str, openfda: dict, taiwan_fda: dict) -> DrugInfo:
    warnings = _to_list(openfda.get("warnings"))
    side_effects = _to_list(openfda.get("side_effects"))
    interactions = _to_list(openfda.get("interactions"))

    if taiwan_fda.get("ingredients"):
        interactions.append(f"Taiwan FDA ingredients: {taiwan_fda['ingredients']}")

    source_parts = []
    if "error" not in openfda:
        source_parts.append("OpenFDA")
    if "error" not in taiwan_fda:
        source_parts.append("Taiwan FDA")
    source = " / ".join(source_parts) if source_parts else "Fallback"

    main_effects = openfda.get("indications") or f"Information for {drug_name} is temporarily limited. Please verify with a pharmacist."
    elderly_notes = openfda.get("geriatric_use") or "Use extra caution in elderly patients and review dosing, kidney function, and interactions."

    if not warnings:
        warnings = ["Consult a pharmacist if symptoms change or multiple medications are being taken."]
    if not side_effects:
        side_effects = ["Side effects unavailable from live sources."]

    return DrugInfo(
        main_effects=main_effects,
        side_effects=side_effects,
        warnings=warnings,
        elderly_notes=elderly_notes,
        interactions=interactions,
        source=source,
    )


async def get_drug_info(drug_name: str, drug_name_zh: str | None = None) -> DrugInfo:
    search_name = drug_name_zh or drug_name
    openfda_result = await _call_openfda(drug_name)
    taiwan_fda_result = await _call_taiwan_fda(search_name)

    logger.info(
        "Direct drug info lookup for search_name=%s openfda_found=%s taiwan_fda_found=%s",
        search_name,
        "error" not in openfda_result,
        "error" not in taiwan_fda_result,
    )

    if "error" not in openfda_result:
        logger.info("OpenFDA data preview for %s: %s", drug_name, str(openfda_result)[:500])
    else:
        logger.warning("OpenFDA lookup unavailable for %s: %s", drug_name, openfda_result.get("error"))

    if "error" not in taiwan_fda_result:
        logger.info("Taiwan FDA data preview for %s: %s", search_name, str(taiwan_fda_result)[:500])
    else:
        logger.warning("Taiwan FDA lookup unavailable for %s: %s", search_name, taiwan_fda_result.get("error"))

    return _build_direct_drug_info(search_name, openfda_result, taiwan_fda_result)
