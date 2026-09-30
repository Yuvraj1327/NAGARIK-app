"""
Tests for /reports (Step 5/6/7/8): creation with image upload, single-report
retrieval, and the browse/search/filter feed — all using a fake Supabase
client so these run with no network access and no real Supabase project.
"""

import io
import itertools
import re
import uuid
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from jose import jwt

from app.api.deps import get_supabase_service_client
from app.core.config import Settings, get_settings
from app.main import app

TEST_JWT_SECRET = "test-jwt-secret"

client = TestClient(app)


def _test_settings() -> Settings:
    return Settings(
        SUPABASE_URL="https://test.supabase.co",
        SUPABASE_ANON_KEY="anon-key",
        SUPABASE_SERVICE_ROLE_KEY="service-role-key",
        SUPABASE_JWT_SECRET=TEST_JWT_SECRET,
        SUPABASE_STORAGE_BUCKET="report-images",
    )


def _make_token(sub: str = "user-123") -> str:
    payload = {
        "sub": sub,
        "email": "citizen@example.com",
        "aud": "authenticated",
        "user_metadata": {"full_name": "Asha Rao"},
        "exp": datetime.now(UTC) + timedelta(hours=1),
    }
    return jwt.encode(payload, TEST_JWT_SECRET, algorithm="HS256")


def _auth_headers(sub: str = "user-123") -> dict[str, str]:
    return {"Authorization": f"Bearer {_make_token(sub=sub)}"}


class _FakeStorageBucket:
    def __init__(self) -> None:
        self.uploaded: list[str] = []
        self.removed: list[str] = []
        # When set, create_signed_urls raises instead of returning URLs, so
        # tests can exercise the "signing failed, still degrade gracefully"
        # path in `_sign_image_paths`.
        self.fail_signing = False

    def upload(self, path: str, data: bytes, file_options: dict | None = None) -> dict:
        self.uploaded.append(path)
        return {"path": path}

    def remove(self, paths: list[str]) -> None:
        self.removed.extend(paths)

    def create_signed_urls(self, paths: list[str], expires_in: int) -> list[dict]:
        if self.fail_signing:
            raise RuntimeError("simulated storage outage")
        return [
            {
                "path": path,
                "signedURL": f"https://test.supabase.co/storage/v1/{path}?token=fake&exp={expires_in}",
                "error": None,
            }
            for path in paths
        ]


class _FakeStorage:
    def __init__(self, bucket: _FakeStorageBucket) -> None:
        self._bucket = bucket

    def from_(self, bucket_name: str) -> _FakeStorageBucket:
        return self._bucket


class _FakeAPIError(Exception):
    """Minimal stand-in for `postgrest.exceptions.APIError` — real Supabase
    errors carry a `.code` (e.g. `"PGRST205"`), which is exactly what
    `reports_service._raise_for_supabase_error` inspects to tell "the
    schema/migrations aren't set up" apart from an ordinary failure. Kept
    separate from the real `postgrest` package so these tests don't need
    it installed just to simulate its error shape."""

    def __init__(self, code: str, message: str = "simulated PostgREST error") -> None:
        self.code = code
        self.message = message
        super().__init__(message)


class _FakeQueryBuilder:
    """Enough of postgrest-py's chained select/filter/execute API,
    implemented over a plain in-memory list, to exercise the real filtering,
    ordering, and pagination logic in `reports_service.list_reports`/
    `get_report` without a live Supabase project."""

    def __init__(self, rows: list[dict], *, fail_with_code: str | None = None) -> None:
        self._rows = rows
        self._filters: list = []
        self._order_key: str | None = None
        self._order_desc = False
        self._range: tuple[int, int] | None = None
        self._limit: int | None = None
        self._count_requested = False
        self._fail_with_code = fail_with_code

    def select(self, *columns: str, count: str | None = None, head: bool | None = None):
        self._count_requested = count is not None
        return self

    def eq(self, column: str, value):
        self._filters.append(lambda row: row.get(column) == value)
        return self

    def ilike(self, column: str, pattern: str):
        needle = pattern.strip("%").lower()
        self._filters.append(lambda row: needle in str(row.get(column, "")).lower())
        return self

    def or_(self, expression: str):
        clauses: list[tuple[str, str]] = []
        for part in expression.split(","):
            column, _op, value = part.split(".", 2)
            clauses.append((column, value.strip("%").lower()))

        def _matches(row: dict) -> bool:
            return any(needle in str(row.get(column, "")).lower() for column, needle in clauses)

        self._filters.append(_matches)
        return self

    def order(self, column: str, *, desc: bool = False, **_ignored):
        self._order_key = column
        self._order_desc = desc
        return self

    def range(self, start: int, end: int, **_ignored):
        self._range = (start, end)
        return self

    def limit(self, size: int, **_ignored):
        self._limit = size
        return self

    def execute(self) -> SimpleNamespace:
        if self._fail_with_code is not None:
            raise _FakeAPIError(self._fail_with_code)
        rows = [row for row in self._rows if all(f(row) for f in self._filters)]
        if self._order_key is not None:
            rows.sort(key=lambda row: row[self._order_key], reverse=self._order_desc)
        total = len(rows)
        if self._range is not None:
            start, end = self._range
            rows = rows[start : end + 1]
        elif self._limit is not None:
            rows = rows[: self._limit]
        return SimpleNamespace(data=rows, count=total if self._count_requested else None)


class _FakeTable:
    def __init__(
        self,
        *,
        fail_insert: bool = False,
        fail_insert_code: str | None = None,
        fail_query_code: str | None = None,
        seed_rows: list[dict] | None = None,
    ) -> None:
        self.rows: list[dict] = list(seed_rows or [])
        self.fail_insert = fail_insert
        self.fail_insert_code = fail_insert_code
        self.fail_query_code = fail_query_code
        self._pending_row: dict | None = None
        # Simulates `0003_report_reference_id.sql`'s per-year counter: a
        # fresh `_FakeTable` (one per test, via the `fake_supabase`/
        # `make_fake_supabase` fixtures) starts its own count at 1, same as
        # a brand-new Supabase project would for year `_reference_year`.
        self._reference_seq = itertools.count(1)
        self._reference_year = datetime.now(UTC).year

    def insert(self, row: dict) -> "_FakeTable":
        self._pending_row = row
        return self

    def select(self, *columns: str, count: str | None = None, head: bool | None = None):
        return _FakeQueryBuilder(self.rows, fail_with_code=self.fail_query_code).select(
            *columns, count=count, head=head
        )

    def execute(self) -> SimpleNamespace:
        if self.fail_insert_code is not None:
            raise _FakeAPIError(self.fail_insert_code)
        if self.fail_insert:
            raise RuntimeError("simulated database failure")
        # Mirrors what real Postgres/PostgREST does: columns not given an
        # explicit value get their schema DEFAULT (id, status, timestamps,
        # reference_id — the last one assigned by the `BEFORE INSERT`
        # trigger from 0003_report_reference_id.sql, simulated here the
        # same way), and `insert().execute()` returns the full stored row
        # either way.
        record = {
            "id": str(uuid.uuid4()),
            "reference_id": f"NGR-{self._reference_year}-{next(self._reference_seq):05d}",
            "status": "submitted",
            "created_at": datetime.now(UTC).isoformat(),
            "updated_at": datetime.now(UTC).isoformat(),
            **self._pending_row,
        }
        self.rows.append(record)
        return SimpleNamespace(data=[record])


class FakeSupabaseClient:
    def __init__(
        self,
        *,
        fail_insert: bool = False,
        fail_insert_code: str | None = None,
        fail_query_code: str | None = None,
        seed_rows: list[dict] | None = None,
    ) -> None:
        self.storage_bucket = _FakeStorageBucket()
        self.storage = _FakeStorage(self.storage_bucket)
        self._table = _FakeTable(
            fail_insert=fail_insert,
            fail_insert_code=fail_insert_code,
            fail_query_code=fail_query_code,
            seed_rows=seed_rows,
        )

    def table(self, name: str) -> _FakeTable:
        assert name == "reports"
        return self._table


# Backs `_make_report_row`'s default `reference_id` so every directly-seeded
# row gets its own unique one (matching the real unique index from
# 0003_report_reference_id.sql) without every call site having to invent
# one — a test that actually cares about the value passes it explicitly.
_seeded_reference_seq = itertools.count(1)


def _make_report_row(
    *,
    report_id: str | None = None,
    reference_id: str | None = None,
    user_id: str = "user-123",
    category: str = "road",
    description: str = "A civic issue report.",
    city: str = "Pune",
    pin_code: str = "411001",
    latitude: float | None = None,
    longitude: float | None = None,
    image_paths: list[str] | None = None,
    status: str = "submitted",
    created_at: datetime | None = None,
) -> dict:
    """Builds a full `reports` row the way Postgres would return it, for
    seeding retrieval/search tests directly (skipping a real POST)."""
    created = created_at or datetime.now(UTC)
    return {
        "id": report_id or str(uuid.uuid4()),
        "reference_id": reference_id
        or f"NGR-{created.year}-{next(_seeded_reference_seq):05d}",
        "user_id": user_id,
        "category": category,
        "description": description,
        "city": city,
        "pin_code": pin_code,
        "latitude": latitude,
        "longitude": longitude,
        "image_paths": image_paths or [],
        "status": status,
        "created_at": created.isoformat(),
        "updated_at": created.isoformat(),
    }


@pytest.fixture(autouse=True)
def _override_settings():
    app.dependency_overrides[get_settings] = _test_settings
    yield
    app.dependency_overrides.pop(get_settings, None)


@pytest.fixture
def fake_supabase():
    fake = FakeSupabaseClient()
    app.dependency_overrides[get_supabase_service_client] = lambda: fake
    yield fake
    app.dependency_overrides.pop(get_supabase_service_client, None)


@pytest.fixture
def make_fake_supabase():
    """Like `fake_supabase`, but lets retrieval/search tests seed rows
    up front (`make_fake_supabase(seed_rows=[...])`) instead of only
    reflecting whatever a POST created during the test."""

    def _make(**kwargs) -> FakeSupabaseClient:
        fake = FakeSupabaseClient(**kwargs)
        app.dependency_overrides[get_supabase_service_client] = lambda: fake
        return fake

    yield _make
    app.dependency_overrides.pop(get_supabase_service_client, None)


def test_submit_report_without_images_succeeds(fake_supabase):
    response = client.post(
        "/api/v1/reports",
        headers=_auth_headers(),
        data={
            "category": "road",
            "description": "Large pothole near the bus stop.",
            "city": "Pune",
            "pin_code": "411001",
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["user_id"] == "user-123"
    assert body["category"] == "road"
    assert body["status"] == "submitted"
    assert body["image_paths"] == []
    assert fake_supabase.storage_bucket.uploaded == []


def test_submit_report_with_images_uploads_and_links_them(fake_supabase):
    files = [
        ("images", ("photo1.jpg", io.BytesIO(b"fake-bytes-1"), "image/jpeg")),
        ("images", ("photo2.png", io.BytesIO(b"fake-bytes-2"), "image/png")),
    ]

    response = client.post(
        "/api/v1/reports",
        headers=_auth_headers(),
        data={
            "category": "sanitation",
            "description": "Overflowing garbage bin for a week.",
            "city": "Pune",
            "pin_code": "411001",
            "latitude": "18.5204",
            "longitude": "73.8567",
        },
        files=files,
    )

    assert response.status_code == 201
    body = response.json()
    assert len(body["image_paths"]) == 2
    assert all(path.startswith("user-123/") for path in body["image_paths"])
    assert fake_supabase.storage_bucket.uploaded == body["image_paths"]
    assert body["latitude"] == 18.5204
    assert body["longitude"] == 73.8567
    # Step 7: every image also comes back with a freshly signed URL.
    assert len(body["image_urls"]) == 2
    assert all(url.startswith("https://") for url in body["image_urls"])


def test_submit_report_rejects_short_description(fake_supabase):
    response = client.post(
        "/api/v1/reports",
        headers=_auth_headers(),
        data={
            "category": "road",
            "description": "too short",
            "city": "Pune",
            "pin_code": "411001",
        },
    )
    assert response.status_code == 422


def test_submit_report_rejects_invalid_pin_code(fake_supabase):
    response = client.post(
        "/api/v1/reports",
        headers=_auth_headers(),
        data={
            "category": "road",
            "description": "Large pothole near the bus stop.",
            "city": "Pune",
            "pin_code": "abc123",
        },
    )
    assert response.status_code == 422


def test_submit_report_rejects_description_over_max_length(fake_supabase):
    response = client.post(
        "/api/v1/reports",
        headers=_auth_headers(),
        data={
            "category": "road",
            "description": "x" * 2001,
            "city": "Pune",
            "pin_code": "411001",
        },
    )
    assert response.status_code == 422


def test_submit_report_rejects_city_over_max_length(fake_supabase):
    response = client.post(
        "/api/v1/reports",
        headers=_auth_headers(),
        data={
            "category": "road",
            "description": "Large pothole near the bus stop.",
            "city": "x" * 101,
            "pin_code": "411001",
        },
    )
    assert response.status_code == 422


def test_submit_report_rejects_unsupported_image_type(fake_supabase):
    files = [("images", ("doc.pdf", io.BytesIO(b"%PDF-1.4"), "application/pdf"))]

    response = client.post(
        "/api/v1/reports",
        headers=_auth_headers(),
        data={
            "category": "road",
            "description": "Large pothole near the bus stop.",
            "city": "Pune",
            "pin_code": "411001",
        },
        files=files,
    )
    assert response.status_code == 400
    assert fake_supabase.storage_bucket.uploaded == []


def test_submit_report_requires_authentication(fake_supabase):
    response = client.post(
        "/api/v1/reports",
        data={
            "category": "road",
            "description": "Large pothole near the bus stop.",
            "city": "Pune",
            "pin_code": "411001",
        },
    )
    assert response.status_code == 401


def test_submit_report_cleans_up_uploaded_images_on_db_failure():
    fake = FakeSupabaseClient(fail_insert=True)
    app.dependency_overrides[get_supabase_service_client] = lambda: fake
    try:
        files = [("images", ("photo1.jpg", io.BytesIO(b"fake-bytes-1"), "image/jpeg"))]
        response = client.post(
            "/api/v1/reports",
            headers=_auth_headers(),
            data={
                "category": "road",
                "description": "Large pothole near the bus stop.",
                "city": "Pune",
                "pin_code": "411001",
            },
            files=files,
        )
        assert response.status_code == 502
        assert len(fake.storage_bucket.uploaded) == 1
        assert fake.storage_bucket.removed == fake.storage_bucket.uploaded
    finally:
        app.dependency_overrides.pop(get_supabase_service_client, None)


def test_submit_report_returns_503_when_reports_table_is_missing():
    """A `PGRST205` ('Could not find the table public.reports in the schema
    cache') means the SQL migrations haven't been run against this Supabase
    project — a setup problem, not a transient failure, so it should be a
    distinct 503 with guidance, not the generic "try again" 502."""
    fake = FakeSupabaseClient(fail_insert_code="PGRST205")
    app.dependency_overrides[get_supabase_service_client] = lambda: fake
    try:
        response = client.post(
            "/api/v1/reports",
            headers=_auth_headers(),
            data={
                "category": "road",
                "description": "Large pothole near the bus stop.",
                "city": "Pune",
                "pin_code": "411001",
            },
        )
        assert response.status_code == 503
        assert "migrations" in response.json()["detail"].lower()
    finally:
        app.dependency_overrides.pop(get_supabase_service_client, None)


# ---------------------------------------------------------------------------
# GET /reports/{id} (Step 7)
# ---------------------------------------------------------------------------


def test_get_report_detail_returns_the_report(make_fake_supabase):
    row = _make_report_row(image_paths=["user-123/photo.jpg"])
    make_fake_supabase(seed_rows=[row])

    response = client.get(f"/api/v1/reports/{row['id']}")

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == row["id"]
    assert body["image_paths"] == ["user-123/photo.jpg"]
    assert body["image_urls"] == [
        "https://test.supabase.co/storage/v1/user-123/photo.jpg?token=fake&exp=3600"
    ]


def test_get_report_detail_requires_no_authentication():
    """Browsing a single report is public — no bearer token needed."""
    row = _make_report_row()
    make_fake = FakeSupabaseClient(seed_rows=[row])
    app.dependency_overrides[get_supabase_service_client] = lambda: make_fake
    try:
        response = client.get(f"/api/v1/reports/{row['id']}")
        assert response.status_code == 200
    finally:
        app.dependency_overrides.pop(get_supabase_service_client, None)


def test_get_report_detail_404_for_unknown_id(make_fake_supabase):
    make_fake_supabase(seed_rows=[])

    response = client.get("/api/v1/reports/does-not-exist")

    assert response.status_code == 404


def test_get_report_detail_returns_503_when_reports_table_is_missing(make_fake_supabase):
    make_fake_supabase(fail_query_code="PGRST205")

    response = client.get("/api/v1/reports/anything")

    assert response.status_code == 503
    assert "migrations" in response.json()["detail"].lower()


def test_get_report_detail_degrades_gracefully_when_signing_fails(make_fake_supabase):
    row = _make_report_row(image_paths=["user-123/photo.jpg"])
    fake = make_fake_supabase(seed_rows=[row])
    fake.storage_bucket.fail_signing = True

    response = client.get(f"/api/v1/reports/{row['id']}")

    assert response.status_code == 200
    body = response.json()
    assert body["image_paths"] == ["user-123/photo.jpg"]
    assert body["image_urls"] == []


# ---------------------------------------------------------------------------
# GET /reports (Step 7 feed baseline + Step 8 filters/search/pagination)
# ---------------------------------------------------------------------------


def test_browse_reports_orders_most_recent_first(make_fake_supabase):
    base = datetime.now(UTC)
    oldest = _make_report_row(created_at=base - timedelta(minutes=10))
    newest = _make_report_row(created_at=base)
    middle = _make_report_row(created_at=base - timedelta(minutes=5))
    make_fake_supabase(seed_rows=[oldest, newest, middle])

    response = client.get("/api/v1/reports")

    assert response.status_code == 200
    body = response.json()
    assert [item["id"] for item in body["items"]] == [newest["id"], middle["id"], oldest["id"]]
    assert body["total"] == 3
    assert body["limit"] == 20
    assert body["offset"] == 0


def test_browse_reports_filters_by_category(make_fake_supabase):
    road = _make_report_row(category="road")
    water = _make_report_row(category="water")
    make_fake_supabase(seed_rows=[road, water])

    response = client.get("/api/v1/reports", params={"category": "water"})

    body = response.json()
    assert [item["id"] for item in body["items"]] == [water["id"]]


def test_browse_reports_filters_by_status(make_fake_supabase):
    submitted = _make_report_row(status="submitted")
    resolved = _make_report_row(status="resolved")
    make_fake_supabase(seed_rows=[submitted, resolved])

    response = client.get("/api/v1/reports", params={"status": "resolved"})

    body = response.json()
    assert [item["id"] for item in body["items"]] == [resolved["id"]]


def test_browse_reports_filters_by_city_case_insensitive_partial(make_fake_supabase):
    pune = _make_report_row(city="Pune")
    mumbai = _make_report_row(city="Mumbai")
    make_fake_supabase(seed_rows=[pune, mumbai])

    response = client.get("/api/v1/reports", params={"city": "pune"})

    body = response.json()
    assert [item["id"] for item in body["items"]] == [pune["id"]]


def test_browse_reports_filters_by_exact_pin_code(make_fake_supabase):
    a = _make_report_row(pin_code="411001")
    b = _make_report_row(pin_code="411002")
    make_fake_supabase(seed_rows=[a, b])

    response = client.get("/api/v1/reports", params={"pin_code": "411002"})

    body = response.json()
    assert [item["id"] for item in body["items"]] == [b["id"]]


def test_browse_reports_search_matches_description_or_city(make_fake_supabase):
    by_description = _make_report_row(description="Large pothole on Main Street", city="Pune")
    by_city = _make_report_row(description="Streetlight broken", city="Mainpuri")
    unrelated = _make_report_row(description="Overflowing bin", city="Nashik")
    make_fake_supabase(seed_rows=[by_description, by_city, unrelated])

    response = client.get("/api/v1/reports", params={"search": "main"})

    body = response.json()
    ids = {item["id"] for item in body["items"]}
    assert ids == {by_description["id"], by_city["id"]}


def test_browse_reports_pagination_limit_and_offset(make_fake_supabase):
    base = datetime.now(UTC)
    rows = [_make_report_row(created_at=base - timedelta(minutes=i)) for i in range(5)]
    make_fake_supabase(seed_rows=rows)

    response = client.get("/api/v1/reports", params={"limit": 2, "offset": 1})

    body = response.json()
    assert body["total"] == 5
    assert body["limit"] == 2
    assert body["offset"] == 1
    # Rows are `minutes=0..4` old, so most-recent-first is rows[0..4]; offset
    # 1 skips rows[0] and takes the next 2.
    assert [item["id"] for item in body["items"]] == [rows[1]["id"], rows[2]["id"]]


def test_browse_reports_mine_requires_authentication(make_fake_supabase):
    make_fake_supabase(seed_rows=[_make_report_row()])

    response = client.get("/api/v1/reports", params={"mine": True})

    assert response.status_code == 401


def test_browse_reports_mine_returns_only_the_callers_reports(make_fake_supabase):
    mine_1 = _make_report_row(user_id="user-123")
    mine_2 = _make_report_row(user_id="user-123")
    someone_elses = _make_report_row(user_id="user-999")
    make_fake_supabase(seed_rows=[mine_1, mine_2, someone_elses])

    response = client.get(
        "/api/v1/reports", params={"mine": True}, headers=_auth_headers(sub="user-123")
    )

    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 2
    assert {item["id"] for item in body["items"]} == {mine_1["id"], mine_2["id"]}


def test_browse_reports_nearby_requires_both_coordinates(make_fake_supabase):
    make_fake_supabase(seed_rows=[])

    response = client.get("/api/v1/reports", params={"latitude": 18.52})

    assert response.status_code == 400


def test_browse_reports_nearby_filters_by_radius_and_sorts_by_distance(make_fake_supabase):
    query_lat, query_lon = 18.5204, 73.8567
    close = _make_report_row(latitude=18.5254, longitude=73.8567)  # ~0.55km away
    moderate = _make_report_row(latitude=18.5474, longitude=73.8567)  # ~3km away
    far_away = _make_report_row(latitude=18.9750, longitude=72.8258)  # Mumbai, >100km away
    no_location = _make_report_row(latitude=None, longitude=None)
    make_fake_supabase(seed_rows=[far_away, no_location, moderate, close])

    response = client.get(
        "/api/v1/reports",
        params={"latitude": query_lat, "longitude": query_lon, "radius_km": 5},
    )

    assert response.status_code == 200
    body = response.json()
    # Ordered nearest-first, `far_away` and `no_location` excluded entirely.
    assert [item["id"] for item in body["items"]] == [close["id"], moderate["id"]]
    assert body["total"] == 2


def test_browse_reports_degrades_gracefully_when_signing_fails(make_fake_supabase):
    row = _make_report_row(image_paths=["user-123/a.jpg", "user-123/b.jpg"])
    fake = make_fake_supabase(seed_rows=[row])
    fake.storage_bucket.fail_signing = True

    response = client.get("/api/v1/reports")

    assert response.status_code == 200
    body = response.json()
    assert body["items"][0]["image_paths"] == ["user-123/a.jpg", "user-123/b.jpg"]
    assert body["items"][0]["image_urls"] == []


def test_browse_reports_returns_503_when_reports_table_is_missing(make_fake_supabase):
    make_fake_supabase(fail_query_code="PGRST205")

    response = client.get("/api/v1/reports")

    assert response.status_code == 503
    assert "migrations" in response.json()["detail"].lower()


def test_browse_reports_nearby_returns_503_when_reports_table_is_missing(make_fake_supabase):
    """The nearby-search branch executes a different query chain than the
    plain paginated one — worth covering separately since it's a distinct
    code path in `list_reports`."""
    make_fake_supabase(fail_query_code="PGRST205")

    response = client.get("/api/v1/reports", params={"latitude": 18.52, "longitude": 73.85})

    assert response.status_code == 503
    assert "migrations" in response.json()["detail"].lower()


# ---------------------------------------------------------------------------
# GET /reports/stats (Profile screen)
# ---------------------------------------------------------------------------


def test_report_stats_requires_authentication(make_fake_supabase):
    make_fake_supabase(seed_rows=[])

    response = client.get("/api/v1/reports/stats")

    assert response.status_code == 401


def test_report_stats_counts_only_the_callers_own_reports_by_status(make_fake_supabase):
    rows = [
        _make_report_row(user_id="user-123", status="submitted"),
        _make_report_row(user_id="user-123", status="submitted"),
        _make_report_row(user_id="user-123", status="in_review"),
        _make_report_row(user_id="user-123", status="resolved"),
        # Someone else's reports — must not be counted.
        _make_report_row(user_id="someone-else", status="submitted"),
        _make_report_row(user_id="someone-else", status="resolved"),
    ]
    make_fake_supabase(seed_rows=rows)

    response = client.get("/api/v1/reports/stats", headers=_auth_headers(sub="user-123"))

    assert response.status_code == 200
    assert response.json() == {
        "total": 4,
        "submitted": 2,
        "in_review": 1,
        "resolved": 1,
    }


def test_report_stats_is_all_zero_for_a_user_with_no_reports(make_fake_supabase):
    make_fake_supabase(seed_rows=[_make_report_row(user_id="someone-else")])

    response = client.get("/api/v1/reports/stats", headers=_auth_headers(sub="user-123"))

    assert response.status_code == 200
    assert response.json() == {"total": 0, "submitted": 0, "in_review": 0, "resolved": 0}


def test_report_stats_returns_503_when_reports_table_is_missing(make_fake_supabase):
    make_fake_supabase(fail_query_code="PGRST205")

    response = client.get("/api/v1/reports/stats", headers=_auth_headers())

    assert response.status_code == 503
    assert "migrations" in response.json()["detail"].lower()


def test_report_stats_route_does_not_shadow_get_report_detail(make_fake_supabase):
    """Regression test for the FastAPI route-ordering hazard called out in
    the endpoint's own comment: `/reports/stats` must reach the stats
    handler, never `GET /{report_id}` with `report_id="stats"`."""
    make_fake_supabase(seed_rows=[])

    response = client.get("/api/v1/reports/stats", headers=_auth_headers())

    assert response.status_code == 200
    assert "total" in response.json()


# ---------------------------------------------------------------------------
# Report reference IDs (My Reports & Report Tracking upgrade) —
# see backend/migrations/0003_report_reference_id.sql. `_FakeTable.execute`
# simulates the real `BEFORE INSERT` trigger, so these exercise the same
# "the caller never supplies it, the row always comes back with one"
# contract the real database enforces.
# ---------------------------------------------------------------------------

_REFERENCE_ID_PATTERN = re.compile(r"^NGR-\d{4}-\d{5}$")


def test_submit_report_response_includes_a_well_formed_reference_id(fake_supabase):
    response = client.post(
        "/api/v1/reports",
        headers=_auth_headers(),
        data={
            "category": "road",
            "description": "Large pothole near the bus stop.",
            "city": "Pune",
            "pin_code": "411001",
        },
    )

    assert response.status_code == 201
    reference_id = response.json()["reference_id"]
    assert _REFERENCE_ID_PATTERN.match(reference_id), reference_id


def test_submitting_two_reports_gives_each_a_different_reference_id(fake_supabase):
    def _submit() -> str:
        response = client.post(
            "/api/v1/reports",
            headers=_auth_headers(),
            data={
                "category": "road",
                "description": "Large pothole near the bus stop.",
                "city": "Pune",
                "pin_code": "411001",
            },
        )
        assert response.status_code == 201
        return response.json()["reference_id"]

    first = _submit()
    second = _submit()

    assert first != second


def test_get_report_detail_includes_the_reference_id(make_fake_supabase):
    row = _make_report_row(reference_id="NGR-2026-00042")
    make_fake_supabase(seed_rows=[row])

    response = client.get(f"/api/v1/reports/{row['id']}")

    assert response.status_code == 200
    assert response.json()["reference_id"] == "NGR-2026-00042"


def test_browse_reports_includes_reference_id_for_every_item(make_fake_supabase):
    rows = [_make_report_row(), _make_report_row()]
    make_fake_supabase(seed_rows=rows)

    response = client.get("/api/v1/reports")

    assert response.status_code == 200
    reference_ids = [item["reference_id"] for item in response.json()["items"]]
    assert all(_REFERENCE_ID_PATTERN.match(value) for value in reference_ids)
    # Also unique across the page — two reports never share an id.
    assert len(reference_ids) == len(set(reference_ids))


def test_browse_reports_mine_does_not_leak_another_users_reference_id(make_fake_supabase):
    """User isolation, specifically for the My Reports screen: a caller's
    `?mine=true` results must never include another user's report, whether
    identified by `id` or by `reference_id`."""
    mine = _make_report_row(user_id="user-123", reference_id="NGR-2026-00001")
    someone_elses = _make_report_row(user_id="user-999", reference_id="NGR-2026-00002")
    make_fake_supabase(seed_rows=[mine, someone_elses])

    response = client.get(
        "/api/v1/reports", params={"mine": True}, headers=_auth_headers(sub="user-123")
    )

    assert response.status_code == 200
    body = response.json()
    reference_ids = {item["reference_id"] for item in body["items"]}
    assert reference_ids == {"NGR-2026-00001"}
    assert "NGR-2026-00002" not in reference_ids


# ---------------------------------------------------------------------------
# GET /reports/markers (Location Discovery & Home upgrade) — lean data for
# the Nearby/Discovery map.
# ---------------------------------------------------------------------------

_MARKER_FIELDS = {"id", "reference_id", "category", "status", "city", "latitude", "longitude"}


def test_get_report_markers_route_does_not_shadow_get_report_detail(make_fake_supabase):
    """Same route-ordering hazard as `/stats`: `/reports/markers` must reach
    the markers handler, never `GET /{report_id}` with `report_id="markers"`."""
    make_fake_supabase(seed_rows=[])

    response = client.get("/api/v1/reports/markers")

    assert response.status_code == 200
    assert response.json() == {"items": []}


def test_get_report_markers_returns_only_the_lean_marker_fields(make_fake_supabase):
    row = _make_report_row(latitude=18.5204, longitude=73.8567)
    make_fake_supabase(seed_rows=[row])

    response = client.get("/api/v1/reports/markers")

    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 1
    assert set(items[0].keys()) == _MARKER_FIELDS
    assert items[0]["id"] == row["id"]
    assert items[0]["reference_id"] == row["reference_id"]


def test_get_report_markers_omits_reports_without_coordinates(make_fake_supabase):
    with_coords = _make_report_row(latitude=18.5204, longitude=73.8567)
    without_coords = _make_report_row(latitude=None, longitude=None)
    make_fake_supabase(seed_rows=[with_coords, without_coords])

    response = client.get("/api/v1/reports/markers")

    assert response.status_code == 200
    ids = {item["id"] for item in response.json()["items"]}
    assert ids == {with_coords["id"]}


def test_get_report_markers_filters_by_category(make_fake_supabase):
    road = _make_report_row(category="road", latitude=18.52, longitude=73.85)
    water = _make_report_row(category="water", latitude=18.53, longitude=73.86)
    make_fake_supabase(seed_rows=[road, water])

    response = client.get("/api/v1/reports/markers", params={"category": "road"})

    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 1
    assert items[0]["id"] == road["id"]


def test_get_report_markers_nearby_filters_by_radius(make_fake_supabase):
    near = _make_report_row(latitude=18.5204, longitude=73.8567)  # Pune
    far = _make_report_row(latitude=28.7041, longitude=77.1025)  # Delhi
    make_fake_supabase(seed_rows=[near, far])

    response = client.get(
        "/api/v1/reports/markers",
        params={"latitude": 18.5204, "longitude": 73.8567, "radius_km": 5},
    )

    assert response.status_code == 200
    ids = {item["id"] for item in response.json()["items"]}
    assert ids == {near["id"]}


def test_get_report_markers_nearby_requires_both_coordinates(make_fake_supabase):
    make_fake_supabase(seed_rows=[])

    response = client.get("/api/v1/reports/markers", params={"latitude": 18.5204})

    assert response.status_code == 400


def test_get_report_markers_returns_503_when_reports_table_is_missing(make_fake_supabase):
    make_fake_supabase(fail_query_code="PGRST205")

    response = client.get("/api/v1/reports/markers")

    assert response.status_code == 503
    assert "migrations" in response.json()["detail"].lower()


def test_get_report_markers_requires_no_authentication(make_fake_supabase):
    """The map is public, same as the feed/search results it's an
    alternate view of — no bearer token needed."""
    make_fake_supabase(seed_rows=[_make_report_row(latitude=18.52, longitude=73.85)])

    response = client.get("/api/v1/reports/markers")

    assert response.status_code == 200
