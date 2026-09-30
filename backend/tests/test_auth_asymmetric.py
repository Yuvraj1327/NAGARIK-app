"""Tests for verifying ES256 Supabase access tokens via the project's JWKS.

Supabase projects using asymmetric JWT signing keys issue user tokens signed
with ES256, verifiable only with the public key from
`<SUPABASE_URL>/auth/v1/.well-known/jwks.json` — never with the HS256 secret.
These tests generate a real EC keypair and serve its public half as the JWKS
(no network), so the whole verify path runs for real.
"""

from datetime import UTC, datetime, timedelta

import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi.testclient import TestClient
from jose import jwk, jwt

from app.api.deps import get_supabase_service_client
from app.core import security
from app.core.config import Settings, get_settings
from app.main import app
from tests.test_reports import FakeSupabaseClient, _make_report_row

TEST_JWT_SECRET = "test-jwt-secret"
KID = "test-key-1"

client = TestClient(app)


def _generate_ec_key() -> tuple[str, dict]:
    private_key = ec.generate_private_key(ec.SECP256R1())
    private_pem = private_key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ).decode()
    public_pem = private_key.public_key().public_bytes(
        serialization.Encoding.PEM,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    public_jwk = jwk.construct(public_pem, "ES256").to_dict()
    public_jwk.update({"kid": KID, "alg": "ES256", "use": "sig"})
    return private_pem, public_jwk


PRIVATE_PEM, PUBLIC_JWK = _generate_ec_key()
OTHER_PRIVATE_PEM, _ = _generate_ec_key()


def _test_settings() -> Settings:
    return Settings(
        SUPABASE_URL="https://test.supabase.co",
        SUPABASE_ANON_KEY="anon-key",
        SUPABASE_SERVICE_ROLE_KEY="service-role-key",
        SUPABASE_JWT_SECRET=TEST_JWT_SECRET,
    )


@pytest.fixture(autouse=True)
def _setup(monkeypatch):
    app.dependency_overrides[get_settings] = _test_settings
    security._jwks_cache.clear()
    fetches: list[str] = []

    def fake_fetch(url: str) -> list[dict]:
        fetches.append(url)
        return [PUBLIC_JWK]

    monkeypatch.setattr(security, "_fetch_jwks", fake_fetch)
    yield fetches
    app.dependency_overrides.pop(get_settings, None)
    security._jwks_cache.clear()


def _es256_token(*, private_pem: str = PRIVATE_PEM, kid: str | None = KID, **overrides) -> str:
    payload = {
        "sub": "user-es256",
        "email": "citizen@example.com",
        "aud": "authenticated",
        "user_metadata": {"full_name": "Asha Rao"},
        "exp": datetime.now(UTC) + timedelta(hours=1),
        **overrides,
    }
    headers = {"kid": kid} if kid else None
    return jwt.encode(payload, private_pem, algorithm="ES256", headers=headers)


def _get(path: str, token: str | None):
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    return client.get(path, headers=headers)


def test_users_me_accepts_valid_es256_token():
    response = _get("/api/v1/users/me", _es256_token())

    assert response.status_code == 200
    body = response.json()
    assert (body["id"], body["email"], body["full_name"]) == (
        "user-es256",
        "citizen@example.com",
        "Asha Rao",
    )


def test_jwks_is_fetched_from_project_url_and_cached(_setup):
    _get("/api/v1/users/me", _es256_token())
    _get("/api/v1/users/me", _es256_token())

    assert _setup == ["https://test.supabase.co/auth/v1/.well-known/jwks.json"]


def test_es256_token_signed_by_a_different_key_is_rejected():
    response = _get("/api/v1/users/me", _es256_token(private_pem=OTHER_PRIVATE_PEM))

    assert response.status_code == 401


def test_expired_es256_token_is_rejected_with_clear_message():
    expired = _es256_token(exp=datetime.now(UTC) - timedelta(minutes=5))

    response = _get("/api/v1/users/me", expired)

    assert response.status_code == 401
    assert response.json()["detail"] == "Authentication token has expired."
    assert response.headers["www-authenticate"] == "Bearer"


def test_es256_token_with_wrong_audience_is_rejected():
    assert _get("/api/v1/users/me", _es256_token(aud="anon")).status_code == 401


def test_es256_token_with_unknown_kid_is_rejected():
    assert _get("/api/v1/users/me", _es256_token(kid="rotated-away")).status_code == 401


def test_unknown_kid_refetch_is_rate_limited(_setup):
    _get("/api/v1/users/me", _es256_token())  # warm the cache
    for _ in range(3):
        _get("/api/v1/users/me", _es256_token(kid="garbage"))

    assert len(_setup) == 1


def test_jwks_fetch_failure_is_503_not_401(monkeypatch):
    def boom(url: str) -> list[dict]:
        raise OSError("network down")

    monkeypatch.setattr(security, "_fetch_jwks", boom)

    response = _get("/api/v1/users/me", _es256_token())

    # 503 (not 401) so the app doesn't sign the user out over a transient outage.
    assert response.status_code == 503


def test_reports_and_mine_work_with_es256_token():
    mine = _make_report_row(user_id="user-es256")
    other = _make_report_row(user_id="someone-else")
    fake = FakeSupabaseClient(seed_rows=[mine, other])
    app.dependency_overrides[get_supabase_service_client] = lambda: fake
    try:
        token = _es256_token()

        everything = _get("/api/v1/reports", token)
        only_mine = client.get(
            "/api/v1/reports",
            params={"mine": True},
            headers={"Authorization": f"Bearer {token}"},
        )
        garbage = _get("/api/v1/reports", "garbage")
    finally:
        app.dependency_overrides.pop(get_supabase_service_client, None)

    assert everything.status_code == 200
    assert only_mine.status_code == 200
    assert [item["id"] for item in only_mine.json()["items"]] == [mine["id"]]
    # A present-but-invalid token is still a 401, not silently "anonymous".
    assert garbage.status_code == 401


def test_hs256_token_signed_with_public_jwk_as_secret_is_rejected():
    """Algorithm-confusion guard: HS256 must only verify against the real secret."""
    forged = jwt.encode(
        {"sub": "attacker", "aud": "authenticated", "exp": datetime.now(UTC) + timedelta(hours=1)},
        "not-the-secret",
        algorithm="HS256",
    )
    assert _get("/api/v1/users/me", forged).status_code == 401


def test_legacy_hs256_tokens_still_work():
    token = jwt.encode(
        {
            "sub": "legacy-user",
            "aud": "authenticated",
            "exp": datetime.now(UTC) + timedelta(hours=1),
        },
        TEST_JWT_SECRET,
        algorithm="HS256",
    )
    assert _get("/api/v1/users/me", token).json()["id"] == "legacy-user"
