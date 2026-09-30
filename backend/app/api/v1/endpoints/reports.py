"""
Civic report endpoints.

`POST /` (Step 5/6) creates a report: requires a signed-in user, uploads
any attached images to Supabase Storage, and inserts the report row —
using the Supabase SERVICE ROLE client, so the backend (not Postgres RLS)
is what enforces "a report belongs to its authenticated creator".

`GET /{id}` and `GET /` (Step 7/8) don't require a bearer token at the API
level: anyone with network access to this backend can browse and search
reports, and `GET /?mine=true` is the only case that needs a signed-in
caller (to know whose reports to return). The Flutter app's own screens
are more restrictive than that: its router requires a signed-in user for
every screen, including Home and Search, so in practice these two
endpoints are only ever called by an already-authenticated app session —
they're left optional here rather than tightened to match, since a public
read API for civic reports is a reasonable thing to keep open for other
future clients (a public website, an open-data export) even though
today's one client always sends a token. Every response signs its own
image URLs against the private Storage bucket rather than returning raw,
unfetchable paths.

`POST /{id}/save`, `DELETE /{id}/save`, and `GET /saved` (Report Sharing &
Saved Reports upgrade) let a signed-in caller bookmark a report, remove a
bookmark, and list their own bookmarks — all three require a token, since a
saved report belongs to whoever saved it. `GET /{id}` uses
`get_optional_current_user` (not `get_current_user`) so it stays public
while still returning the right `is_saved` for a caller who happens to be
signed in.
"""

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status

from app.api.deps import (
    CurrentUser,
    get_current_user,
    get_optional_current_user,
    get_supabase_service_client,
)
from app.core.config import Settings, get_settings
from app.schemas.report import (
    ReportCategory,
    ReportListResponse,
    ReportMarkerListResponse,
    ReportResponse,
    ReportStatsResponse,
    ReportStatus,
    SaveReportResponse,
)
from app.services.reports_service import (
    create_report,
    get_report,
    get_report_stats,
    list_report_markers,
    list_reports,
    list_saved_reports,
    save_report,
    unsave_report,
)

router = APIRouter()


@router.post(
    "",
    response_model=ReportResponse,
    status_code=201,
    summary="Submit a new civic issue report",
)
async def submit_report(
    category: ReportCategory = Form(...),
    # Upper bounds (Step 9 hardening) so a malicious or buggy client can't
    # push an unbounded amount of text through a "text" field — there was
    # previously no ceiling on either.
    description: str = Form(..., min_length=10, max_length=2000),
    city: str = Form(..., min_length=1, max_length=100),
    pin_code: str = Form(..., pattern=r"^[0-9]{6}$"),
    latitude: float | None = Form(None),
    longitude: float | None = Form(None),
    images: list[UploadFile] | None = File(None),
    current_user: CurrentUser = Depends(get_current_user),
    settings: Settings = Depends(get_settings),
    supabase=Depends(get_supabase_service_client),
) -> ReportResponse:
    return await create_report(
        supabase=supabase,
        settings=settings,
        user_id=current_user.id,
        category=category,
        description=description,
        city=city,
        pin_code=pin_code,
        latitude=latitude,
        longitude=longitude,
        images=images or [],
    )


@router.get(
    "",
    response_model=ReportListResponse,
    summary="Browse, search, and filter civic issue reports",
)
async def browse_reports(
    category: ReportCategory | None = Query(None),
    report_status: ReportStatus | None = Query(None, alias="status"),
    city: str | None = Query(None, min_length=1, max_length=100),
    pin_code: str | None = Query(None, pattern=r"^[0-9]{6}$"),
    search: str | None = Query(None, min_length=1, max_length=200),
    mine: bool = Query(False, description="Only the signed-in caller's own reports"),
    latitude: float | None = Query(None, ge=-90, le=90),
    longitude: float | None = Query(None, ge=-180, le=180),
    radius_km: float | None = Query(None, gt=0, le=100),
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    current_user: CurrentUser | None = Depends(get_optional_current_user),
    settings: Settings = Depends(get_settings),
    supabase=Depends(get_supabase_service_client),
) -> ReportListResponse:
    if (latitude is None) != (longitude is None):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="latitude and longitude must be provided together for a nearby search.",
        )

    user_id: str | None = None
    if mine:
        if current_user is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Sign in to view your own reports.",
            )
        user_id = current_user.id

    return await list_reports(
        supabase=supabase,
        settings=settings,
        category=category,
        status_filter=report_status,
        city=city,
        pin_code=pin_code,
        search=search,
        user_id=user_id,
        latitude=latitude,
        longitude=longitude,
        radius_km=radius_km,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/stats",
    response_model=ReportStatsResponse,
    summary="Get the signed-in caller's own report counts (Profile screen)",
)
async def get_my_report_stats(
    current_user: CurrentUser = Depends(get_current_user),
    supabase=Depends(get_supabase_service_client),
) -> ReportStatsResponse:
    # Registered ABOVE `GET /{report_id}` deliberately: both are a bare
    # `GET` one path segment past `/reports`, and FastAPI/Starlette matches
    # routes in registration order, so `/reports/stats` would otherwise be
    # swallowed by `/{report_id}` (with `report_id="stats"`) instead of
    # reaching this handler.
    return await get_report_stats(supabase=supabase, user_id=current_user.id)


@router.get(
    "/markers",
    response_model=ReportMarkerListResponse,
    summary="Lean report data for the Nearby/Discovery map (no images, no description)",
)
async def get_report_markers(
    category: ReportCategory | None = Query(None),
    report_status: ReportStatus | None = Query(None, alias="status"),
    city: str | None = Query(None, min_length=1, max_length=100),
    pin_code: str | None = Query(None, pattern=r"^[0-9]{6}$"),
    search: str | None = Query(None, min_length=1, max_length=200),
    latitude: float | None = Query(None, ge=-90, le=90),
    longitude: float | None = Query(None, ge=-180, le=180),
    radius_km: float | None = Query(None, gt=0, le=100),
    supabase=Depends(get_supabase_service_client),
) -> ReportMarkerListResponse:
    # Registered ABOVE `GET /{report_id}` deliberately, same reason as
    # `/stats` above: FastAPI/Starlette matches routes in registration
    # order, so `/reports/markers` must come first or it would be swallowed
    # by `/{report_id}` with `report_id="markers"`.
    if (latitude is None) != (longitude is None):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="latitude and longitude must be provided together for a nearby search.",
        )

    return await list_report_markers(
        supabase=supabase,
        category=category,
        status_filter=report_status,
        city=city,
        pin_code=pin_code,
        search=search,
        latitude=latitude,
        longitude=longitude,
        radius_km=radius_km,
    )


@router.get(
    "/saved",
    response_model=ReportListResponse,
    summary="Get the signed-in caller's saved (bookmarked) reports",
)
async def get_saved_reports(
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    current_user: CurrentUser = Depends(get_current_user),
    settings: Settings = Depends(get_settings),
    supabase=Depends(get_supabase_service_client),
) -> ReportListResponse:
    # Registered ABOVE `GET /{report_id}` deliberately, same reason as
    # `/stats` and `/markers` above: FastAPI/Starlette matches routes in
    # registration order, so `/reports/saved` must come first or it would be
    # swallowed by `/{report_id}` with `report_id="saved"`.
    return await list_saved_reports(
        supabase=supabase,
        settings=settings,
        user_id=current_user.id,
        limit=limit,
        offset=offset,
    )


@router.post(
    "/{report_id}/save",
    response_model=SaveReportResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Bookmark a report for the signed-in caller",
)
async def save_report_endpoint(
    report_id: str,
    current_user: CurrentUser = Depends(get_current_user),
    supabase=Depends(get_supabase_service_client),
) -> SaveReportResponse:
    # `/{report_id}/save` has one more path segment than `/{report_id}`
    # itself, so — unlike `/stats`/`/markers`/`/saved` above — there's no
    # route-shadowing risk here regardless of registration order.
    await save_report(supabase=supabase, user_id=current_user.id, report_id=report_id)
    return SaveReportResponse(report_id=report_id, saved=True)


@router.delete(
    "/{report_id}/save",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Remove a bookmark for the signed-in caller",
)
async def unsave_report_endpoint(
    report_id: str,
    current_user: CurrentUser = Depends(get_current_user),
    supabase=Depends(get_supabase_service_client),
) -> None:
    await unsave_report(supabase=supabase, user_id=current_user.id, report_id=report_id)


@router.get(
    "/{report_id}",
    response_model=ReportResponse,
    summary="Get a single report's full details",
)
async def get_report_detail(
    report_id: str,
    current_user: CurrentUser | None = Depends(get_optional_current_user),
    settings: Settings = Depends(get_settings),
    supabase=Depends(get_supabase_service_client),
) -> ReportResponse:
    # Still public (no token required) — `get_optional_current_user` only
    # lets a *signed-in* caller's own `is_saved` state come back correctly,
    # the same "optional auth" shape `GET /reports?mine=true` already uses.
    return await get_report(
        supabase=supabase,
        settings=settings,
        report_id=report_id,
        current_user_id=current_user.id if current_user else None,
    )
