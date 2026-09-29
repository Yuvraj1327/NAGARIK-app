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


class ReportListResponse(BaseModel):
    """Paginated result of `GET /reports` (feed/search/discovery, Step 7/8)."""

    items: list[ReportResponse]
    total: int
    limit: int
    offset: int
