"""
Tests for `POST /users/me/avatar` and `DELETE /users/me/avatar` (Official
Logo & User Profile Photo upgrade) — upload, replace (including an
extension change), remove, validation, and auth, all against a fake
Supabase Storage client so these run with no network access and no real
Supabase project.

A self-contained fake, separate from `test_reports.py`'s (which fakes the
`reports` table + the report-images bucket) and `test_users.py`'s (which
only fakes signing) — this one needs `upload`/`remove`/`list` on top of
signing, to exercise `profile_service`'s "clean up the old extension"
behavior.
"""

from datetime import UTC, datetime, timedelta

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
        SUPABASE_AVATAR_BUCKET="avatars",
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


class _FakeAvatarBucket:
    def __init__(self) -> None:
        # path -> bytes, standing in for actual Storage objects.
        self.objects: dict[str, bytes] = {}
        self.upload_calls: list[str] = []
        self.removed: list[str] = []
        self.fail_upload = False
        self.fail_remove = False
        self.fail_list = False
        self.fail_signing = False

    def upload(self, path: str, data: bytes, file_options: dict | None = None) -> dict:
        self.upload_calls.append(path)
        if self.fail_upload:
            raise RuntimeError("simulated storage outage")
        self.objects[path] = data
        return {"path": path}

    def remove(self, paths: list[str]) -> None:
        if self.fail_remove:
            raise RuntimeError("simulated storage outage")
        for path in paths:
            self.objects.pop(path, None)
            self.removed.append(path)

    def list(self, path: str) -> list[dict]:
        if self.fail_list:
            raise RuntimeError("simulated storage outage")
        prefix = f"{path}/"
        return [
            {"name": stored_path[len(prefix) :]}
            for stored_path in self.objects
            if stored_path.startswith(prefix)
        ]

    def create_signed_url(self, path: str, expires_in: int) -> dict:
        if self.fail_signing:
            raise RuntimeError("simulated storage outage")
        return {
            "signedURL": f"https://test.supabase.co/storage/v1/{path}?token=fake&exp={expires_in}",
        }


class _FakeStorage:
    def __init__(self, bucket: _FakeAvatarBucket) -> None:
        self._bucket = bucket

    def from_(self, bucket_name: str) -> _FakeAvatarBucket:
        assert bucket_name == "avatars"
        return self._bucket


class _FakeSupabase:
    def __init__(self) -> None:
        self.bucket = _FakeAvatarBucket()
        self.storage = _FakeStorage(self.bucket)


@pytest.fixture
def fake_supabase():
    fake = _FakeSupabase()
    app.dependency_overrides[get_settings] = _test_settings
    app.dependency_overrides[get_supabase_service_client] = lambda: fake
    yield fake
    app.dependency_overrides.pop(get_settings, None)
    app.dependency_overrides.pop(get_supabase_service_client, None)


def _jpeg_file(name: str = "photo.jpg") -> dict:
    return {"image": (name, b"\xff\xd8\xff fake jpeg bytes", "image/jpeg")}


def test_upload_avatar_stores_it_under_the_users_folder(fake_supabase):
    response = client.post(
        "/api/v1/users/me/avatar", headers=_auth_headers(), files=_jpeg_file()
    )

    assert response.status_code == 200
    body = response.json()
    assert body["avatar_path"] == "user-123/avatar.jpg"
    assert body["avatar_url"] == (
        "https://test.supabase.co/storage/v1/user-123/avatar.jpg?token=fake&exp=3600"
    )
    assert fake_supabase.bucket.objects == {"user-123/avatar.jpg": b"\xff\xd8\xff fake jpeg bytes"}


def test_upload_avatar_replacing_the_same_extension_overwrites_in_place(fake_supabase):
    client.post("/api/v1/users/me/avatar", headers=_auth_headers(), files=_jpeg_file())
    response = client.post(
        "/api/v1/users/me/avatar",
        headers=_auth_headers(),
        files={"image": ("new.jpg", b"new bytes", "image/jpeg")},
    )

    assert response.status_code == 200
    assert response.json()["avatar_path"] == "user-123/avatar.jpg"
    assert fake_supabase.bucket.objects == {"user-123/avatar.jpg": b"new bytes"}
    # Only one object ever exists for this user — no leftover to remove.
    assert fake_supabase.bucket.removed == []


def test_upload_avatar_replacing_with_a_different_extension_removes_the_old_object(
    fake_supabase,
):
    client.post("/api/v1/users/me/avatar", headers=_auth_headers(), files=_jpeg_file())
    response = client.post(
        "/api/v1/users/me/avatar",
        headers=_auth_headers(),
        files={"image": ("new.png", b"png bytes", "image/png")},
    )

    assert response.status_code == 200
    assert response.json()["avatar_path"] == "user-123/avatar.png"
    # The old .jpg object is gone; only the new .png remains.
    assert fake_supabase.bucket.objects == {"user-123/avatar.png": b"png bytes"}
    assert fake_supabase.bucket.removed == ["user-123/avatar.jpg"]


def test_upload_avatar_rejects_an_unsupported_content_type(fake_supabase):
    response = client.post(
        "/api/v1/users/me/avatar",
        headers=_auth_headers(),
        files={"image": ("doc.pdf", b"%PDF-1.4", "application/pdf")},
    )

    assert response.status_code == 400
    assert fake_supabase.bucket.objects == {}


def test_upload_avatar_rejects_a_file_over_5mb(fake_supabase):
    oversized = b"a" * (5 * 1024 * 1024 + 1)
    response = client.post(
        "/api/v1/users/me/avatar",
        headers=_auth_headers(),
        files={"image": ("big.jpg", oversized, "image/jpeg")},
    )

    assert response.status_code == 400
    assert fake_supabase.bucket.objects == {}


def test_upload_avatar_rejects_an_empty_file(fake_supabase):
    response = client.post(
        "/api/v1/users/me/avatar",
        headers=_auth_headers(),
        files={"image": ("empty.jpg", b"", "image/jpeg")},
    )

    assert response.status_code == 400


def test_upload_avatar_without_token_is_unauthorized(fake_supabase):
    response = client.post("/api/v1/users/me/avatar", files=_jpeg_file())
    assert response.status_code == 401


def test_upload_avatar_surfaces_a_storage_failure_as_502(fake_supabase):
    fake_supabase.bucket.fail_upload = True
    response = client.post(
        "/api/v1/users/me/avatar", headers=_auth_headers(), files=_jpeg_file()
    )
    assert response.status_code == 502


def test_delete_avatar_removes_the_stored_object(fake_supabase):
    client.post("/api/v1/users/me/avatar", headers=_auth_headers(), files=_jpeg_file())

    response = client.delete("/api/v1/users/me/avatar", headers=_auth_headers())

    assert response.status_code == 204
    assert fake_supabase.bucket.objects == {}
    assert fake_supabase.bucket.removed == ["user-123/avatar.jpg"]


def test_delete_avatar_when_nothing_was_ever_uploaded_is_still_204(fake_supabase):
    response = client.delete("/api/v1/users/me/avatar", headers=_auth_headers())
    assert response.status_code == 204
    assert fake_supabase.bucket.removed == []


def test_delete_avatar_without_token_is_unauthorized(fake_supabase):
    response = client.delete("/api/v1/users/me/avatar")
    assert response.status_code == 401


def test_avatar_upload_and_removal_are_isolated_per_user(fake_supabase):
    client.post(
        "/api/v1/users/me/avatar", headers=_auth_headers(sub="user-123"), files=_jpeg_file()
    )
    client.post(
        "/api/v1/users/me/avatar",
        headers=_auth_headers(sub="user-456"),
        files={"image": ("other.jpg", b"other bytes", "image/jpeg")},
    )

    response = client.delete(
        "/api/v1/users/me/avatar", headers=_auth_headers(sub="user-456")
    )

    assert response.status_code == 204
    # Only user-456's own object was removed — user-123's is untouched.
    assert fake_supabase.bucket.objects == {"user-123/avatar.jpg": b"\xff\xd8\xff fake jpeg bytes"}
