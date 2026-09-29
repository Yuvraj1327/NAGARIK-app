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

The `reports` feature (Step 5/6) needs two SQL migrations applied to your
Supabase project before you can submit a report. This project does not run
migrations automatically — apply them yourself, once, in the Supabase
dashboard's **SQL Editor**, in order:

1. `migrations/0001_reports.sql` — creates the `reports` table (columns,
   check constraints, indexes, `updated_at` trigger, and RLS policies).
2. `migrations/0002_report_images_bucket.sql` — creates the private
   `report-images` Storage bucket and its per-user-folder RLS policies.

Paste each file's contents into the SQL Editor and run it. Re-running them
is not idempotent (they use `create table`/`insert into storage.buckets`),
so only run each one once per project.

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
    └── reports_service.py   # creation (Step 5/6), single/browse retrieval, search, nearby, signed URLs (Step 7/8)

tests/
├── test_health.py          # liveness/readiness, incl. deterministic ok/degraded cases (Step 9)
├── test_users.py           # JWT verification via GET /users/me
├── test_reports.py         # creation, retrieval, search/filter/pagination, length limits (Step 9)
└── test_error_handling.py  # the app-wide unhandled-exception handler (Step 9)

migrations/
├── 0001_reports.sql              # reports table, indexes, RLS (Step 5)
└── 0002_report_images_bucket.sql # private Storage bucket + RLS (Step 6)
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
