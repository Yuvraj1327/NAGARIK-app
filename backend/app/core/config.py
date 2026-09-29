"""
Application configuration.

All configuration is loaded from environment variables (see `.env.example`).
Nothing here should be hardcoded — this is what lets the same codebase run
locally, in CI, and on AWS with only the environment differing.
"""

from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # ---- App ----
    APP_NAME: str = "NAGARIK API"
    ENVIRONMENT: Literal["local", "staging", "production"] = "local"
    DEBUG: bool = True
    API_V1_PREFIX: str = "/api/v1"

    # ---- CORS ----
    # Kept as a raw comma-separated string (not list[str]) because
    # pydantic-settings tries to JSON-decode list-typed env vars before any
    # validator runs, which breaks on a plain "" or "a,b" value from .env.
    # Use the `cors_origins` property below to get the parsed list.
    BACKEND_CORS_ORIGINS: str = ""

    @property
    def cors_origins(self) -> list[str]:
        return [origin.strip() for origin in self.BACKEND_CORS_ORIGINS.split(",") if origin.strip()]

    # ---- Supabase ----
    # Project URL, e.g. https://xxxxx.supabase.co
    SUPABASE_URL: str = ""
    # Public anon key — safe to expose to trusted server-side contexts only
    # (the backend never forwards this to a client; the Flutter app has its own).
    SUPABASE_ANON_KEY: str = ""
    # Service role key — full DB/Storage access, bypasses Row Level Security.
    # NEVER expose this to the Flutter app. Backend-only secret.
    SUPABASE_SERVICE_ROLE_KEY: str = ""
    # Used to verify the JWT issued by Supabase Auth on incoming requests.
    SUPABASE_JWT_SECRET: str = ""
    # Name of the Supabase Storage bucket used for report images.
    SUPABASE_STORAGE_BUCKET: str = "report-images"
    # How long a signed image URL stays valid (Step 7). The bucket is
    # private, so every report response gets freshly signed URLs rather
    # than a permanent link — this just controls that link's lifetime.
    REPORT_IMAGE_SIGNED_URL_TTL_SECONDS: int = 3600

    # ---- Security ----
    JWT_ALGORITHM: str = "HS256"

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT == "production"


@lru_cache
def get_settings() -> Settings:
    """Cached settings instance (avoids re-parsing the environment on every call)."""
    return Settings()
