"""Smoke tests proving the API boots and the Flutter <-> FastAPI path works."""

from fastapi.testclient import TestClient

from app.core.config import Settings, get_settings
from app.main import app

client = TestClient(app)


def test_health_ok():
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["app_name"]


def test_readiness_reports_supabase_config_state():
    response = client.get("/api/v1/health/ready")
    assert response.status_code == 200
    body = response.json()
    assert "supabase_configured" in body


def test_readiness_is_degraded_when_supabase_is_not_configured():
    app.dependency_overrides[get_settings] = lambda: Settings(
        SUPABASE_URL="", SUPABASE_ANON_KEY="", SUPABASE_SERVICE_ROLE_KEY=""
    )
    try:
        response = client.get("/api/v1/health/ready")
        assert response.status_code == 200
        assert response.json() == {"status": "degraded", "supabase_configured": False}
    finally:
        app.dependency_overrides.pop(get_settings, None)


def test_readiness_is_ok_when_supabase_is_configured():
    app.dependency_overrides[get_settings] = lambda: Settings(
        SUPABASE_URL="https://test.supabase.co",
        SUPABASE_ANON_KEY="anon-key",
        SUPABASE_SERVICE_ROLE_KEY="service-role-key",
    )
    try:
        response = client.get("/api/v1/health/ready")
        assert response.status_code == 200
        assert response.json() == {"status": "ok", "supabase_configured": True}
    finally:
        app.dependency_overrides.pop(get_settings, None)
