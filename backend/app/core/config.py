from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    supabase_url: str
    supabase_service_key: str

    openrouter_api_key: str

    apns_key_id: str
    apns_team_id: str
    apns_bundle_id: str
    apns_key_path: str
    apns_use_sandbox: bool = True

    app_env: str = "development"
    secret_key: str

    class Config:
        env_file = ".env"


settings = Settings()
