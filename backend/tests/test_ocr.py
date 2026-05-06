"""
Quick OCR test — bypass server, gọi service trực tiếp
Chạy: PYTHONPATH=. python3 tests/test_ocr.py [path/to/image.jpg]
"""
import asyncio
import base64
import json
import sys
from pathlib import Path

from dotenv import load_dotenv
load_dotenv()

from app.services.ocr_service import _OCR_MODEL, parse_medication_image

IMAGE_PATH = Path(__file__).parent / "fixtures" / "sample_medicine.jpg"
TEST_USER_ID = "test-user-local"


async def run_ocr_test(image_path: Path) -> None:
    if not image_path.exists():
        print(f"Image not found: {image_path}")
        print("Put any medicine image at tests/fixtures/sample_medicine.jpg")
        sys.exit(1)

    image_b64 = base64.b64encode(image_path.read_bytes()).decode()
    size_kb = image_path.stat().st_size // 1024
    print(f"Testing OCR with: {image_path.name} ({size_kb} KB)")
    print(f"Model: {_OCR_MODEL}\n")

    result = await parse_medication_image(image_b64, TEST_USER_ID)
    print(json.dumps(result.model_dump(), indent=2, ensure_ascii=False))


if __name__ == "__main__":
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else IMAGE_PATH
    asyncio.run(run_ocr_test(path))
