"""
User profile endpoints.

`GET /me` (Step 4) is the only endpoint so far. It returns the
authenticated user's basic details straight from their verified Supabase
JWT claims — no database round-trip needed, since Supabase Auth already
carries `email` and `user_metadata` (set at signup) in the token.

Report history is deliberately NOT exposed here yet: there is no reports
table until Step 5 creates one, so an endpoint for it would either be fake
or fail. It's added once Step 5/7 exist for it to query.
"""

from fastapi import APIRouter, Depends

from app.api.deps import CurrentUser, get_current_user
from app.schemas.user import UserProfileResponse

router = APIRouter()


@router.get("/me", response_model=UserProfileResponse, summary="Get the current user's profile")
def get_my_profile(current_user: CurrentUser = Depends(get_current_user)) -> UserProfileResponse:
    return UserProfileResponse(
        id=current_user.id,
        email=current_user.email,
        full_name=current_user.full_name,
    )
