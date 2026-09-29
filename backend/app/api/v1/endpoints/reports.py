"""
Civic report endpoints.

`POST /` (Step 5/6) creates a report: requires a signed-in user, uploads
any attached images to Supabase Storage, and inserts the report row —
using the Supabase SERVICE ROLE client, so the backend (not Postgres RLS)
is what enforces "a report belongs to its authenticated creator".

`GET /{id}` and `GET /` (Step 7/8) are public: anyone can browse and search
reports (the feed and search tabs don't require login), but `GET
/?mine=true` needs a signed-in caller to know whose reports to return.
Every response signs its own image URLs against the private Storage
bucket rather than returning raw, unfetchable paths.
"""

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status

from app.api.deps import (
    CurrentUser,
    get_current_user,
    get_optional_current_user,
    get_supabase_service_client,
)
from app.core.config import Settings, get_settings
from app.schemas.report import ReportCategory, ReportListResponse, ReportResponse, ReportStatus
from app.services.reports_service import create_report, get_report, list_reports

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
    "/{report_id}",
    response_model=ReportResponse,
    summary="Get a single report's full details",
)
async def get_report_detail(
    report_id: str,
    settings: Settings = Depends(get_settings),
    supabase=Depends(get_supabase_service_client),
) -> ReportResponse:
    return await get_report(supabase=supabase, settings=settings, report_id=report_id)
