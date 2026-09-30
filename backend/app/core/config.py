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

    # Flutter web's dev server (`flutter run -d chrome` / `-d web-server`)
    # picks an unpredictable localhost port per run, so it can't be listed
    # as a fixed origin in BACKEND_CORS_ORIGINS. Outside production, the API
    # also accepts any http(s)://localhost:<port> or 127.0.0.1:<port>
    # origin via `allow_origin_regex` (see app/main.py) so local web
    # development works without editing .env every time the port changes.
    # This never applies in production (see `is_production` below).
    @property
    def cors_local_dev_origin_regex(self) -> str | None:
        if self.is_production:
            return None
        return r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"

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
    # Name of the Supabase Storage bucket used for profile photos (Official
    # Logo & User Profile Photo upgrade) — a separate bucket from
    # SUPABASE_STORAGE_BUCKET so report images and avatars have their own
    # RLS policies and lifecycle, even though both are private and follow
    # the same "<user_id>/..." path convention.
    SUPABASE_AVATAR_BUCKET: str = "avatars"
    # How long a signed avatar URL stays valid. Kept as its own setting
    # (rather than reusing REPORT_IMAGE_SIGNED_URL_TTL_SECONDS) since a
    # profile photo and a report photo may reasonably want different
    # lifetimes even though both default to the same value today.
    AVATAR_SIGNED_URL_TTL_SECONDS: int = 3600

    # ---- Security ----
    JWT_ALGORITHM: str = "HS256"

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT == "production"


@lru_cache
def get_settings() -> Settings:
    """Cached settings instance (avoids re-parsing the environment on every call)."""
    return Settings()
