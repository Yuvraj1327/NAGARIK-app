"""
NAGARIK API entrypoint.

Run locally with:
    uvicorn app.main:app --reload

This module only wires things together (app factory, middleware, router
registration). Business logic never lives here.
"""

import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1.api import api_router
from app.core.config import get_settings
from app.core.logging import configure_logging

logger = logging.getLogger(__name__)


def create_app() -> FastAPI:
    settings = get_settings()
    configure_logging()

    app = FastAPI(
        title=settings.APP_NAME,
        version="0.1.0",
        description="REST API for the NAGARIK civic issue reporting app.",
        docs_url="/docs" if not settings.is_production else None,
        redoc_url="/redoc" if not settings.is_production else None,
    )

    # Always registered (previously only added `if settings.cors_origins`,
    # which meant with no explicit origins configured — the documented
    # default for local dev — Starlette had no CORS middleware at all, so
    # any browser preflight `OPTIONS` request hit a plain 405 instead of a
    # CORS response). `allow_origins` covers explicitly configured origins
    # (e.g. a deployed web build's real domain); `allow_origin_regex`
    # additionally accepts any localhost/127.0.0.1 port outside production,
    # which is what Flutter's web dev server runs on.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_origin_regex=settings.cors_local_dev_origin_regex,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(api_router, prefix=settings.API_V1_PREFIX)

    # Step 9 hardening: FastAPI already turns `HTTPException` and validation
    # errors into clean JSON on its own (this handler is never consulted for
    # those — Starlette dispatches to the most specific registered handler
    # for the exception type, and those have their own). This is the
    # catch-all for anything genuinely unexpected (a bug, a downstream
    # outage) so the client always gets a well-formed JSON error instead of
    # a raw traceback or a dropped connection, and the real exception still
    # gets logged server-side for debugging.
    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled exception on %s %s", request.method, request.url.path)
        return JSONResponse(status_code=500, content={"detail": "Internal server error."})

    return app


app = create_app()
