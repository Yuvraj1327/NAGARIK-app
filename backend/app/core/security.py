"""
Authentication scaffolding.

Flow (decided in Step 1, implemented in Step 3):
    1. The Flutter app signs up / logs in directly against Supabase Auth
       using the Supabase client SDK, and receives a Supabase-issued JWT.
    2. The Flutter app sends that JWT as `Authorization: Bearer <token>`
       on every request to this API.
    3. This API verifies the JWT's signature and extracts the Supabase user
       id (`sub` claim) — it never calls Supabase Auth per request, so
       verification is local and fast. Which key is used depends on the
       token's `alg` header, because Supabase projects differ:
         - ES256 / RS256 (projects using Supabase's asymmetric "JWT Signing
           Keys", the default for new projects): verified against the
           project's public JWKS, `<SUPABASE_URL>/auth/v1/.well-known/jwks.json`,
           picked by the token's `kid` and cached in memory.
         - HS256 (legacy projects): verified against SUPABASE_JWT_SECRET.
       A project that has migrated to asymmetric keys still issues HS256
       *anon/service* keys, which is why an HS256-only verifier can look
       correct in a quick check yet reject every real user token.
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

import logging
import threading
import time
from dataclasses import dataclass

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.concurrency import run_in_threadpool
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import ExpiredSignatureError, JWTError, jwt

from app.core.config import Settings, get_settings

logger = logging.getLogger(__name__)

_bearer_scheme = HTTPBearer(auto_error=False)

_ASYMMETRIC_ALGORITHMS = frozenset({"ES256", "RS256"})
_JWKS_CACHE_TTL_SECONDS = 600
# An unknown `kid` forces a refetch (key rotation), but at most this often,
# so a stream of garbage tokens can't turn into a stream of outbound requests.
_JWKS_MIN_REFETCH_INTERVAL_SECONDS = 30
_JWKS_FETCH_TIMEOUT_SECONDS = 5
_JWT_LEEWAY_SECONDS = 10

_UNAUTHORIZED_HEADERS = {"WWW-Authenticate": "Bearer"}


@dataclass(frozen=True)
class CurrentUser:
    """Minimal identity extracted from a verified Supabase JWT.

    `full_name` comes from the token's `user_metadata` claim — this is
    exactly what Flutter passed as `data: {'full_name': ...}` to
    `signUp()`, so it's available here with no database round-trip.

    `avatar_path` (Official Logo & User Profile Photo upgrade) is the same
    idea for a profile photo: there's no `profiles` table to store a
    reference in, so the Storage object path is kept in `user_metadata`
    too, set by the Flutter client (`AuthRepository.updateAvatarPath`) right
    after a successful upload to Storage. It's a path, not a URL — the
    avatars bucket is private, so `GET /users/me` signs it fresh on every
    request (see `app/services/profile_service.py`).
    """

    id: str
    email: str | None = None
    full_name: str | None = None
    avatar_path: str | None = None


class _JwksCache:
    """In-memory cache of a Supabase project's public signing keys."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._keys: dict[str, dict] = {}
        self._url: str | None = None
        self._fetched_at = 0.0

    def clear(self) -> None:
        with self._lock:
            self._keys, self._url, self._fetched_at = {}, None, 0.0

    def get_key(self, jwks_url: str, kid: str | None) -> dict | None:
        with self._lock:
            now = time.monotonic()
            if self._url != jwks_url:
                self._keys, self._url, self._fetched_at = {}, jwks_url, 0.0
            age = now - self._fetched_at
            known = self._pick(kid)
            if known is not None and age < _JWKS_CACHE_TTL_SECONDS:
                return known
            # Cold cache, expired cache, or unknown kid (key rotation).
            if self._keys and age < _JWKS_MIN_REFETCH_INTERVAL_SECONDS:
                return known
            try:
                self._keys = {k.get("kid", ""): k for k in _fetch_jwks(jwks_url)}
                self._fetched_at = now
            except Exception:
                logger.exception("Could not fetch Supabase JWKS from %s", jwks_url)
                if known is not None:
                    return known  # stale key beats failing every request
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="Unable to load token signing keys. Please try again.",
                ) from None
            return self._pick(kid)

    def _pick(self, kid: str | None) -> dict | None:
        if kid is not None:
            return self._keys.get(kid)
        # Tokens without a `kid` are only unambiguous with a single key.
        return next(iter(self._keys.values())) if len(self._keys) == 1 else None


_jwks_cache = _JwksCache()


def _fetch_jwks(jwks_url: str) -> list[dict]:
    # httpx (already a dependency of the supabase client) verifies TLS against
    # certifi's CA bundle; the stdlib's urllib relies on the OS trust store,
    # which is missing on some Python installs (e.g. python.org builds on macOS).
    response = httpx.get(jwks_url, timeout=_JWKS_FETCH_TIMEOUT_SECONDS)
    response.raise_for_status()
    return response.json()["keys"]


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers=_UNAUTHORIZED_HEADERS,
    )


def _verification_key(header: dict, settings: Settings) -> tuple[str | dict, str]:
    """Pick the (key, algorithm) for a token based on its unverified header.

    The algorithm is chosen from a fixed allowlist rather than trusted
    blindly from the header, so `alg: none` and HS/RS confusion attacks
    (signing with a public key as if it were an HMAC secret) are rejected.
    """
    algorithm = header.get("alg")
    if algorithm in _ASYMMETRIC_ALGORITHMS:
        if not settings.SUPABASE_URL:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Server auth is not configured (SUPABASE_URL missing).",
            )
        jwks_url = f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1/.well-known/jwks.json"
        key = _jwks_cache.get_key(jwks_url, header.get("kid"))
        if key is None:
            raise _unauthorized("Invalid authentication token (unknown signing key).")
        return key, algorithm
    if algorithm == settings.JWT_ALGORITHM:
        if not settings.SUPABASE_JWT_SECRET:
            # Fails loudly rather than silently accepting unverifiable tokens.
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Server auth is not configured (SUPABASE_JWT_SECRET missing).",
            )
        return settings.SUPABASE_JWT_SECRET, algorithm
    raise _unauthorized("Invalid authentication token.")


def decode_supabase_jwt(token: str, settings: Settings) -> dict:
    """Decode and verify a Supabase-issued access token.

    Raises HTTPException(401) if the token is malformed, invalid, or expired.
    Blocking (may fetch the JWKS over the network on a cold cache) — async
    callers should go through `run_in_threadpool`, as the dependencies below do.
    """
    try:
        header = jwt.get_unverified_header(token)
    except JWTError as exc:
        raise _unauthorized("Invalid authentication token.") from exc

    key, algorithm = _verification_key(header, settings)
    try:
        return jwt.decode(
            token,
            key,
            algorithms=[algorithm],
            audience="authenticated",
            options={"leeway": _JWT_LEEWAY_SECONDS},
        )
    except ExpiredSignatureError as exc:
        raise _unauthorized("Authentication token has expired.") from exc
    except JWTError as exc:
        raise _unauthorized("Invalid or expired authentication token.") from exc


def _current_user_from_payload(payload: dict) -> CurrentUser:
    user_metadata = payload.get("user_metadata") or {}
    return CurrentUser(
        id=payload["sub"],
        email=payload.get("email"),
        full_name=user_metadata.get("full_name"),
        avatar_path=user_metadata.get("avatar_path"),
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
            headers=_UNAUTHORIZED_HEADERS,
        )
    payload = await run_in_threadpool(decode_supabase_jwt, credentials.credentials, settings)
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
    payload = await run_in_threadpool(decode_supabase_jwt, credentials.credentials, settings)
    return _current_user_from_payload(payload)
