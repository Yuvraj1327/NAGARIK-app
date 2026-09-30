"""
Tests for report bookmarking (Report Sharing, Saved Reports & Final Feature
Polish): save/unsave a report, list a caller's saved reports, duplicate-save
prevention, per-caller isolation, and `GET /reports/{id}`'s `is_saved` field
— all using a fake Supabase client so these run with no network access and
no real Supabase project.
"""

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


def _make_token(sub: str) -> str:
    payload = {
        "sub": sub,
        "email": f"{sub}@example.com",
        "aud": "authenticated",
        "user_metadata": {"full_name": "Test User"},
        "exp": datetime.now(UTC) + timedelta(hours=1),
    }
    return jwt.encode(payload, TEST_JWT_SECRET, algorithm="HS256")


def _auth_headers(sub: str = "user-123") -> dict[str, str]:
    return {"Authorization": f"Bearer {_make_token(sub)}"}


class _FakeAPIError(Exception):
    """Minimal stand-in for `postgrest.exceptions.APIError` — see
    `test_reports.py`'s copy of this for why: `reports_service` inspects
    `.code` to tell a specific Postgres failure (here, `23505` unique and
    `23503` foreign-key violations) apart from an ordinary one."""

    def __init__(self, code: str, message: str = "simulated PostgREST error") -> None:
        self.code = code
        self.message = message
        super().__init__(message)


def _make_report_row(*, report_id: str | None = None, user_id: str = "other-user") -> dict:
    now = datetime.now(UTC)
    return {
        "id": report_id or str(uuid.uuid4()),
        "reference_id": f"NGR-{now.year}-00001",
        "user_id": user_id,
        "category": "road",
        "description": "A pothole outside the market.",
        "city": "Pune",
        "pin_code": "411001",
        "latitude": None,
        "longitude": None,
        "image_paths": [],
        "status": "submitted",
        "created_at": now.isoformat(),
        "updated_at": now.isoformat(),
    }


class _FakeReportsTable:
    """Just enough of postgrest-py's `.select(...).eq(...)/.in_(...)`
    chain, over a plain in-memory list, to back `get_report`'s single-row
    lookup and `list_saved_reports`' `.in_("id", [...])` fetch."""

    def __init__(self, rows: list[dict]) -> None:
        self.rows = rows
        self._filters: list = []

    def select(self, *_columns, count: str | None = None, **_ignored):
        self._filters = []
        return self

    def eq(self, column: str, value):
        self._filters.append(lambda row: row.get(column) == value)
        return self

    def in_(self, column: str, values):
        values_set = set(values)
        self._filters.append(lambda row: row.get(column) in values_set)
        return self

    def limit(self, _size: int, **_ignored):
        return self

    def execute(self) -> SimpleNamespace:
        rows = [row for row in self.rows if all(f(row) for f in self._filters)]
        return SimpleNamespace(data=rows, count=None)


class _FakeSavedReportsTable:
    """Enough of postgrest-py's insert/select/delete chain to exercise
    `save_report`/`unsave_report`/`list_saved_reports` for real, including
    the two constraints a real `saved_reports` insert can hit: the unique
    `(user_id, report_id)` pair (duplicate save -> `23505`) and the foreign
    key to `reports.id` (saving a nonexistent report -> `23503`) — both
    simulated the same way Postgres would report them, via `_FakeAPIError`.
    """

    def __init__(self, reports_table: _FakeReportsTable) -> None:
        self._reports_table = reports_table
        self.rows: list[dict] = []
        self._pending_insert: dict | None = None
        self._filters: list = []
        self._mode: str | None = None  # "select" | "delete"
        self._order_desc = False
        self._range: tuple[int, int] | None = None
        self._count_requested = False

    def insert(self, row: dict) -> "_FakeSavedReportsTable":
        self._pending_insert = row
        return self

    def select(self, *_columns, count: str | None = None, **_ignored):
        self._mode = "select"
        self._filters = []
        self._count_requested = count is not None
        return self

    def delete(self) -> "_FakeSavedReportsTable":
        self._mode = "delete"
        self._filters = []
        return self

    def eq(self, column: str, value):
        self._filters.append(lambda row: row.get(column) == value)
        return self

    def order(self, _column: str, *, desc: bool = False, **_ignored):
        self._order_desc = desc
        return self

    def range(self, start: int, end: int, **_ignored):
        self._range = (start, end)
        return self

    def limit(self, _size: int, **_ignored):
        return self

    def execute(self) -> SimpleNamespace:
        if self._pending_insert is not None:
            row = self._pending_insert
            self._pending_insert = None

            if not any(r["id"] == row["report_id"] for r in self._reports_table.rows):
                raise _FakeAPIError("23503", "insert or update violates foreign key constraint")

            duplicate = any(
                existing["user_id"] == row["user_id"]
                and existing["report_id"] == row["report_id"]
                for existing in self.rows
            )
            if duplicate:
                raise _FakeAPIError("23505", "duplicate key value violates unique constraint")

            record = {"id": str(uuid.uuid4()), "created_at": datetime.now(UTC).isoformat(), **row}
            self.rows.append(record)
            return SimpleNamespace(data=[record], count=None)

        matches = [row for row in self.rows if all(f(row) for f in self._filters)]
        if self._mode == "delete":
            self.rows = [row for row in self.rows if row not in matches]
            return SimpleNamespace(data=matches, count=None)

        matches = sorted(matches, key=lambda row: row["created_at"], reverse=self._order_desc)
        total = len(matches)
        if self._range is not None:
            start, end = self._range
            matches = matches[start : end + 1]
        return SimpleNamespace(data=matches, count=total if self._count_requested else None)


class FakeSupabaseClient:
    def __init__(self, *, report_rows: list[dict] | None = None) -> None:
        self._reports = _FakeReportsTable(list(report_rows or []))
        self._saved = _FakeSavedReportsTable(self._reports)

    def table(self, name: str):
        if name == "reports":
            return self._reports
        if name == "saved_reports":
            return self._saved
        raise AssertionError(f"unexpected table: {name}")


@pytest.fixture(autouse=True)
def _override_settings():
    app.dependency_overrides[get_settings] = _test_settings
    yield
    app.dependency_overrides.pop(get_settings, None)


@pytest.fixture
def make_fake_supabase():
    def _make(**kwargs) -> FakeSupabaseClient:
        fake = FakeSupabaseClient(**kwargs)
        app.dependency_overrides[get_supabase_service_client] = lambda: fake
        return fake

    yield _make
    app.dependency_overrides.pop(get_supabase_service_client, None)


def test_save_report_requires_authentication(make_fake_supabase):
    report = _make_report_row()
    make_fake_supabase(report_rows=[report])

    response = client.post(f"/api/v1/reports/{report['id']}/save")

    assert response.status_code == 401


def test_save_report_creates_a_bookmark(make_fake_supabase):
    report = _make_report_row()
    make_fake_supabase(report_rows=[report])

    response = client.post(f"/api/v1/reports/{report['id']}/save", headers=_auth_headers())

    assert response.status_code == 201
    assert response.json() == {"report_id": report["id"], "saved": True}


def test_saving_an_already_saved_report_is_idempotent(make_fake_supabase):
    report = _make_report_row()
    fake = make_fake_supabase(report_rows=[report])

    first = client.post(f"/api/v1/reports/{report['id']}/save", headers=_auth_headers())
    second = client.post(f"/api/v1/reports/{report['id']}/save", headers=_auth_headers())

    assert first.status_code == 201
    assert second.status_code == 201
    assert len(fake._saved.rows) == 1


def test_saving_a_nonexistent_report_returns_404(make_fake_supabase):
    make_fake_supabase(report_rows=[])

    response = client.post(
        f"/api/v1/reports/{uuid.uuid4()}/save", headers=_auth_headers()
    )

    assert response.status_code == 404


def test_unsave_report_removes_the_bookmark(make_fake_supabase):
    report = _make_report_row()
    make_fake_supabase(report_rows=[report])
    client.post(f"/api/v1/reports/{report['id']}/save", headers=_auth_headers())

    response = client.delete(f"/api/v1/reports/{report['id']}/save", headers=_auth_headers())

    assert response.status_code == 204
    listing = client.get("/api/v1/reports/saved", headers=_auth_headers())
    assert listing.json()["items"] == []


def test_unsaving_a_report_that_was_never_saved_is_a_no_op(make_fake_supabase):
    report = _make_report_row()
    make_fake_supabase(report_rows=[report])

    response = client.delete(f"/api/v1/reports/{report['id']}/save", headers=_auth_headers())

    assert response.status_code == 204


def test_unsave_report_requires_authentication(make_fake_supabase):
    report = _make_report_row()
    make_fake_supabase(report_rows=[report])

    response = client.delete(f"/api/v1/reports/{report['id']}/save")

    assert response.status_code == 401


def test_list_saved_reports_requires_authentication(make_fake_supabase):
    make_fake_supabase(report_rows=[])

    response = client.get("/api/v1/reports/saved")

    assert response.status_code == 401


def test_list_saved_reports_only_returns_the_callers_own(make_fake_supabase):
    report_a = _make_report_row()
    report_b = _make_report_row()
    make_fake_supabase(report_rows=[report_a, report_b])

    client.post(f"/api/v1/reports/{report_a['id']}/save", headers=_auth_headers("user-123"))
    client.post(f"/api/v1/reports/{report_b['id']}/save", headers=_auth_headers("user-456"))

    mine = client.get("/api/v1/reports/saved", headers=_auth_headers("user-123")).json()

    assert [item["id"] for item in mine["items"]] == [report_a["id"]]
    assert mine["total"] == 1


def test_list_saved_reports_marks_every_item_as_saved(make_fake_supabase):
    report = _make_report_row()
    make_fake_supabase(report_rows=[report])
    client.post(f"/api/v1/reports/{report['id']}/save", headers=_auth_headers())

    listing = client.get("/api/v1/reports/saved", headers=_auth_headers()).json()

    assert listing["items"][0]["is_saved"] is True


def test_saved_route_does_not_shadow_get_report_detail(make_fake_supabase):
    make_fake_supabase(report_rows=[])

    response = client.get("/api/v1/reports/saved", headers=_auth_headers())

    assert response.status_code == 200
    body = response.json()
    assert "items" in body and "total" in body


def test_get_report_detail_is_saved_is_false_for_anonymous_caller(make_fake_supabase):
    report = _make_report_row()
    make_fake_supabase(report_rows=[report])
    client.post(f"/api/v1/reports/{report['id']}/save", headers=_auth_headers())

    response = client.get(f"/api/v1/reports/{report['id']}")

    assert response.status_code == 200
    assert response.json()["is_saved"] is False


def test_get_report_detail_is_saved_reflects_the_authenticated_caller(make_fake_supabase):
    report = _make_report_row()
    make_fake_supabase(report_rows=[report])
    client.post(f"/api/v1/reports/{report['id']}/save", headers=_auth_headers("user-123"))

    mine = client.get(f"/api/v1/reports/{report['id']}", headers=_auth_headers("user-123"))
    someone_elses = client.get(
        f"/api/v1/reports/{report['id']}", headers=_auth_headers("user-456")
    )

    assert mine.json()["is_saved"] is True
    assert someone_elses.json()["is_saved"] is False
