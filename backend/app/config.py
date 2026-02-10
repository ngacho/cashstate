"""Application configuration using pydantic-settings."""

from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Supabase API Keys
    supabase_url: str
    supabase_secret_key: str  # For auth operations only
    supabase_service_role_key: str  # Service role key - bypasses RLS, use for backend operations
    supabase_publishable_key: str = ""  # Anon key

    # Plaid
    plaid_client_id: str
    plaid_secret: str
    plaid_env: str = "sandbox"  # sandbox, development, production

    # App
    app_name: str = "CashState"
    app_env: str = "development"
    debug: bool = True

    # Server
    host: str = "0.0.0.0"
    port: int = 8000

    # API
    api_v1_prefix: str = "/app/v1"

    # Encryption
    encryption_key: str  # Fernet key for encrypting sensitive data (Plaid tokens, etc.)

    @property
    def is_development(self) -> bool:
        return self.app_env == "development"

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
