"""Tests for /users/me, exercising the Supabase-JWT verification path end to end."""

from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from jose import jwt

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
    )


@pytest.fixture(autouse=True)
def _override_settings():
    app.dependency_overrides[get_settings] = _test_settings
    yield
    app.dependency_overrides.pop(get_settings, None)


def _make_token(
    *,
    sub: str = "user-123",
    email: str = "citizen@example.com",
    full_name: str | None = "Asha Rao",
) -> str:
    payload = {
        "sub": sub,
        "email": email,
        "aud": "authenticated",
        "user_metadata": {"full_name": full_name} if full_name else {},
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
    }


def test_get_my_profile_without_full_name_metadata():
    token = _make_token(full_name=None)

    response = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200
    assert response.json()["full_name"] is None


def test_get_my_profile_without_token_is_unauthorized():
    response = client.get("/api/v1/users/me")
    assert response.status_code == 401


def test_get_my_profile_with_invalid_token_is_unauthorized():
    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": "Bearer not-a-real-token"},
    )
    assert response.status_code == 401
