# NAGARIK API (FastAPI backend)

## Local setup

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt

cp .env.example .env
# then edit .env with your Supabase project's URL/keys

uvicorn app.main:app --reload
```

The API is now at `http://localhost:8000`, interactive docs at
`http://localhost:8000/docs`.

## Database migrations

The `reports` feature needs three SQL migrations applied to your Supabase
project before `/api/v1/reports` will work — **skipping the first two is
the #1 cause of a `PGRST205: Could not find the table 'public.reports' in
the schema cache` error.** This project does not run migrations
automatically — apply them yourself, once, in the Supabase dashboard's
**SQL Editor**. See [`migrations/README.md`](migrations/README.md) for the
full walkthrough, including how to fix `PGRST205` specifically if it shows
up after you've already run them (usually a stale PostgREST schema cache
or a `.env` pointed at the wrong Supabase project).

The third migration, `0003_report_reference_id.sql` (My Reports & Report
Tracking upgrade), adds every report's human-readable reference id (e.g.
`NGR-2026-00001`) — **required** for the API to work at all once this
step's code is deployed, since `ReportResponse` now requires
`reference_id` on every report.

The fourth migration, `0004_saved_reports.sql` (Report Sharing, Saved
Reports & Final Feature Polish upgrade), adds the `saved_reports` table
that backs bookmarking a report — **required** before `POST`/`DELETE
/api/v1/reports/{id}/save` and `GET /api/v1/reports/saved` will work
(without it, those three calls fail with the same `PGRST205`-style 503
every other missing-table case does).

The fifth migration, `0005_avatars_bucket.sql` (Official Logo & User
Profile Photo upgrade), adds a private `avatars` Storage bucket + RLS —
**required** before `POST`/`DELETE /api/v1/users/me/avatar` will work
(without it, both calls fail the same way every other missing-bucket case
does: a 502 from the Storage call itself, since a missing *bucket* isn't a
PostgREST schema-cache error like a missing table).

There is no `profiles`/`users` table to migrate — `GET /api/v1/users/me`
reads directly from the verified Supabase Auth JWT (see
`migrations/README.md` for why). A profile photo doesn't change that: only
its *bytes* live in Storage, the *reference* to it is one more key in the
same JWT `user_metadata` `full_name` already lives in (see
`docs/ARCHITECTURE.md` section 19).

## CORS (Flutter web dev)

`BACKEND_CORS_ORIGINS` in `.env` is a comma-separated allowlist for a
**deployed** web origin, if you ever have one. You don't need to set it
just to run `flutter run -d chrome` (or `-d web-server`) locally: outside
`ENVIRONMENT=production`, the API also accepts any
`http://localhost:<port>` / `http://127.0.0.1:<port>` origin automatically
(`app/core/config.py`'s `cors_local_dev_origin_regex`), since Flutter's web
dev server picks an unpredictable port each run. This applies to every
request method, including the `OPTIONS` preflight a browser sends before
its real request — previously CORS middleware was only registered `if
settings.cors_origins` was non-empty, so with no origins configured (the
documented default for local dev) there was no CORS middleware at all and
every preflight got a plain `405`; it's now always registered.

Android/iOS builds don't send an `Origin` header at all, so none of this
affects them either way.

## API surface (Step 5-8)

- `POST /api/v1/reports` — submit a report (auth required).
- `GET /api/v1/reports/{id}` — a single report's full detail, with freshly
  signed image URLs (public, no auth required).
- `GET /api/v1/reports` — browse/search/filter reports (public). Query
  params: `category`, `status`, `city` (partial, case-insensitive), `search`
  (matches description or city), `pin_code` (exact), `mine` (auth required
  when `true` — the caller's own reports), `latitude` + `longitude` (both
  required together, switches to nearest-first within `radius_km`, default
  5km), `limit` (default 20, max 50), `offset`.
- `GET /api/v1/reports/markers` — lean pin data for the mobile app's map
  view (public, no auth required). Same filters as `GET /api/v1/reports`
  (`category`, `status`, `city`, `pin_code`, `search`, `latitude` +
  `longitude` + `radius_km`), but each item returns only
  `id`, `reference_id`, `category`, `status`, `city`, `latitude`,
  `longitude` — no `description`, no images, no signed URLs — since a map
  may render dozens of pins and only needs enough to plot and identify each
  one. A tapped marker's full detail is fetched separately via the existing
  `GET /api/v1/reports/{id}`. Registered ahead of `GET /{id}` in the router
  so the literal `/markers` path isn't shadowed by the `/{report_id}` catch-all
  (see `docs/ARCHITECTURE.md` for the general pattern).

- `GET /api/v1/reports/saved` — the caller's bookmarked reports (auth
  required), newest save first. Same `ReportListResponse` shape/pagination
  (`limit`, `offset`) as `GET /api/v1/reports`, so it reuses the exact same
  report card on the mobile side. Registered ahead of `GET /{id}` for the
  same route-shadowing reason as `/stats`/`/markers`.
- `POST /api/v1/reports/{id}/save` — bookmark a report (auth required).
  Returns `201` with `{"report_id": ..., "saved": true}`. Idempotent:
  saving an already-saved report still returns `201`/`saved: true` rather
  than erroring (duplicate saves are prevented by the `saved_reports`
  table's own `unique (user_id, report_id)` constraint, not an
  application-level check). `404` if the report doesn't exist.
- `DELETE /api/v1/reports/{id}/save` — remove a bookmark (auth required).
  Returns `204`. Idempotent: unsaving a report that was never saved (or
  already removed) is still `204`, not `404`.

Every `ReportResponse` also carries `is_saved` — whether the *caller*
(not just anyone) has bookmarked that report. It's only computed for real
on `GET /api/v1/reports/{id}` (auth is optional there, so it's `false` for
signed-out visitors); plain browse/search/`markers` lists always return
`false` for it (an extra per-row lookup nothing in a list card currently
shows); `GET /api/v1/reports/saved` always returns `true` for it, since
every row there is one of the caller's own saves by definition.

Every response signs its own `image_urls` against the private Storage
bucket at request time (`REPORT_IMAGE_SIGNED_URL_TTL_SECONDS` in `.env`
controls how long they stay valid) — `image_paths` alone isn't fetchable by
a client.

`description` (max 2000 chars) and `city` (max 100 chars) on `POST
/reports` are length-capped (Step 9) — previously only a minimum length was
enforced. Any uncaught, unexpected error anywhere in the API comes back as
a clean `{"detail": "Internal server error."}` (500) instead of a raw
traceback, via the catch-all handler in `app/main.py`; it never affects
ordinary `HTTPException`/validation responses, which keep their own
specific status codes and messages.

## Users API

- `GET /api/v1/users/me` — the signed-in caller's profile (auth required):
  `id`, `email`, `full_name`, and (Official Logo & User Profile Photo
  upgrade) `avatar_url` — a freshly signed URL for their photo, or `null`
  if they haven't set one. Reads straight from the verified JWT's claims,
  no database round trip, except the one real Storage call this upgrade
  added: signing `avatar_path` (from `user_metadata`) into `avatar_url`
  when it's set.
- `POST /api/v1/users/me/avatar` — upload or replace the caller's profile
  photo (auth required, multipart `image` field). Accepts JPEG/PNG/WebP up
  to 5 MB. Returns `200` with `{"avatar_path": ..., "avatar_url": ...}`.
  Replacing an existing photo overwrites it in place (or, if the new
  upload has a different file extension than the old one, uploads the new
  file and then removes the old one) — a user has exactly one profile
  photo, never an accumulating list.
- `DELETE /api/v1/users/me/avatar` — remove the caller's profile photo
  (auth required). Returns `204`. Idempotent: removing when nothing was
  ever uploaded is still `204`, not `404`.

Both avatar endpoints only touch Storage — neither can update
`user_metadata` itself (that needs the user's own Supabase session, which
the backend never holds). The Flutter client is responsible for calling
`AuthRepository.updateAvatarPath` with the returned `avatar_path` right
after either call succeeds; see `docs/ARCHITECTURE.md` section 19.

## Verify it's alive

```bash
curl http://localhost:8000/api/v1/health
curl http://localhost:8000/api/v1/health/ready
```

## Run tests

```bash
pytest
```

## Lint

```bash
ruff check .
```

## Project layout

```
app/
├── main.py              # app factory: middleware + router registration
├── core/
│   ├── config.py        # env-driven Settings (pydantic-settings)
│   ├── logging.py       # logging setup
│   └── security.py      # Supabase JWT verification + CurrentUser (Step 3/4)
├── api/
│   ├── deps.py          # shared FastAPI dependencies
│   └── v1/
│       ├── api.py       # aggregates all v1 routers
│       └── endpoints/   # one module per resource (health, auth, users, reports)
├── integrations/
│   └── supabase_client.py   # Supabase service-role + anon clients
├── models/               # backend-side domain models (added as needed)
├── schemas/              # Pydantic request/response schemas (per resource)
└── services/
    ├── reports_service.py    # creation (Step 5/6), single/browse retrieval, search, nearby, signed URLs (Step 7/8), lean markers (Location Discovery & Home upgrade)
    └── profile_service.py    # avatar upload/delete/signing against the avatars Storage bucket (Official Logo & User Profile Photo upgrade)

tests/
├── test_health.py          # liveness/readiness, incl. deterministic ok/degraded cases (Step 9)
├── test_users.py           # JWT verification via GET /users/me, incl. signed avatar_url (Official Logo & User Profile Photo upgrade)
├── test_reports.py         # creation, retrieval, search/filter/pagination, length limits, stats, reference ids, markers
├── test_saved_reports.py   # save/unsave, duplicate-prevention, per-user isolation, GET /reports/saved, is_saved (Report Sharing, Saved Reports & Final Feature Polish upgrade)
├── test_profile_avatar.py  # upload/replace/remove, validation, per-user isolation (Official Logo & User Profile Photo upgrade)
└── test_error_handling.py  # the app-wide unhandled-exception handler (Step 9)

migrations/
├── 0001_reports.sql               # reports table, indexes, RLS (Step 5)
├── 0002_report_images_bucket.sql  # private Storage bucket + RLS (Step 6)
├── 0003_report_reference_id.sql   # reference_id column, per-year counter, trigger (My Reports & Report Tracking upgrade)
├── 0004_saved_reports.sql         # saved_reports table + RLS (Report Sharing, Saved Reports & Final Feature Polish upgrade)
└── 0005_avatars_bucket.sql        # avatars Storage bucket + RLS (Official Logo & User Profile Photo upgrade)
```

## Deployment

A production `Dockerfile` is included and builds a non-root, slim image
that runs `uvicorn` on port 8000. Step 10 adds the deployment-preparation
artifacts (nothing has actually been deployed — see the note in
`infra/aws/README.md`):

- **`infra/aws/apprunner-service.json`** — `create-service` input template
  for AWS App Runner, the recommended target for this single-service
  backend.
- **`infra/aws/ecs-task-definition.json`** — an ECS/Fargate task
  definition, provided as an alternative for teams already running ECS.
- **`backend/.env.production.example`** — documents the production
  configuration shape (not a file the app loads directly).
- **`.github/workflows/backend-ci.yml`** — runs `ruff`, `pytest`, and a
  Docker build check automatically on every push/PR touching `backend/`.
- **`.github/workflows/backend-deploy.yml`** — builds, pushes to ECR, and
  redeploys App Runner. Manual only (`workflow_dispatch`); never runs
  automatically.

See [`infra/aws/README.md`](../infra/aws/README.md) for the full
one-time AWS setup walkthrough, the required GitHub Actions secrets, and
the secrets-management approach.
