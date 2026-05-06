import json

import httpx

from app.core.config import settings
from app.models.medication import DrugInfo

_MODEL = "google/gemini-2.0-flash-exp:free"

_SYSTEM_PROMPT = """You are a pharmacist AI assistant helping elderly users in Taiwan.
Query the drug databases provided as tools, then explain the medication in simple language.
Pay special attention to side effects and warnings relevant to elderly patients.
Return ONLY valid JSON with this schema:
{
  "main_effects": "simple explanation of what this drug does",
  "side_effects": ["list of notable side effects"],
  "warnings": ["important warnings"],
  "elderly_notes": "specific notes for elderly patients",
  "interactions": ["known drug interactions"],
  "source": "OpenFDA / Taiwan FDA / Combined"
}"""

_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "query_openfda",
            "description": "Query OpenFDA drug label database to get official drug information",
            "parameters": {
                "type": "object",
                "properties": {
                    "drug_name": {"type": "string", "description": "Drug name in English"},
                },
                "required": ["drug_name"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "query_taiwan_fda",
            "description": "Query Taiwan FDA database for Taiwan-specific drugs",
            "parameters": {
                "type": "object",
                "properties": {
                    "drug_name": {"type": "string", "description": "Drug name in Chinese or English"},
                },
                "required": ["drug_name"],
            },
        },
    },
]


async def _call_openfda(drug_name: str) -> dict:
    url = "https://api.fda.gov/drug/label.json"
    params = {"search": f'brand_name:"{drug_name}"+OR+generic_name:"{drug_name}"', "limit": 1}
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(url, params=params)
        if resp.status_code == 200:
            results = resp.json().get("results", [])
            if results:
                r = results[0]
                return {
                    "indications": r.get("indications_and_usage", [""])[0][:500],
                    "warnings": r.get("warnings", [""])[0][:500],
                    "side_effects": r.get("adverse_reactions", [""])[0][:500],
                }
    return {"error": "Not found in OpenFDA"}


async def _call_taiwan_fda(drug_name: str) -> dict:
    url = "https://data.fda.gov.tw/codedata/datadownload/datadownload10.json"
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(url)
        if resp.status_code == 200:
            items = resp.json().get("item", [])
            match = next(
                (i for i in items if drug_name.lower() in i.get("drug_name", "").lower()),
                None,
            )
            if match:
                return {"drug_name": match.get("drug_name"), "ingredients": match.get("ingredient")}
    return {"error": "Not found in Taiwan FDA"}


async def _call_openrouter(messages: list, tools: list | None = None) -> dict:
    body = {"model": _MODEL, "messages": messages}
    if tools:
        body["tools"] = tools

    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={"Authorization": f"Bearer {settings.openrouter_api_key}"},
            json=body,
        )
        resp.raise_for_status()
        return resp.json()


async def get_drug_info(drug_name: str, drug_name_zh: str | None = None) -> DrugInfo:
    search_name = drug_name_zh or drug_name
    messages = [
        {"role": "system", "content": _SYSTEM_PROMPT},
        {"role": "user", "content": f"Get drug information for: {search_name}"},
    ]

    while True:
        response = await _call_openrouter(messages, tools=_TOOLS)
        choice = response["choices"][0]
        message = choice["message"]

        # No tool calls → final answer
        if not message.get("tool_calls"):
            raw = message["content"].strip()
            if raw.startswith("```"):
                raw = raw.split("```")[1]
                if raw.startswith("json"):
                    raw = raw[4:]
            return DrugInfo(**json.loads(raw.strip()))

        # Process tool calls
        messages.append(message)
        for tool_call in message["tool_calls"]:
            fn_name = tool_call["function"]["name"]
            fn_args = json.loads(tool_call["function"]["arguments"])

            if fn_name == "query_openfda":
                result = await _call_openfda(fn_args["drug_name"])
            elif fn_name == "query_taiwan_fda":
                result = await _call_taiwan_fda(fn_args["drug_name"])
            else:
                result = {"error": "Unknown tool"}

            messages.append({
                "role": "tool",
                "tool_call_id": tool_call["id"],
                "content": json.dumps(result),
            })
