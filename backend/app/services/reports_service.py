"""
Report creation, retrieval, and discovery business logic (Step 5/6/7/8).

Kept out of the route functions so the upload-then-insert sequence, the
signed-URL handling, and the filter/pagination logic each live in one
testable place instead of inline in the endpoints.
"""

import math
import uuid
from typing import NoReturn

from fastapi import HTTPException, UploadFile, status
from supabase import Client

from app.core.config import Settings
from app.schemas.report import (
    ReportCategory,
    ReportListResponse,
    ReportMarkerListResponse,
    ReportMarkerResponse,
    ReportResponse,
    ReportStatsResponse,
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

# Report stats (Profile screen) scope to a single caller's own reports, so
# unlike NEARBY_SCAN_LIMIT (which bounds a scan across every user's
# reports), this is a generous safety cap rather than a real limitation —
# no realistic single citizen files anywhere near this many reports. It
# exists only so one pathological account can't turn this into an
# unbounded query.
STATS_SCAN_LIMIT = 5000

# PostgREST's own error codes for "the schema I have cached doesn't match
# what was asked for" (as opposed to a normal query error) — most commonly
# PGRST205, "Could not find the table 'public.reports' in the schema
# cache", which is exactly what you get if backend/migrations/*.sql was
# never run against this Supabase project, or was run but PostgREST hasn't
# reloaded its schema cache since. `42P01` (Postgres' own "undefined_table")
# is included too in case a request ever reaches raw Postgres instead of
# going through PostgREST's cache. See backend/migrations/README.md.
_SCHEMA_NOT_READY_CODES = {"PGRST205", "PGRST204", "PGRST202", "42P01"}

# Postgres' own error codes, surfaced by a `saved_reports` insert that hits
# one of its two constraints (Report Sharing & Saved Reports upgrade):
# `23505` (unique_violation) means this exact user+report was already
# saved, and `23503` (foreign_key_violation) means `report_id` doesn't
# point at a real report. Both are turned into a specific, correct response
# by `save_report` rather than the generic 502 `_raise_for_supabase_error`
# would otherwise produce for either.
_UNIQUE_VIOLATION = "23505"
_FOREIGN_KEY_VIOLATION = "23503"


def _raise_for_supabase_error(exc: Exception, *, fallback_detail: str) -> NoReturn:
    """Translate a Supabase/PostgREST failure into an HTTPException.

    A missing-table/column/function error gets a distinct, actionable 503
    pointing at the migrations — that's a setup problem, not a transient
    failure, and "Failed to fetch reports, try again" would be actively
    misleading for it (retrying changes nothing). Anything else falls back
    to the generic 502 the caller supplies, matching prior behavior.
    """
    code = getattr(exc, "code", None)
    if code in _SCHEMA_NOT_READY_CODES:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                f"Database schema isn't ready yet (Supabase error {code}). "
                "Run the SQL files in backend/migrations/ against your "
                "Supabase project (Dashboard -> SQL Editor), then see "
                "backend/migrations/README.md if this persists."
            ),
        ) from exc
    raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=fallback_detail) from exc


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
        _raise_for_supabase_error(
            exc, fallback_detail="Failed to save the report. Please try again."
        )

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


def _row_to_response(
    row: dict, url_by_path: dict[str, str], *, is_saved: bool = False
) -> ReportResponse:
    image_paths = row.get("image_paths") or []
    return ReportResponse(
        **{**row, "image_paths": image_paths},
        image_urls=[url_by_path[path] for path in image_paths if path in url_by_path],
        is_saved=is_saved,
    )


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * _EARTH_RADIUS_KM * math.asin(math.sqrt(a))


async def get_report(
    *,
    supabase: Client,
    settings: Settings,
    report_id: str,
    current_user_id: str | None = None,
) -> ReportResponse:
    """Fetch a single report by id (Step 7). Public — no login required to
    view a report, matching the `reports` table's "public select" RLS
    policy (this endpoint still goes through the service-role client, since
    that policy is defense-in-depth, not what's actually enforcing this).

    [current_user_id], when given (the caller sent a valid bearer token —
    see `get_optional_current_user`), is used only to compute `is_saved`
    for *that* caller, so Report Detail's Save/Unsave button reflects the
    right state without a second round trip.
    """
    try:
        result = supabase.table("reports").select("*").eq("id", report_id).execute()
    except Exception as exc:
        _raise_for_supabase_error(
            exc, fallback_detail="Failed to fetch the report. Please try again."
        )
    rows = result.data or []
    if not rows:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Report not found.")

    row = rows[0]
    url_by_path = _sign_image_paths(supabase, settings, row.get("image_paths") or [])
    is_saved = False
    if current_user_id is not None:
        is_saved = _is_report_saved(supabase, user_id=current_user_id, report_id=report_id)
    return _row_to_response(row, url_by_path, is_saved=is_saved)


def _is_report_saved(supabase: Client, *, user_id: str, report_id: str) -> bool:
    """Best-effort: a failure here shouldn't take down viewing a report at
    all, the same "degrade gracefully" precedent `_sign_image_paths` already
    sets for a similarly non-essential piece of the response."""
    try:
        result = (
            supabase.table("saved_reports")
            .select("id")
            .eq("user_id", user_id)
            .eq("report_id", report_id)
            .limit(1)
            .execute()
        )
    except Exception:
        return False
    return bool(result.data)


def _build_reports_query(
    supabase: Client,
    *,
    columns: str,
    count: str | None,
    category: ReportCategory | None,
    status_filter: ReportStatus | None,
    city: str | None,
    pin_code: str | None,
    search: str | None,
    user_id: str | None,
):
    """The filter logic shared by `list_reports` (full report data, for the
    feed/search/My Reports lists) and `list_report_markers` (map pins only)
    — kept in one place so the two never drift apart on what "matching
    reports" means. `columns` is the only thing that differs between the
    two callers' actual database column selection: markers ask for a lean,
    named column list instead of `"*"`, which is the real, DB-level version
    of "don't load unnecessary report fields" (as opposed to fetching every
    column and discarding most of them in Python).
    """
    query = supabase.table("reports").select(columns, count=count)
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
    return query


def _nearby_filter_and_sort(
    rows: list[dict], *, latitude: float, longitude: float, radius_km: float | None
) -> list[tuple[float, dict]]:
    """Shared by `list_reports` and `list_report_markers`: keeps only rows
    within `radius_km` of `(latitude, longitude)` and sorts nearest-first.
    Rows with no coordinates at all (both are optional on `reports`) are
    silently skipped — they simply can't be placed on a map or ranked by
    distance, not an error."""
    radius = radius_km or DEFAULT_RADIUS_KM
    scored: list[tuple[float, dict]] = []
    for row in rows:
        row_lat, row_lon = row.get("latitude"), row.get("longitude")
        if row_lat is None or row_lon is None:
            continue
        distance = _haversine_km(latitude, longitude, row_lat, row_lon)
        if distance <= radius:
            scored.append((distance, row))
    scored.sort(key=lambda item: item[0])
    return scored


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

    query = _build_reports_query(
        supabase,
        columns="*",
        count="exact",
        category=category,
        status_filter=status_filter,
        city=city,
        pin_code=pin_code,
        search=search,
        user_id=user_id,
    )

    nearby = latitude is not None and longitude is not None
    try:
        if nearby:
            result = query.order("created_at", desc=True).limit(NEARBY_SCAN_LIMIT).execute()
        else:
            result = (
                query.order("created_at", desc=True)
                .range(offset, offset + limit - 1)
                .execute()
            )
    except Exception as exc:
        _raise_for_supabase_error(
            exc, fallback_detail="Failed to fetch reports. Please try again."
        )

    if nearby:
        scored = _nearby_filter_and_sort(
            result.data or [], latitude=latitude, longitude=longitude, radius_km=radius_km
        )
        total = len(scored)
        page_rows = [row for _, row in scored[offset : offset + limit]]
    else:
        page_rows = result.data or []
        total = result.count if result.count is not None else len(page_rows)

    all_paths = [path for row in page_rows for path in (row.get("image_paths") or [])]
    url_by_path = _sign_image_paths(supabase, settings, all_paths)
    items = [_row_to_response(row, url_by_path) for row in page_rows]

    return ReportListResponse(items=items, total=total, limit=limit, offset=offset)


# Columns fetched for the map/marker view — everything `ReportMarkerResponse`
# needs and nothing else (no `description`, `image_paths`, timestamps, etc.).
# `latitude`/`longitude` are fetched even though they're not in the response
# model itself... they are: see `ReportMarkerResponse`. Listed explicitly
# (never `"*"`) so adding a column to `reports` later can't silently start
# shipping extra data to every map view.
_MARKER_COLUMNS = "id,reference_id,category,status,city,latitude,longitude"

# Safety cap for a marker fetch with no location filter (e.g. "show me every
# open report in Pune on the map") — there's no per-page pagination for
# markers (a map wants "everything in view", not page 2 of a list), so this
# is what stands in for it. Generous for a single city/category at
# civic-app scale; matches the spirit of `NEARBY_SCAN_LIMIT`.
MARKER_SCAN_LIMIT = 500


async def list_report_markers(
    *,
    supabase: Client,
    category: ReportCategory | None = None,
    status_filter: ReportStatus | None = None,
    city: str | None = None,
    pin_code: str | None = None,
    search: str | None = None,
    latitude: float | None = None,
    longitude: float | None = None,
    radius_km: float | None = None,
) -> ReportMarkerListResponse:
    """Lean report data for the Nearby/Discovery map (Location Discovery &
    Home upgrade) — same filters as `list_reports`, but this never signs a
    single image URL or fetches a column the map doesn't render. A map with
    a hundred pins on screen would otherwise mean a hundred reports' worth
    of `description`/`image_paths` downloaded and a batch Storage
    signed-URL call made, for data no marker ever displays (a tap opens the
    full report through the existing `GET /reports/{report_id}` instead,
    which already does that work for the one report that needs it).
    """
    query = _build_reports_query(
        supabase,
        columns=_MARKER_COLUMNS,
        count=None,
        category=category,
        status_filter=status_filter,
        city=city,
        pin_code=pin_code,
        search=search,
        user_id=None,
    )

    nearby = latitude is not None and longitude is not None
    try:
        if nearby:
            result = query.order("created_at", desc=True).limit(NEARBY_SCAN_LIMIT).execute()
        else:
            result = query.order("created_at", desc=True).limit(MARKER_SCAN_LIMIT).execute()
    except Exception as exc:
        _raise_for_supabase_error(
            exc, fallback_detail="Failed to fetch the map's reports. Please try again."
        )

    rows = result.data or []
    if nearby:
        rows = [row for _, row in _nearby_filter_and_sort(
            rows, latitude=latitude, longitude=longitude, radius_km=radius_km
        )]
    else:
        # Not every report has coordinates (latitude/longitude are
        # optional) — those simply can't be plotted, so they're dropped
        # here rather than passed on as a marker with nowhere to go.
        rows = [
            row
            for row in rows
            if row.get("latitude") is not None and row.get("longitude") is not None
        ]

    return ReportMarkerListResponse(items=[ReportMarkerResponse(**row) for row in rows])


async def get_report_stats(*, supabase: Client, user_id: str) -> ReportStatsResponse:
    """Per-status counts of the caller's own reports, for the Profile
    screen's stat tiles (Total / Resolved / In Review / Submitted).

    Fetches only the `status` column for the caller's rows and counts in
    Python — the same trade-off already made for "nearby" search in
    `list_reports`, since supabase-py's query builder has no `GROUP BY`
    without dropping to a raw RPC/SQL function, and one is not worth adding
    for a single-user aggregate this small (see `STATS_SCAN_LIMIT`).
    """
    try:
        result = (
            supabase.table("reports")
            .select("status")
            .eq("user_id", user_id)
            .limit(STATS_SCAN_LIMIT)
            .execute()
        )
    except Exception as exc:
        _raise_for_supabase_error(
            exc, fallback_detail="Failed to fetch your report stats. Please try again."
        )

    rows = result.data or []
    counts = {status.value: 0 for status in ReportStatus}
    for row in rows:
        row_status = row.get("status")
        if row_status in counts:
            counts[row_status] += 1

    return ReportStatsResponse(
        total=len(rows),
        submitted=counts[ReportStatus.submitted.value],
        in_review=counts[ReportStatus.in_review.value],
        resolved=counts[ReportStatus.resolved.value],
    )


# ---- Saved reports / bookmarking (Report Sharing & Saved Reports upgrade) ----


async def save_report(*, supabase: Client, user_id: str, report_id: str) -> None:
    """Bookmarks a report for the caller.

    Idempotent by design: saving an already-saved report succeeds silently
    rather than erroring, because "duplicate saves must be prevented" means
    the end state (saved, once) is what matters — not that a second attempt
    should be rejected. The actual duplicate guard is the database's own
    `unique (user_id, report_id)` constraint (see
    `0004_saved_reports.sql`); this just treats the resulting `23505` as
    success instead of surfacing it. A `report_id` that doesn't exist trips
    the table's foreign key constraint (`23503`) instead, which is a real
    error — surfaced as 404 rather than a generic 502, since it's the same
    "not found" a bad id gets from `GET /reports/{id}`.
    """
    try:
        supabase.table("saved_reports").insert(
            {"user_id": user_id, "report_id": report_id}
        ).execute()
    except Exception as exc:
        code = getattr(exc, "code", None)
        if code == _UNIQUE_VIOLATION:
            return
        if code == _FOREIGN_KEY_VIOLATION:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Report not found."
            ) from exc
        _raise_for_supabase_error(
            exc, fallback_detail="Failed to save the report. Please try again."
        )


async def unsave_report(*, supabase: Client, user_id: str, report_id: str) -> None:
    """Removes a bookmark. Removing one that was never saved (or already
    removed) is also a no-op, not a 404 — "removed saves disappear
    correctly" only requires that the report end up not-saved, which is
    already true either way, so there's nothing to distinguish from the
    caller's point of view."""
    try:
        supabase.table("saved_reports").delete().eq("user_id", user_id).eq(
            "report_id", report_id
        ).execute()
    except Exception as exc:
        _raise_for_supabase_error(
            exc, fallback_detail="Failed to remove the saved report. Please try again."
        )


async def list_saved_reports(
    *,
    supabase: Client,
    settings: Settings,
    user_id: str,
    limit: int = DEFAULT_PAGE_SIZE,
    offset: int = 0,
) -> ReportListResponse:
    """The caller's bookmarked reports, most recently saved first — backs
    the Saved Reports screen. `saved_reports` only stores `(user_id,
    report_id)`; this fetches the matching full report rows in a second
    query (`.in_("id", ...)`) so the response is a plain `ReportListResponse`
    the same `ReportCard` widget already knows how to render, rather than a
    different shape the mobile app would need a second code path for.
    """
    limit = max(1, min(limit, MAX_PAGE_SIZE))
    offset = max(0, offset)

    try:
        saved_result = (
            supabase.table("saved_reports")
            .select("report_id,created_at", count="exact")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
    except Exception as exc:
        _raise_for_supabase_error(
            exc, fallback_detail="Failed to fetch your saved reports. Please try again."
        )

    saved_rows = saved_result.data or []
    total = saved_result.count if saved_result.count is not None else len(saved_rows)
    report_ids = [row["report_id"] for row in saved_rows]
    if not report_ids:
        return ReportListResponse(items=[], total=total, limit=limit, offset=offset)

    try:
        reports_result = supabase.table("reports").select("*").in_("id", report_ids).execute()
    except Exception as exc:
        _raise_for_supabase_error(
            exc, fallback_detail="Failed to fetch your saved reports. Please try again."
        )

    reports_by_id = {row["id"]: row for row in (reports_result.data or [])}
    # Preserve save order (most recently saved first). A report id with no
    # matching row means that report was deleted after being saved — its
    # `saved_reports` row would already be gone too via `on delete cascade`
    # in the normal case, so this is just defense against a race, not
    # something expected to actually happen.
    ordered_rows = [reports_by_id[rid] for rid in report_ids if rid in reports_by_id]

    all_paths = [path for row in ordered_rows for path in (row.get("image_paths") or [])]
    url_by_path = _sign_image_paths(supabase, settings, all_paths)
    items = [_row_to_response(row, url_by_path, is_saved=True) for row in ordered_rows]

    return ReportListResponse(items=items, total=total, limit=limit, offset=offset)
