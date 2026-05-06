import argparse
import base64
import json
import os
from pathlib import Path

import httpx


DEFAULT_BASE_URL = os.environ.get("MEDIGUARD_BASE_URL", "http://127.0.0.1:8000")
DEFAULT_EMAIL = os.environ.get("MEDIGUARD_EMAIL")
DEFAULT_PASSWORD = os.environ.get("MEDIGUARD_PASSWORD")
DEFAULT_IMAGE = Path(__file__).resolve().parents[1] / "tests" / "fixtures" / "sample_medicine.jpg"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run OCR -> drug-info pipeline against the deployed backend.")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="Backend base URL.")
    parser.add_argument(
        "--email",
        default=DEFAULT_EMAIL,
        help="Login email. Can also be provided via MEDIGUARD_EMAIL.",
    )
    parser.add_argument(
        "--password",
        default=DEFAULT_PASSWORD,
        help="Login password. Can also be provided via MEDIGUARD_PASSWORD.",
    )
    parser.add_argument("--image", type=Path, default=DEFAULT_IMAGE, help="Path to the medicine image.")
    parser.add_argument("--timeout", type=float, default=60.0, help="HTTP timeout in seconds.")
    return parser.parse_args()


def login(client: httpx.Client, base_url: str, email: str, password: str) -> str:
    response = client.post(
        f"{base_url}/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    response.raise_for_status()
    return response.json()["data"]["access_token"]


def scan_medication(client: httpx.Client, base_url: str, token: str, image_path: Path) -> dict:
    image_b64 = base64.b64encode(image_path.read_bytes()).decode()
    response = client.post(
        f"{base_url}/api/v1/medications/scan",
        headers={"Authorization": f"Bearer {token}"},
        json={"image_base64": image_b64},
    )
    response.raise_for_status()
    return response.json()


def fetch_drug_info(client: httpx.Client, base_url: str, token: str, scan_data: dict) -> dict:
    payload = {"drug_name": scan_data["data"]["name"]}
    if scan_data["data"].get("name_zh"):
        payload["drug_name_zh"] = scan_data["data"]["name_zh"]

    response = client.post(
        f"{base_url}/api/v1/medications/drug-info",
        headers={"Authorization": f"Bearer {token}"},
        json=payload,
    )
    response.raise_for_status()
    return response.json()


def main() -> None:
    args = parse_args()
    image_path = args.image.expanduser().resolve()
    if not image_path.exists():
        raise SystemExit(f"Image not found: {image_path}")
    if not args.email or not args.password:
        raise SystemExit(
            "Missing credentials. Provide --email/--password or set "
            "MEDIGUARD_EMAIL and MEDIGUARD_PASSWORD."
        )

    with httpx.Client(timeout=args.timeout) as client:
        token = login(client, args.base_url, args.email, args.password)
        scan_data = scan_medication(client, args.base_url, token, image_path)
        drug_info = fetch_drug_info(client, args.base_url, token, scan_data)

    print("OCR RESULT")
    print(json.dumps(scan_data, indent=2, ensure_ascii=False))
    print()
    print("DRUG INFO RESULT")
    print(json.dumps(drug_info, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
