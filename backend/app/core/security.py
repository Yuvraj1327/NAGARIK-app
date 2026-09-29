"""
Authentication scaffolding.

Flow (decided in Step 1, implemented in Step 3):
    1. The Flutter app signs up / logs in directly against Supabase Auth
       using the Supabase client SDK, and receives a Supabase-issued JWT.
    2. The Flutter app sends that JWT as `Authorization: Bearer <token>`
       on every request to this API.
    3. This API verifies the JWT's signature against SUPABASE_JWT_SECRET
       and extracts the Supabase user id (`sub` claim) — it never talks
       to Supabase Auth to do this, verification is local and fast.
    4. Once verified, the backend uses the Supabase *service role* client
       (see app/integrations/supabase_client.py) to perform the actual
       Postgres/Storage operations on the user's behalf.

Wired into a route as of Step 4 (`GET /users/me`); more protected
endpoints attach `Depends(get_current_user)` the same way as they're built.

Step 7/8 adds `get_optional_current_user`: report browsing/search is public
(no login needed to look around), but the same endpoint also answers "my
reports" for a signed-in caller, so it needs to know who's asking without
*requiring* anyone to be signed in. A missing token means "anonymous"; a
present-but-invalid token still raises 401, same as the required variant.
"""

from dataclasses import dataclass

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from app.core.config import Settings, get_settings

_bearer_scheme = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class CurrentUser:
    """Minimal identity extracted from a verified Supabase JWT.

    `full_name` comes from the token's `user_metadata` claim — this is
    exactly what Flutter passed as `data: {'full_name': ...}` to
    `signUp()`, so it's available here with no database round-trip.
    """

    id: str
    email: str | None = None
    full_name: str | None = None


def decode_supabase_jwt(token: str, settings: Settings) -> dict:
    """Decode and verify a Supabase-issued access token.

    Raises HTTPException(401) if the token is missing, malformed, or invalid.
    """
    if not settings.SUPABASE_JWT_SECRET:
        # Fails loudly rather than silently accepting unverifiable tokens.
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server auth is not configured (SUPABASE_JWT_SECRET missing).",
        )
    try:
        return jwt.decode(
            token,
            settings.SUPABASE_JWT_SECRET,
            algorithms=[settings.JWT_ALGORITHM],
            audience="authenticated",
        )
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token.",
        ) from exc


def _current_user_from_payload(payload: dict) -> CurrentUser:
    user_metadata = payload.get("user_metadata") or {}
    return CurrentUser(
        id=payload["sub"],
        email=payload.get("email"),
        full_name=user_metadata.get("full_name"),
    )


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
    settings: Settings = Depends(get_settings),
) -> CurrentUser:
    """FastAPI dependency that resolves the authenticated user from the request.

    Any endpoint that should require login declares
    `user: CurrentUser = Depends(get_current_user)` as a parameter.
    """
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token.",
        )
    payload = decode_supabase_jwt(credentials.credentials, settings)
    return _current_user_from_payload(payload)


async def get_optional_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
    settings: Settings = Depends(get_settings),
) -> CurrentUser | None:
    """Like `get_current_user`, but returns `None` instead of raising when no
    bearer token was sent at all. Used by endpoints that are public but
    behave differently for a signed-in caller (e.g. `GET /reports?mine=true`).

    A token that *is* present but invalid/expired still raises 401 — that
    case means the caller thinks they're signed in and got it wrong, which
    is worth surfacing rather than silently treating as "anonymous".
    """
    if credentials is None:
        return None
    payload = decode_supabase_jwt(credentials.credentials, settings)
    return _current_user_from_payload(payload)
