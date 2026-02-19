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
    supabase_secret_key: str  # For GoTrue auth operations (sign_up, sign_in, refresh)
    supabase_publishable_key: str  # Anon/publishable key for client requests

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

    # AI Categorization
    categorization_provider: str = "claude"  # Provider: "claude" or "openrouter"
    anthropic_api_key: str | None = (
        None  # Anthropic API key for Claude AI categorization
    )
    claude_model: str = "claude-3-5-sonnet-20241022"  # Claude model for categorization
    openrouter_api_key: str | None = (
        None  # OpenRouter API key for cheaper categorization
    )
    openrouter_model: str = (
        "meta-llama/llama-3.1-8b-instruct:free"  # OpenRouter model (free tier default)
    )

    # SimpleFin (optional, for development/testing only)
    simplefin_access_url: str | None = None  # Pre-claimed access URL for dev/test

    # Cron Jobs
    enable_cron_jobs: bool = True  # Enable/disable scheduled background tasks

    @property
    def is_development(self) -> bool:
        """Check if running in development mode."""
        return self.app_env == "development"

    @property
    def is_production(self) -> bool:
        """Check if running in production mode."""
        return self.app_env == "production"


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
