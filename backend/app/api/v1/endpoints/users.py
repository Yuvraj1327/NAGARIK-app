"""
User profile endpoints.

`GET /me` (Step 4) returns the authenticated user's basic details straight
from their verified Supabase JWT claims — no database round-trip needed,
since Supabase Auth already carries `email` and `user_metadata` (set at
signup) in the token. The Official Logo & User Profile Photo upgrade adds
one real Storage call on top of that: if the caller has a photo
(`user_metadata.avatar_path`), it's signed fresh on every call, since the
avatars bucket is private (same reasoning as report images).

Report history is deliberately NOT exposed here yet: there is no reports
table until Step 5 creates one, so an endpoint for it would either be fake
or fail. It's added once Step 5/7 exist for it to query.

`POST /me/avatar` and `DELETE /me/avatar` (Official Logo & User Profile
Photo upgrade) let a signed-in caller upload/replace or remove their own
profile photo. Both only touch Storage — see
`app/services/profile_service.py`'s module docstring for why the backend
never writes `user_metadata` itself, and why the Flutter client is the one
that calls `AuthRepository.updateAvatarPath` right after either succeeds.
"""

from fastapi import APIRouter, Depends, File, UploadFile

from app.api.deps import CurrentUser, get_current_user, get_supabase_service_client
from app.core.config import Settings, get_settings
from app.schemas.user import AvatarUploadResponse, UserProfileResponse
from app.services.profile_service import delete_avatar, sign_avatar_url, upload_avatar

router = APIRouter()


@router.get("/me", response_model=UserProfileResponse, summary="Get the current user's profile")
def get_my_profile(
    current_user: CurrentUser = Depends(get_current_user),
    settings: Settings = Depends(get_settings),
    supabase=Depends(get_supabase_service_client),
) -> UserProfileResponse:
    avatar_url = sign_avatar_url(
        supabase=supabase, settings=settings, avatar_path=current_user.avatar_path
    )
    return UserProfileResponse(
        id=current_user.id,
        email=current_user.email,
        full_name=current_user.full_name,
        avatar_url=avatar_url,
    )


@router.post(
    "/me/avatar",
    response_model=AvatarUploadResponse,
    summary="Upload or replace the signed-in caller's profile photo",
)
async def upload_my_avatar(
    image: UploadFile = File(...),
    current_user: CurrentUser = Depends(get_current_user),
    settings: Settings = Depends(get_settings),
    supabase=Depends(get_supabase_service_client),
) -> AvatarUploadResponse:
    avatar_path = await upload_avatar(
        supabase=supabase, settings=settings, user_id=current_user.id, image=image
    )
    avatar_url = sign_avatar_url(supabase=supabase, settings=settings, avatar_path=avatar_path)
    return AvatarUploadResponse(avatar_path=avatar_path, avatar_url=avatar_url)


@router.delete(
    "/me/avatar",
    status_code=204,
    summary="Remove the signed-in caller's profile photo",
)
def delete_my_avatar(
    current_user: CurrentUser = Depends(get_current_user),
    settings: Settings = Depends(get_settings),
    supabase=Depends(get_supabase_service_client),
) -> None:
    delete_avatar(supabase=supabase, settings=settings, user_id=current_user.id)
