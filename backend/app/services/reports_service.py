"""
Report creation, retrieval, and discovery business logic (Step 5/6/7/8).

Kept out of the route functions so the upload-then-insert sequence, the
signed-URL handling, and the filter/pagination logic each live in one
testable place instead of inline in the endpoints.
"""

import math
import uuid

from fastapi import HTTPException, UploadFile, status
from supabase import Client

from app.core.config import Settings
from app.schemas.report import (
    ReportCategory,
    ReportListResponse,
    ReportResponse,
    ReportStatus,
)

# Explicit limits on user-uploaded files rather than leaving them unbounded.
MAX_IMAGES = 5
MAX_IMAGE_BYTES = 8 * 1024 * 1024  # 8 MB
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
_EXTENSION_BY_CONTENT_TYPE = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}

# ---- Retrieval / discovery (Step 7/8) ----
DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE = 50
DEFAULT_RADIUS_KM = 5.0
# Supabase/Postgres here has no PostGIS or earthdistance extension enabled
# (out of scope to set up for this project), so "nearby" is computed in
# plain Python with the haversine formula instead of a spatial DB query.
# That means a "nearby" search scans up to this many of the most recent
# matching rows (after the other filters) rather than the whole table —
# fine at civic-app-for-a-city scale, called out as a known limitation for
# very large datasets in docs/ARCHITECTURE.md.
NEARBY_SCAN_LIMIT = 300
_EARTH_RADIUS_KM = 6371.0


async def create_report(
    *,
    supabase: Client,
    settings: Settings,
    user_id: str,
    category: ReportCategory,
    description: str,
    city: str,
    pin_code: str,
    latitude: float | None,
    longitude: float | None,
    images: list[UploadFile],
) -> ReportResponse:
    if len(images) > MAX_IMAGES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"You can attach at most {MAX_IMAGES} images.",
        )

    bucket = supabase.storage.from_(settings.SUPABASE_STORAGE_BUCKET)
    uploaded_paths: list[str] = []

    for image in images:
        if image.content_type not in ALLOWED_CONTENT_TYPES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported image type: {image.content_type}.",
            )

        contents = await image.read()
        if len(contents) > MAX_IMAGE_BYTES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Each image must be smaller than 8 MB.",
            )

        extension = _EXTENSION_BY_CONTENT_TYPE.get(image.content_type, "bin")
        object_path = f"{user_id}/{uuid.uuid4()}.{extension}"

        try:
            bucket.upload(object_path, contents, {"content-type": image.content_type})
        except Exception as exc:
            _cleanup(bucket, uploaded_paths)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Failed to upload one or more images. Please try again.",
            ) from exc

        uploaded_paths.append(object_path)

    row = {
        "user_id": user_id,
        "category": category.value,
        "description": description,
        "city": city,
        "pin_code": pin_code,
        "latitude": latitude,
        "longitude": longitude,
        "image_paths": uploaded_paths,
    }

    try:
        result = supabase.table("reports").insert(row).execute()
    except Exception as exc:
        # The report wasn't saved, so don't leave orphaned files behind.
        _cleanup(bucket, uploaded_paths)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to save the report. Please try again.",
        ) from exc

    saved_row = result.data[0]
    url_by_path = _sign_image_paths(supabase, settings, saved_row.get("image_paths") or [])
    return _row_to_response(saved_row, url_by_path)


def _cleanup(bucket, paths: list[str]) -> None:
    """Best-effort removal of already-uploaded images after a failure
    partway through, so a partial failure doesn't leave orphaned Storage
    objects with no report row pointing at them."""
    if not paths:
        return
    try:
        bucket.remove(paths)
    except Exception:
        pass


# ---- Retrieval / discovery (Step 7/8) ----


def _sign_image_paths(
    supabase: Client, settings: Settings, paths: list[str]
) -> dict[str, str]:
    """Batch-sign every given Storage path in one request and return a
    `{path: signed_url}` map. The bucket is private (Step 6), so a raw
    `image_paths` entry isn't fetchable by a client on its own.

    Best-effort: if Storage is unreachable or a particular path errors, that
    path is simply left out of the map rather than failing the whole
    request — a broken thumbnail shouldn't take down report browsing.
    """
    if not paths:
        return {}

    unique_paths = list(dict.fromkeys(paths))
    bucket = supabase.storage.from_(settings.SUPABASE_STORAGE_BUCKET)
    try:
        signed = bucket.create_signed_urls(
            unique_paths, settings.REPORT_IMAGE_SIGNED_URL_TTL_SECONDS
        )
    except Exception:
        return {}

    url_by_path: dict[str, str] = {}
    for item in signed:
        path = item.get("path")
        url = item.get("signedURL") or item.get("signedUrl")
        if path and url and not item.get("error"):
            url_by_path[path] = url
    return url_by_path


def _row_to_response(row: dict, url_by_path: dict[str, str]) -> ReportResponse:
    image_paths = row.get("image_paths") or []
    return ReportResponse(
        **{**row, "image_paths": image_paths},
        image_urls=[url_by_path[path] for path in image_paths if path in url_by_path],
    )


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * _EARTH_RADIUS_KM * math.asin(math.sqrt(a))


async def get_report(*, supabase: Client, settings: Settings, report_id: str) -> ReportResponse:
    """Fetch a single report by id (Step 7). Public — no login required to
    view a report, matching the `reports` table's "public select" RLS
    policy (this endpoint still goes through the service-role client, since
    that policy is defense-in-depth, not what's actually enforcing this)."""
    result = supabase.table("reports").select("*").eq("id", report_id).execute()
    rows = result.data or []
    if not rows:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Report not found.")

    row = rows[0]
    url_by_path = _sign_image_paths(supabase, settings, row.get("image_paths") or [])
    return _row_to_response(row, url_by_path)


async def list_reports(
    *,
    supabase: Client,
    settings: Settings,
    category: ReportCategory | None = None,
    status_filter: ReportStatus | None = None,
    city: str | None = None,
    pin_code: str | None = None,
    search: str | None = None,
    user_id: str | None = None,
    latitude: float | None = None,
    longitude: float | None = None,
    radius_km: float | None = None,
    limit: int = DEFAULT_PAGE_SIZE,
    offset: int = 0,
) -> ReportListResponse:
    """Browse/search reports (Step 7 baseline feed, Step 8 filters).

    `city`/`search` do a case-insensitive partial match; `pin_code` and
    `category`/`status` match exactly. When `latitude`/`longitude` are both
    given, results are instead filtered to within `radius_km` (default
    `DEFAULT_RADIUS_KM`) and sorted by distance — see `NEARBY_SCAN_LIMIT`
    for why that path doesn't use `.range()` pagination at the DB level.
    """
    limit = max(1, min(limit, MAX_PAGE_SIZE))
    offset = max(0, offset)

    query = supabase.table("reports").select("*", count="exact")
    if category is not None:
        query = query.eq("category", category.value)
    if status_filter is not None:
        query = query.eq("status", status_filter.value)
    if city:
        query = query.ilike("city", f"%{city}%")
    if pin_code:
        query = query.eq("pin_code", pin_code)
    if user_id:
        query = query.eq("user_id", user_id)
    if search:
        # Commas are the `or_()` clause separator, so strip them defensively
        # rather than letting a searched-for comma break the filter syntax.
        needle = search.replace(",", " ").strip()
        if needle:
            query = query.or_(f"description.ilike.%{needle}%,city.ilike.%{needle}%")

    nearby = latitude is not None and longitude is not None
    if nearby:
        result = query.order("created_at", desc=True).limit(NEARBY_SCAN_LIMIT).execute()
        candidates = result.data or []
        radius = radius_km or DEFAULT_RADIUS_KM
        scored: list[tuple[float, dict]] = []
        for row in candidates:
            row_lat, row_lon = row.get("latitude"), row.get("longitude")
            if row_lat is None or row_lon is None:
                continue
            distance = _haversine_km(latitude, longitude, row_lat, row_lon)
            if distance <= radius:
                scored.append((distance, row))
        scored.sort(key=lambda item: item[0])
        total = len(scored)
        page_rows = [row for _, row in scored[offset : offset + limit]]
    else:
        result = query.order("created_at", desc=True).range(offset, offset + limit - 1).execute()
        page_rows = result.data or []
        total = result.count if result.count is not None else len(page_rows)

    all_paths = [path for row in page_rows for path in (row.get("image_paths") or [])]
    url_by_path = _sign_image_paths(supabase, settings, all_paths)
    items = [_row_to_response(row, url_by_path) for row in page_rows]

    return ReportListResponse(items=items, total=total, limit=limit, offset=offset)
