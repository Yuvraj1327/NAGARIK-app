"""
Supabase integration.

Two distinct clients are exposed on purpose:

- `get_supabase_service_client()` — uses the SERVICE ROLE key. Bypasses Row
  Level Security. This is what the backend uses internally to perform
  Postgres/Storage operations once it has independently verified the caller's
  identity via `app.core.security`. Never expose this client or its key to
  the Flutter app.

- `get_supabase_anon_client()` — uses the public ANON key. Included for
  completeness (e.g. if the backend ever needs to act "as anonymous"), but
  is not expected to see much use since the Flutter app talks to Supabase
  Auth directly with its own anon key.

Both are cached as singletons so we don't reconnect per-request.
"""

from functools import lru_cache

from supabase import Client, create_client

from app.core.config import get_settings


@lru_cache
def get_supabase_service_client() -> Client:
    settings = get_settings()
    if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_ROLE_KEY:
        raise RuntimeError(
            "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are not configured. "
            "Copy backend/.env.example to backend/.env and fill in your "
            "Supabase project credentials."
        )
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)


@lru_cache
def get_supabase_anon_client() -> Client:
    settings = get_settings()
    if not settings.SUPABASE_URL or not settings.SUPABASE_ANON_KEY:
        raise RuntimeError(
            "SUPABASE_URL / SUPABASE_ANON_KEY are not configured. "
            "Copy backend/.env.example to backend/.env and fill in your "
            "Supabase project credentials."
        )
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY)
