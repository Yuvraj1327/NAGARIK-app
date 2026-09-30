"""
Profile photo (avatar) Storage logic — Official Logo & User Profile Photo
upgrade.

Avatars live in their own private Supabase Storage bucket
(`migrations/0005_avatars_bucket.sql`), NOT in a database column: there is
no `profiles` table (see `docs/ARCHITECTURE.md`), so — same as `full_name`
— the *reference* to the uploaded photo is stored in the user's Supabase
Auth `user_metadata` (`avatar_path`). That field is set by the Flutter
client (`AuthRepository.updateAvatarPath`) right after a successful
upload/removal here, mirroring `updateFullName`'s existing pattern exactly,
including the `refreshSession()` call needed for the change to be reflected
in the JWT immediately (see that method's doc comment). This module only
ever touches Storage bytes; it has no way to write `user_metadata` itself
(that needs the user's own session, which the backend never holds) and
doesn't try to.

Each user's photo is stored at a single, fixed-name path,
"<user_id>/avatar.<ext>" — unlike report images (many, permanent, one row
per uploaded file), a profile photo is one slot that gets replaced or
removed, not a growing list. Because the extension can change between
uploads (a PNG replaced by a JPEG, say), every upload lists and cleans up
any other object(s) already sitting in that user's folder after the new one
is safely written, so a stale file under the old extension never lingers
next to the new one.
"""

from fastapi import HTTPException, UploadFile, status
from supabase import Client

from app.core.config import Settings

# Deliberately smaller than reports' MAX_IMAGE_BYTES (8 MB) — a single
# profile photo has no reason to be as large as a report's evidence photos.
MAX_AVATAR_BYTES = 5 * 1024 * 1024  # 5 MB
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
_EXTENSION_BY_CONTENT_TYPE = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}


def _bucket(supabase: Client, settings: Settings):
    return supabase.storage.from_(settings.SUPABASE_AVATAR_BUCKET)


def _existing_paths(supabase: Client, settings: Settings, user_id: str) -> list[str]:
    """Best-effort listing of whatever's currently stored for this user, so
    a replace/remove can clean it up regardless of its extension. Returns
    an empty list (rather than raising) if Storage is unreachable or the
    user simply has nothing yet — both are treated the same as "nothing to
    clean up", not a failure."""
    try:
        objects = _bucket(supabase, settings).list(user_id)
    except Exception:
        return []
    return [f"{user_id}/{obj['name']}" for obj in (objects or []) if obj.get("name")]


async def upload_avatar(
    *, supabase: Client, settings: Settings, user_id: str, image: UploadFile
) -> str:
    """Uploads a new profile photo, replacing any existing one. Returns the
    Storage object path (not yet signed) for the caller to sign and to hand
    back to the Flutter client to store in `user_metadata`."""
    if image.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported image type: {image.content_type}.",
        )

    contents = await image.read()
    if not contents:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="The image is empty."
        )
    if len(contents) > MAX_AVATAR_BYTES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Your photo must be smaller than 5 MB.",
        )

    bucket = _bucket(supabase, settings)
    stale_paths = _existing_paths(supabase, settings, user_id)

    extension = _EXTENSION_BY_CONTENT_TYPE.get(image.content_type, "bin")
    object_path = f"{user_id}/avatar.{extension}"

    try:
        # `upsert` so re-uploading under the *same* extension (the common
        # case — replacing a JPEG with another JPEG) overwrites cleanly
        # instead of failing with "already exists".
        bucket.upload(object_path, contents, {"content-type": image.content_type, "upsert": "true"})
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to upload your photo. Please try again.",
        ) from exc

    # Clean up any leftover object(s) from a previous upload under a
    # *different* extension. Done after the new upload succeeds and kept
    # best-effort, so a cleanup hiccup never costs the user their
    # just-uploaded photo.
    leftovers = [path for path in stale_paths if path != object_path]
    if leftovers:
        try:
            bucket.remove(leftovers)
        except Exception:
            pass

    return object_path


def delete_avatar(*, supabase: Client, settings: Settings, user_id: str) -> None:
    """Removes whatever profile photo(s) exist for this user. Idempotent —
    removing when nothing exists is a no-op, not an error, same philosophy
    as `reports_service.unsave_report`."""
    paths = _existing_paths(supabase, settings, user_id)
    if not paths:
        return
    try:
        _bucket(supabase, settings).remove(paths)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to remove your photo. Please try again.",
        ) from exc


def sign_avatar_url(
    *, supabase: Client, settings: Settings, avatar_path: str | None
) -> str | None:
    """Signs a single avatar path, or returns None if there's nothing to
    sign. Best-effort on failure (a broken/expired Storage call should never
    break loading the rest of the profile) — same philosophy as
    `reports_service._sign_image_paths`."""
    if not avatar_path:
        return None
    try:
        signed = _bucket(supabase, settings).create_signed_url(
            avatar_path, settings.AVATAR_SIGNED_URL_TTL_SECONDS
        )
    except Exception:
        return None
    url = signed.get("signedURL") or signed.get("signedUrl")
    return url if url and not signed.get("error") else None
