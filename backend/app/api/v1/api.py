"""
Aggregates all v1 routers into a single APIRouter mounted by app.main.

Each feature gets its own endpoints module. Only `health` is implemented in
Step 1 (it proves the Flutter <-> FastAPI communication path end to end).
`auth`, `users`, and `reports` are registered now as empty routers so the
URL structure and module layout are locked in; their real endpoints are
filled in during Steps 3, 4, and 5/7/8 respectively.
"""

from fastapi import APIRouter

from app.api.v1.endpoints import auth, health, reports, users

api_router = APIRouter()

api_router.include_router(health.router, prefix="/health", tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(reports.router, prefix="/reports", tags=["reports"])
