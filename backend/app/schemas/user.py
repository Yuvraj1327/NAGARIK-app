"""Pydantic schemas for the /users endpoints."""

from pydantic import BaseModel


class UserProfileResponse(BaseModel):
    id: str
    email: str | None
    full_name: str | None
    # Official Logo & User Profile Photo upgrade: a freshly signed URL for
    # the user's photo, or None if they haven't set one. Always computed
    # from `CurrentUser.avatar_path` at request time (the avatars bucket is
    # private) — never a raw Storage path, which wouldn't be fetchable by
    # the client anyway.
    avatar_url: str | None = None


class AvatarUploadResponse(BaseModel):
    """Returned by `POST /users/me/avatar`. `avatar_path` is what the
    Flutter client stores back into Supabase Auth's `user_metadata` via
    `AuthRepository.updateAvatarPath` — the backend has no way to write
    that itself (see `app/services/profile_service.py`)."""

    avatar_path: str
    avatar_url: str | None = None
