from pydantic import ConfigDict
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    model_config = ConfigDict(env_file=".env")

    supabase_url: str
    supabase_service_key: str

    openrouter_api_key: str

    apns_key_id: str
    apns_team_id: str
    apns_bundle_id: str
    apns_key_path: str
    apns_use_sandbox: bool = True

    app_env: str = "development"
    scheduler_enabled: bool = True
    app_timezone: str = "Asia/Taipei"
    secret_key: str


settings = Settings()
