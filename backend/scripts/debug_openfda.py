import asyncio
import json
import sys
from pathlib import Path
from urllib.parse import urlencode

import httpx

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.services.drug_agent import _first_text

OPENFDA_URL = "https://api.fda.gov/drug/label.json"


async def fetch_query(client: httpx.AsyncClient, label: str, search: str) -> None:
    params = {"search": search, "limit": 1}
    response = await client.get(OPENFDA_URL, params=params)

    print(f"\n=== {label} ===")
    print(f"GET {OPENFDA_URL}?{urlencode(params)}")
    print(f"STATUS: {response.status_code}")

    if response.status_code != 200:
        print(response.text[:1000])
        return

    payload = response.json()
    results = payload.get("results", [])
    print(f"MATCHES RETURNED: {len(results)}")
    if not results:
        return

    record = results[0]
    preview = {
        "openfda.brand_name": record.get("openfda", {}).get("brand_name"),
        "openfda.generic_name": record.get("openfda", {}).get("generic_name"),
        "indications": _first_text(record, "indications_and_usage", "purpose", "description")[:300],
        "warnings": _first_text(record, "warnings", "warnings_and_cautions", "boxed_warning")[:300],
        "side_effects": _first_text(record, "adverse_reactions")[:300],
        "geriatric_use": _first_text(record, "geriatric_use")[:300],
        "interactions": _first_text(record, "drug_interactions", "drug_and_or_laboratory_test_interactions")[:300],
    }
    print(json.dumps(preview, indent=2, ensure_ascii=False))


async def main(drug_name: str) -> None:
    queries = [
        ("brand_name only", f'openfda.brand_name:"{drug_name}"'),
        ("generic_name only", f'openfda.generic_name:"{drug_name}"'),
        ("brand OR generic", f'openfda.brand_name:"{drug_name}"+OR+openfda.generic_name:"{drug_name}"'),
    ]

    async with httpx.AsyncClient(timeout=20) as client:
        for label, search in queries:
            await fetch_query(client, label, search)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: uv run python scripts/debug_openfda.py <drug name>")
        raise SystemExit(1)

    asyncio.run(main(sys.argv[1]))
