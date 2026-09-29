"""Pydantic schemas for the /users endpoints."""

from pydantic import BaseModel


class UserProfileResponse(BaseModel):
    id: str
    email: str | None
    full_name: str | None
