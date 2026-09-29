"""
Shared FastAPI dependencies, re-exported here so endpoint modules have a
single, stable import path instead of reaching into `core`/`integrations`
directly.
"""

from app.core.security import CurrentUser, get_current_user, get_optional_current_user
from app.integrations.supabase_client import (
    get_supabase_anon_client,
    get_supabase_service_client,
)

__all__ = [
    "CurrentUser",
    "get_current_user",
    "get_optional_current_user",
    "get_supabase_service_client",
    "get_supabase_anon_client",
]
