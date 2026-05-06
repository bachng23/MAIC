import os
import sys
from pathlib import Path


BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))


os.environ.setdefault("SUPABASE_URL", "https://example.supabase.co")
os.environ.setdefault("SUPABASE_SERVICE_KEY", "test-service-key")
os.environ.setdefault("OPENROUTER_API_KEY", "test-openrouter-key")
os.environ.setdefault("APNS_KEY_ID", "TESTKEY123")
os.environ.setdefault("APNS_TEAM_ID", "TESTTEAM123")
os.environ.setdefault("APNS_BUNDLE_ID", "com.example.mediguard")
os.environ.setdefault("APNS_KEY_PATH", "./apns_key.p8")
os.environ.setdefault("APNS_USE_SANDBOX", "true")
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("SCHEDULER_ENABLED", "false")
os.environ.setdefault("APP_TIMEZONE", "Asia/Taipei")
os.environ.setdefault("SECRET_KEY", "test-secret-key")
