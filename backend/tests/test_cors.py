"""
CORS behavior for the Flutter web dev server.

Previously `CORSMiddleware` was only registered `if settings.cors_origins`
(see app/main.py), so with the documented default of an empty
`BACKEND_CORS_ORIGINS`, no CORS middleware existed at all and every
browser preflight `OPTIONS` request hit Starlette's default "no handler
for this method" 405 — this is what the app actually looked like running
locally with a fresh `.env.example` copy. These tests pin the fixed
behavior: CORS middleware is always registered, any localhost/127.0.0.1
port is auto-allowed outside production (covering Flutter web's randomly
picked dev-server port), and that auto-allow does NOT extend to arbitrary
origins or to production.

Note: CORS middleware is configured once, inside `create_app()`, from
whatever `get_settings()` returns at that moment — unlike a route's
`Depends(get_settings)`, it's not re-resolved per request, so
`app.dependency_overrides` (used elsewhere in this test suite) has no
effect on it. Testing a non-default configuration here instead
monkeypatches `app.main.get_settings` and builds a fresh app with
`create_app()`, exactly like a real process would with different
environment variables.
"""

from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import app, create_app

# The module-level `app` (and this client) picked up whatever environment
# was present at import time — in this test environment, that's the plain
# defaults (`BACKEND_CORS_ORIGINS=""`, `ENVIRONMENT="local"`), i.e. exactly
# what a freshly-copied `.env.example` produces.
client = TestClient(app)


def _preflight(test_client: TestClient, origin: str):
    """A CORS preflight is an OPTIONS request carrying both `Origin` and
    `Access-Control-Request-Method` — without both, CORSMiddleware treats
    it as an ordinary request instead of a preflight."""
    return test_client.options(
        "/api/v1/reports",
        headers={
            "Origin": origin,
            "Access-Control-Request-Method": "GET",
        },
    )


def _build_app_with_settings(monkeypatch, settings: Settings) -> TestClient:
    monkeypatch.setattr("app.main.get_settings", lambda: settings)
    return TestClient(create_app())


def test_preflight_from_flutter_web_dev_localhost_is_allowed():
    # Flutter's web dev server binds an unpredictable port per run.
    response = _preflight(client, "http://localhost:54231")
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:54231"


def test_preflight_from_127_0_0_1_is_also_allowed():
    response = _preflight(client, "http://127.0.0.1:9000")
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://127.0.0.1:9000"


def test_preflight_never_returns_405_even_when_origin_is_disallowed():
    # An arbitrary, non-localhost, unconfigured origin is correctly
    # rejected — but as a CORS decision (400), never as "this HTTP method
    # isn't supported here" (405, the bug this fixes).
    response = _preflight(client, "https://evil.example.com")
    assert response.status_code != 405
    assert "access-control-allow-origin" not in response.headers


def test_localhost_auto_allow_does_not_apply_in_production(monkeypatch):
    test_client = _build_app_with_settings(
        monkeypatch,
        Settings(
            SUPABASE_URL="https://test.supabase.co",
            SUPABASE_ANON_KEY="anon-key",
            SUPABASE_SERVICE_ROLE_KEY="service-role-key",
            ENVIRONMENT="production",
        ),
    )
    response = _preflight(test_client, "http://localhost:54231")
    assert "access-control-allow-origin" not in response.headers


def test_explicitly_configured_origin_is_still_allowed_in_production(monkeypatch):
    test_client = _build_app_with_settings(
        monkeypatch,
        Settings(
            SUPABASE_URL="https://test.supabase.co",
            SUPABASE_ANON_KEY="anon-key",
            SUPABASE_SERVICE_ROLE_KEY="service-role-key",
            ENVIRONMENT="production",
            BACKEND_CORS_ORIGINS="https://app.example.com",
        ),
    )
    response = _preflight(test_client, "https://app.example.com")
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "https://app.example.com"
