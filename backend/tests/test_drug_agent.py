import pytest

from app.services import drug_agent


@pytest.mark.anyio
async def test_call_taiwan_fda_accepts_list_payload(monkeypatch) -> None:
    class _FakeResponse:
        status_code = 200

        @staticmethod
        def json():
            return [
                {"drug_name": "Aspirin", "ingredient": "acetylsalicylic acid"},
                {"drug_name": "Zinc", "ingredient": "zinc gluconate"},
            ]

    class _FakeClient:
        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, _url, **_kwargs):
            return _FakeResponse()

    monkeypatch.setattr("app.services.drug_agent.httpx.AsyncClient", lambda timeout=10: _FakeClient())

    result = await drug_agent._call_taiwan_fda("Zinc")

    assert result == {"drug_name": "Zinc", "ingredients": "zinc gluconate"}


def test_extract_json_content_strips_markdown_code_fence() -> None:
    payload = """```json
    {"main_effects":"Pain relief","side_effects":["nausea"],"warnings":["take with food"],"elderly_notes":"Monitor stomach upset.","interactions":["warfarin"],"source":"Combined"}
    ```"""

    result = drug_agent._extract_json_content(payload)

    assert result["main_effects"] == "Pain relief"
    assert result["source"] == "Combined"


@pytest.mark.anyio
async def test_get_drug_info_returns_fallback_when_openrouter_fails(monkeypatch) -> None:
    async def _fake_call_openfda(_drug_name: str) -> dict:
        return {
            "indications": "Pain relief and fever reduction.",
            "warnings": "Take with food; avoid if allergic to NSAIDs.",
            "side_effects": "Nausea; stomach upset.",
        }

    async def _fake_call_taiwan_fda(_drug_name: str) -> dict:
        return {"drug_name": "Aspirin", "ingredients": "acetylsalicylic acid"}

    async def _fake_call_openrouter(_messages, tools=None) -> dict:
        raise RuntimeError("OpenRouter unavailable")

    monkeypatch.setattr("app.services.drug_agent._call_openfda", _fake_call_openfda)
    monkeypatch.setattr("app.services.drug_agent._call_taiwan_fda", _fake_call_taiwan_fda)
    monkeypatch.setattr("app.services.drug_agent._call_openrouter", _fake_call_openrouter)

    result = await drug_agent.get_drug_info("Aspirin")

    assert result.main_effects == "Pain relief and fever reduction."
    assert "Take with food" in result.warnings[0]
    assert result.source == "OpenFDA / Taiwan FDA"
