"""Pydantic schemas and wire enums for the /reports endpoints."""

from datetime import datetime
from enum import Enum

from pydantic import BaseModel


class ReportCategory(str, Enum):
    """Mirrors the Flutter `ReportCategory` enum exactly (same member
    names), so no translation layer is needed between the two."""

    road = "road"
    streetlight = "streetlight"
    sanitation = "sanitation"
    water = "water"
    electricity = "electricity"
    safety = "safety"
    other = "other"


class ReportStatus(str, Enum):
    submitted = "submitted"
    in_review = "in_review"
    resolved = "resolved"


class ReportResponse(BaseModel):
    id: str
    # Stable, human-readable reference (e.g. "NGR-2026-00001") — see
    # backend/migrations/0003_report_reference_id.sql. Assigned once by a
    # database trigger on insert and never changed afterwards, so it's safe
    # to print, search for, or read aloud (e.g. when a citizen calls in
    # about a report), unlike `id` (an opaque UUID meant for the API, not
    # people).
    reference_id: str
    user_id: str
    category: ReportCategory
    description: str
    city: str
    pin_code: str
    latitude: float | None
    longitude: float | None
    image_paths: list[str]
    # Freshly signed Storage URLs for `image_paths` (Step 7), good for
    # `REPORT_IMAGE_SIGNED_URL_TTL_SECONDS`. The bucket is private, so
    # `image_paths` alone isn't fetchable by a client — always built
    # explicitly alongside `image_paths`, never derived from a raw DB row.
    image_urls: list[str]
    status: ReportStatus
    created_at: datetime
    updated_at: datetime
    # Whether the *currently authenticated caller* has bookmarked this
    # report (Report Sharing & Saved Reports upgrade) — never a count or
    # anyone else's saved state, just this caller's own. `False` for an
    # anonymous caller (there's no one to check a saved state for) and for
    # every row in a plain browse/search list, where computing it isn't
    # worth an extra query per row for a feature no card currently surfaces;
    # it's computed for real on `GET /reports/{id}` (Report Detail, where
    # the Save/Unsave button needs it) and is always `True` on
    # `GET /reports/saved` (by definition). See `reports_service.py`.
    is_saved: bool = False


class ReportListResponse(BaseModel):
    """Paginated result of `GET /reports` (feed/search/discovery, Step 7/8)."""

    items: list[ReportResponse]
    total: int
    limit: int
    offset: int


class ReportMarkerResponse(BaseModel):
    """One pin's worth of data for the Nearby/Discovery map (Location
    Discovery & Home upgrade) — deliberately a small subset of
    `ReportResponse`'s fields.

    A map view may render dozens of pins at once, and a marker only ever
    needs a location, a category (for the pin icon), a status (for the pin
    color), and enough identity to open the full report on tap — not the
    full description or signed image URLs, which `list_report_markers()`
    never fetches or signs for this response in the first place (see that
    function's docstring). Full report data, images included, is only ever
    fetched for the one report a marker's tap actually opens, via the
    existing `GET /reports/{report_id}`.
    """

    id: str
    reference_id: str
    category: ReportCategory
    status: ReportStatus
    city: str
    latitude: float
    longitude: float


class ReportMarkerListResponse(BaseModel):
    items: list[ReportMarkerResponse]


class SaveReportResponse(BaseModel):
    """Ack for `POST /reports/{id}/save` (Report Sharing & Saved Reports
    upgrade). `saved` is always `true` on success — saving a report that was
    already saved is treated as success too, not an error (see
    `reports_service.save_report`), so this response doesn't distinguish
    "just saved" from "was already saved"; either way the end state the
    caller asked for now holds."""

    report_id: str
    saved: bool


class ReportStatsResponse(BaseModel):
    """Per-status counts of the caller's own reports (Profile screen).

    `total` is always `submitted + in_review + resolved` — kept as its own
    field rather than making the client sum the three, since "total reports"
    is its own stat tile on the Profile screen.
    """

    total: int
    submitted: int
    in_review: int
    resolved: int
