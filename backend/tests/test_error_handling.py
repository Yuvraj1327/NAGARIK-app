"""
Tests for the app-wide unhandled-exception handler (Step 9 hardening,
see app/main.py). Confirms that a genuinely unexpected error — as opposed
to an `HTTPException` an endpoint raises on purpose — still comes back as
a clean, well-formed JSON error instead of a raw traceback or a dropped
connection.

Every test here overrides `get_settings` to valid dummy values, even the
ones that don't care about settings directly. Reason: `get_supabase_service_client`
raises its own `RuntimeError` when Supabase isn't configured, and in this
sandbox it never is — leaving that dependency un-overridden would make
*every* request 500 regardless of what's actually being tested, since
FastAPI resolves query-parameter validation and dependency calls in the
same pass and a dependency's exception can outrace a validation error
being reported. Pinning settings keeps each test isolated to the one
thing it's checking.

`raise_server_exceptions=False` on the `TestClient` matters specifically
for the "unhandled exception" test: by default the test client re-raises
an exception that escaped all the way to Starlette's outermost error
middleware, even if a registered handler already produced a response —
that default exists so bugs aren't silently hidden during testing. A real
deployed server (uvicorn) has no such re-raise step; it just returns the
handler's response, which is the behavior actually under test here.
"""

from fastapi.testclient import TestClient

from app.api.deps import get_supabase_service_client
from app.core.config import Settings, get_settings
from app.main import app

client = TestClient(app, raise_server_exceptions=False)

_DUMMY_SETTINGS = Settings(
    SUPABASE_URL="https://test.supabase.co",
    SUPABASE_ANON_KEY="anon-key",
    SUPABASE_SERVICE_ROLE_KEY="service-role-key",
    SUPABASE_JWT_SECRET="test-jwt-secret",
)


def _raise_unexpected():
    raise RuntimeError("simulated unexpected failure (e.g. a bug, a downstream outage)")


def test_unhandled_exception_returns_a_clean_500():
    """Force a dependency to raise something that isn't an `HTTPException`
    partway through a real request, and confirm the app-wide handler turns
    it into a structured 500 rather than letting it propagate raw."""
    app.dependency_overrides[get_settings] = lambda: _DUMMY_SETTINGS
    app.dependency_overrides[get_supabase_service_client] = _raise_unexpected
    try:
        response = client.get("/api/v1/reports/anything")
        assert response.status_code == 500
        assert response.json() == {"detail": "Internal server error."}
    finally:
        app.dependency_overrides.pop(get_settings, None)
        app.dependency_overrides.pop(get_supabase_service_client, None)


def test_http_exceptions_are_unaffected_by_the_catch_all_handler():
    """A deliberately-raised HTTPException (e.g. 404) must still come back
    as that exact status/detail — the catch-all only handles the leftovers,
    it never shadows FastAPI's own more specific error handling."""
    from tests.test_reports import FakeSupabaseClient

    fake = FakeSupabaseClient(seed_rows=[])
    app.dependency_overrides[get_settings] = lambda: _DUMMY_SETTINGS
    app.dependency_overrides[get_supabase_service_client] = lambda: fake
    try:
        response = client.get("/api/v1/reports/does-not-exist")
        assert response.status_code == 404
        assert response.json() == {"detail": "Report not found."}
    finally:
        app.dependency_overrides.pop(get_settings, None)
        app.dependency_overrides.pop(get_supabase_service_client, None)


def test_validation_errors_are_unaffected_by_the_catch_all_handler():
    """A 422 from FastAPI's own request validation must still look like a
    normal FastAPI validation error, not get swallowed into a generic 500."""
    from tests.test_reports import FakeSupabaseClient

    fake = FakeSupabaseClient(seed_rows=[])
    app.dependency_overrides[get_settings] = lambda: _DUMMY_SETTINGS
    app.dependency_overrides[get_supabase_service_client] = lambda: fake
    try:
        response = client.get("/api/v1/reports", params={"pin_code": "not-a-pin"})
        assert response.status_code == 422
        assert "detail" in response.json()
    finally:
        app.dependency_overrides.pop(get_settings, None)
        app.dependency_overrides.pop(get_supabase_service_client, None)
