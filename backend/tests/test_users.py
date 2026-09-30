"""Tests for /users/me, exercising the Supabase-JWT verification path end to end."""

from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from jose import jwt

from app.api.deps import get_supabase_service_client
from app.core.config import Settings, get_settings
from app.main import app

TEST_JWT_SECRET = "test-jwt-secret"

client = TestClient(app)


def _test_settings() -> Settings:
    return Settings(
        SUPABASE_URL="https://test.supabase.co",
        SUPABASE_ANON_KEY="anon-key",
        SUPABASE_SERVICE_ROLE_KEY="service-role-key",
        SUPABASE_JWT_SECRET=TEST_JWT_SECRET,
        SUPABASE_AVATAR_BUCKET="avatars",
    )


class _FakeAvatarBucket:
    """Deterministic stand-in for the real avatars Storage bucket —
    `GET /users/me` now signs `avatar_path` on every call (Official Logo &
    User Profile Photo upgrade), so every test in this file needs a working
    fake here, not just the ones that actually set an avatar. Without this,
    the real `get_supabase_service_client()` would run (Supabase isn't
    configured in this sandbox — see `test_error_handling.py`'s docstring
    for the same issue) and every `/users/me` call would 500."""

    def create_signed_url(self, path: str, expires_in: int) -> dict:
        return {
            "signedURL": f"https://test.supabase.co/storage/v1/{path}?token=fake&exp={expires_in}",
        }


class _FakeAvatarStorage:
    def from_(self, bucket_name: str) -> _FakeAvatarBucket:
        assert bucket_name == "avatars"
        return _FakeAvatarBucket()


class _FakeSupabase:
    storage = _FakeAvatarStorage()


@pytest.fixture(autouse=True)
def _override_settings():
    app.dependency_overrides[get_settings] = _test_settings
    app.dependency_overrides[get_supabase_service_client] = lambda: _FakeSupabase()
    yield
    app.dependency_overrides.pop(get_settings, None)
    app.dependency_overrides.pop(get_supabase_service_client, None)


def _make_token(
    *,
    sub: str = "user-123",
    email: str = "citizen@example.com",
    full_name: str | None = "Asha Rao",
    avatar_path: str | None = None,
) -> str:
    user_metadata = {}
    if full_name:
        user_metadata["full_name"] = full_name
    if avatar_path:
        user_metadata["avatar_path"] = avatar_path
    payload = {
        "sub": sub,
        "email": email,
        "aud": "authenticated",
        "user_metadata": user_metadata,
        "exp": datetime.now(UTC) + timedelta(hours=1),
    }
    return jwt.encode(payload, TEST_JWT_SECRET, algorithm="HS256")


def test_get_my_profile_returns_claims_from_a_valid_token():
    token = _make_token()

    response = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200
    assert response.json() == {
        "id": "user-123",
        "email": "citizen@example.com",
        "full_name": "Asha Rao",
        "avatar_url": None,
    }


def test_get_my_profile_without_full_name_metadata():
    token = _make_token(full_name=None)

    response = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200
    assert response.json()["full_name"] is None


def test_get_my_profile_without_avatar_metadata_has_no_avatar_url():
    token = _make_token()

    response = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200
    assert response.json()["avatar_url"] is None


def test_get_my_profile_signs_the_avatar_path_when_present():
    token = _make_token(avatar_path="user-123/avatar.jpg")

    response = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200
    assert response.json()["avatar_url"] == (
        "https://test.supabase.co/storage/v1/user-123/avatar.jpg?token=fake&exp=3600"
    )


def test_get_my_profile_without_token_is_unauthorized():
    response = client.get("/api/v1/users/me")
    assert response.status_code == 401


def test_get_my_profile_with_invalid_token_is_unauthorized():
    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": "Bearer not-a-real-token"},
    )
    assert response.status_code == 401
