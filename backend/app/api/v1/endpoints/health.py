"""
Health check endpoints.

This is the one endpoint implemented in Step 1. Its purpose is narrow and
deliberate: prove that the Flutter app, FastAPI, and (optionally) Supabase
can all be reached, before any real feature is built on top.
"""

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.config import Settings, get_settings

router = APIRouter()


class HealthResponse(BaseModel):
    status: str
    app_name: str
    environment: str


class ReadinessResponse(BaseModel):
    status: str
    supabase_configured: bool


@router.get("", response_model=HealthResponse, summary="Liveness check")
def health(settings: Settings = Depends(get_settings)) -> HealthResponse:
    """Returns 200 if the API process is up. No external calls are made."""
    return HealthResponse(
        status="ok",
        app_name=settings.APP_NAME,
        environment=settings.ENVIRONMENT,
    )


@router.get("/ready", response_model=ReadinessResponse, summary="Readiness check")
def readiness(settings: Settings = Depends(get_settings)) -> ReadinessResponse:
    """Reports whether required external configuration (Supabase) is present.

    Deliberately does not make a live network call to Supabase here — that
    keeps this endpoint fast and dependency-free. It only confirms that the
    credentials needed to talk to Supabase have been provided.
    """
    supabase_configured = bool(
        settings.SUPABASE_URL
        and settings.SUPABASE_ANON_KEY
        and settings.SUPABASE_SERVICE_ROLE_KEY
    )
    return ReadinessResponse(
        status="ok" if supabase_configured else "degraded",
        supabase_configured=supabase_configured,
    )
