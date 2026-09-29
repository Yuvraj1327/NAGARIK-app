# NAGARIK — Architecture & Setup (Step 1)

## 1. System overview

```
Flutter App (Android + iOS)
      │
      │  HTTPS, JSON, Bearer <supabase-jwt>
      ▼
FastAPI REST API  ──────────────►  AWS (container deployment, Step 10)
      │
      │  service-role client (server-side only)
      ▼
Supabase
 ├── PostgreSQL   (report/user data — schema designed in later steps)
 ├── Auth         (email/password signup, login, session, JWT issuance)
 └── Storage      (report images)
```

Frontend, backend, auth, database, and storage are kept as separate
concerns, communicating only over well-defined interfaces (HTTP for
Flutter↔FastAPI, the Supabase SDK for FastAPI↔Supabase and for
Flutter↔Supabase Auth specifically).

## 2. Auth & data-access flow (the decision that spans multiple steps)

This is the one decision that needed settling before any other step could
build on it safely, since it determines how every future endpoint and
screen talks to the rest of the system.

**Decision:** Supabase Auth is used directly by Flutter for
signup/login/session/logout. Every other operation — reading or writing
reports, profiles, images — goes through FastAPI, never directly from
Flutter to Postgres or Storage.

1. Flutter uses the `supabase_flutter` SDK to sign up / log in against
   Supabase Auth. This gets Flutter secure token storage, automatic session
   refresh, and password-reset flows for free, instead of reimplementing
   them against a custom backend endpoint.
2. Supabase Auth returns a JWT (`access_token`) tied to a Supabase user.
3. Flutter's `ApiClient` (`mobile/lib/core/network/api_client.dart`)
   attaches that JWT as `Authorization: Bearer <token>` on every request to
   FastAPI.
4. FastAPI verifies the JWT itself — locally, against `SUPABASE_JWT_SECRET`
   (`backend/app/core/security.py`) — rather than calling back to Supabase
   to check it. This is fast and has no extra network hop per request.
5. Once the caller's identity is established, FastAPI uses the Supabase
   **service role** client (`backend/app/integrations/supabase_client.py`)
   to perform the actual Postgres/Storage operations, applying whatever
   business rules and validation the feature needs.

**Why not let Flutter talk to Postgres/Storage directly via Supabase's own
client-side RLS policies (a common, simpler Supabase pattern)?** Because
the agreed architecture diagram is explicitly `Flutter → FastAPI →
Supabase`, and centralizing data access in FastAPI keeps business logic
(validation, status transitions, search/filter query construction) in one
place instead of split between Postgres RLS policies and API code. The
trade-off is that FastAPI must re-verify the JWT on every request, which
`core/security.py` already does.

This flow is scaffolded but not yet active: `get_current_user` isn't
attached to any route yet, and Flutter's Supabase init only sets up the
client. Both are wired to real screens/endpoints starting Step 3.

## 3. Backend architecture (FastAPI)

```
backend/app/
├── main.py            # app factory: CORS, router registration
├── core/
│   ├── config.py      # Settings — all config from environment variables
│   ├── logging.py
│   └── security.py    # Supabase JWT verification (Step 3)
├── api/
│   ├── deps.py        # re-exports shared dependencies for endpoint modules
│   └── v1/
│       ├── api.py     # aggregates one router per resource
│       └── endpoints/ # health (implemented), auth/users/reports (empty until their step)
├── integrations/
│   └── supabase_client.py   # service-role client + anon client, both cached singletons
├── models/            # backend-side domain models, added as needed
├── schemas/           # Pydantic request/response schemas, one module per resource
└── services/          # business logic, called from endpoints — keeps routes thin
```

**Why this layout:** routes stay thin (parse request → call a service →
return response), business logic lives in `services/` where it's testable
without spinning up HTTP, and `integrations/` is the only place that
imports the Supabase SDK — nothing else touches it directly. Versioning
(`api/v1/`) is in place from day one so a `v2` can be added later without
breaking existing clients.

Only `/api/v1/health` and `/api/v1/health/ready` are implemented in Step
1. They exist to prove the Flutter↔FastAPI communication path works before
any real feature is built on it. `auth`, `users`, and `reports` routers are
registered (so the URL structure is locked in) but intentionally empty.

## 4. Mobile architecture (Flutter)

```
mobile/lib/
├── main.dart          # loads env, initializes Supabase, runs the app
├── app.dart           # MaterialApp.router root widget
├── core/
│   ├── config/        # typed .env access
│   ├── constants/      # API path constants
│   ├── network/        # ApiClient (Dio, -> FastAPI), Supabase Auth init
│   ├── routing/        # go_router config
│   ├── theme/          # empty — Step 2
│   └── utils/          # empty
├── features/
│   ├── auth/           # Step 3
│   ├── profile/        # Step 4
│   ├── reports/        # Step 5, 6, 8
│   └── discovery/       # Step 7, 8
│       each: data/ (repositories) · domain/ (entities, repo interfaces) · presentation/ (screens, widgets, state)
└── shared/
    └── widgets/         # common widgets, loading/error/empty states — Step 2
```

**Why feature-first + data/domain/presentation:** each of the roadmap's
remaining steps (3-8) maps to exactly one feature folder, so work stays
isolated — building Reports in Step 5 doesn't risk touching Auth code from
Step 3. Within a feature, `domain/` has no Flutter or Dio imports (pure
Dart), `data/` implements the domain's repository interfaces against
`ApiClient`, and `presentation/` is the only layer that imports Flutter
widgets and Riverpod state — a standard separation that keeps business
rules testable independent of the UI.

**Dependency choices** (locked in now so later steps don't reshuffle them):

| Concern | Choice | Why |
|---|---|---|
| State management | `flutter_riverpod` | Compile-safe DI + state, testable without `BuildContext` |
| Navigation | `go_router` | Declarative routes, deep-linking-ready, official Flutter team package |
| HTTP client | `dio` | Interceptors (used to attach the Supabase JWT automatically), timeouts, typed errors |
| Auth | `supabase_flutter` | Official SDK — secure token storage & refresh handled for us |
| Env config | `flutter_dotenv` | Simple `.env` loading; no code generation step required |

Feature-specific packages (`image_picker`, `geolocator`, `cached_network_image`,
etc.) are intentionally **not** added yet — they're pulled in by the step
that first needs them, so the dependency list always reflects what's
actually used.

## 5. Environment configuration

Both apps read all configuration from environment variables — nothing is
hardcoded, so the same code runs locally, in CI, and in production with
only the environment differing.

- `backend/.env.example` → copy to `backend/.env`. Holds `SUPABASE_URL`,
  the **anon** key, the **service role** key (backend-only secret), the
  **JWT secret** (used to verify tokens issued by Supabase Auth), and CORS
  origins.
- `mobile/.env.example` → copy to `mobile/.env`. Holds `SUPABASE_URL`, the
  **anon** key only (safe to bundle into a mobile build — protected by
  Supabase Row Level Security, not secrecy), and `API_BASE_URL` pointing at
  the FastAPI backend.

Neither `.env` file is committed (see root `.gitignore`); only the
`.example` files are.

## 6. Deployment posture (AWS-ready, not yet deployed)

`backend/Dockerfile` builds a slim, non-root production image running
`uvicorn` on port 8000 — deployable as-is to AWS ECS/Fargate, App Runner,
or Elastic Beanstalk's Docker platform. Actual provisioning, task
definitions, CI/CD, and secrets management are Step 10 work; Step 1 only
ensures the artifact that gets deployed is already production-shaped.

## 7. What's explicitly deferred

Per the agreed scope, these are not touched in Step 1 (or any step) unless
explicitly requested later: push notifications, an admin dashboard,
multi-language support, in-app chat, analytics.

## 8. Verified in Step 1

- `backend`: dependencies install cleanly; `ruff check .` passes; `pytest`
  passes (2 tests); the app boots with `uvicorn` and `/api/v1/health` and
  `/api/v1/health/ready` were hit live and returned correct responses.
- `mobile`: hand-verified for structural/syntax correctness. The Flutter
  SDK is not available in this environment (this sandbox's network
  allowlist doesn't reach `pub.dev` or Flutter's build-artifact storage —
  confirmed, not assumed), so `flutter pub get`, `flutter create .`
  (needed to generate the native `android/` and `ios/` platform folders),
  `flutter analyze`, and `flutter test` have **not** been run yet. Doing
  so is the very first thing to do wherever this project is opened next
  (a developer machine or CI with Flutter installed) — see "What's ready
  for Step 2" in the Step 1 handoff notes.

## 9. Step 3 & 4 additions

**Protected routes.** `go_router`'s `redirect` (in `app_router.dart`) is
driven by a `GoRouterRefreshStream` wrapping Supabase's
`onAuthStateChange` (`core/routing/go_router_refresh_stream.dart`) — the
standard go_router recipe for making `redirect` re-run on external state
changes, not just on navigation. `/report/create` requires a signed-in
user (Step 5 links every report to its author); `/login`/`/signup` bounce
a signed-in user back to `/home`. Because `redirect` re-runs on every auth
change, a successful sign-in on the login screen needs no manual
navigation — the redirect takes the user to `/home` on its own the moment
the auth stream emits. One accepted simplification: after being bounced
to `/login` from `/report/create`, a successful login lands on `/home`,
not back on `/report/create` — deep-linking back to the original
destination wasn't in the approved scope for this step.

**`GET /users/me` reads the JWT, not the database.** Supabase Auth already
puts `email` and `user_metadata` (set via `signUp(data: {...})`) in the
access token it issues. The backend decodes and verifies that token
(`core/security.py`, from Step 1) and returns those claims directly — no
`profiles` table, no extra Supabase call. This is why signup collects
"Full name" and passes it as `data: {'full_name': ...}` to Supabase's
`signUp()`: it ends up in the token, which is all `GET /users/me` needs.

**Report history is honestly empty.** Step 4's "user's submitted reports"
can't be real yet — the `reports` table and creation flow don't exist
until Step 5. The profile screen's signed-in view shows an explicit empty
state for this rather than a fake list or a broken endpoint; it becomes
real once Step 5 (create) and Step 7 (fetch) exist.

**Signup handles both of Supabase's signup outcomes.** If the Supabase
project requires email confirmation (the default), `signUp()` returns no
session yet — the UI tells the user to check their email. If confirmation
is disabled, a session comes back immediately and the same redirect logic
above takes over. Both paths are handled; which one fires depends on the
Auth setting in your Supabase project dashboard.

## 10. Step 5 & 6 additions

**Schema arrives now, not in Step 1.** `backend/migrations/0001_reports.sql`
and `0002_report_images_bucket.sql` are the first real Supabase schema —
deliberately not created earlier, since Step 1 was architecture-only and
inventing a schema before the fields were confirmed would have violated
"do not invent unnecessary fields." **You need to run both files yourself**
in your Supabase project's SQL editor before report creation will work —
this backend only holds your service-role key at runtime, not a channel
for it to run unreviewed DDL against your project.

**Images upload through the backend, not straight from Flutter to
Storage.** This follows the Step 1 decision directly: Flutter never talks
to Postgres or Storage on its own. `POST /reports` is `multipart/form-data`
(fields + image files together); the backend validates each image
(type/size), uploads it to Storage as `<user_id>/<uuid>.<ext>` using the
service-role client, and only then inserts the report row with the
resulting paths. If either an upload or the insert fails partway through,
already-uploaded images for that attempt are removed
(`reports_service.py::_cleanup`) so a partial failure doesn't leave
orphaned files in Storage with no report pointing at them.

**The Storage bucket is private.** Objects aren't readable by a bare URL.
Signed-URL generation for displaying images is added when Step 7 builds
report retrieval — Step 6 only needed upload to work, and defaulting to
private is the safer choice until there's a reason to do otherwise.

**Wire format for category/status matches Flutter's enums exactly.**
`app/schemas/report.py`'s `ReportCategory`/`ReportStatus` use the identical
member names as `mobile/lib/core/constants/report_category.dart` /
`report_status.dart` (e.g. `streetlight`, `in_review`), so
`ReportCategory.values.byName(json['category'])` on the Flutter side needs
no translation table and can't silently drift out of sync.

**Location is optional, city/PIN are not.** "Precise location" (GPS
coordinates) and "city/PIN code" are different fields per the original
scope — a user can decline location permission (or be on a device where it
fails) and still submit a valid report with just city/PIN, matching Step
6's explicit requirement to handle denied/unavailable location gracefully
rather than blocking submission on it.

**Native platform permissions still need to be added manually.** This
project has no `android/`/`ios/` folders yet (the Flutter SDK isn't
available in the environment these steps were built in, so `flutter
create .` has never been run — see Step 1/2's verified-state notes).
`geolocator` and `image_picker` both need permission strings declared in
the native project once those folders exist. See `mobile/README.md`'s
"Native permissions" section for the exact manifest/plist entries — this
is a required manual step, not optional polish; without it, location and
camera/gallery access will fail or crash on-device even though the Dart
code is correct.

## 11. Step 7 & 8 additions

**Report browsing is public; "mine" is the one thing that isn't.**
`GET /reports` and `GET /reports/{id}` need no bearer token — anyone can
browse and search reports, matching the app's civic-transparency intent
and the `reports` table's "public select" RLS policy (Step 5's
defense-in-depth, now actually exercised). The one exception is
`?mine=true`, which needs to know who's asking; `get_optional_current_user`
(new in `app/core/security.py`) returns `None` for an anonymous caller
instead of raising, so the same endpoint serves both cases — a *present but
invalid* token still raises 401, since that means the caller thinks they're
signed in and got it wrong.

**Signed URLs are generated fresh on every response, never stored.** The
Storage bucket stayed private in Step 6 on purpose. Every `ReportResponse`
now carries both `image_paths` (the raw Storage paths — not directly
fetchable) and `image_urls` (Storage's `create_signed_urls`, batched across
every image on the page in one call, valid for
`REPORT_IMAGE_SIGNED_URL_TTL_SECONDS`). Signing failures degrade
gracefully — a broken thumbnail shouldn't take down report browsing — by
simply omitting that path's URL rather than 500ing the whole request.

**"Nearby" is computed in Python, not PostGIS.** Setting up the PostGIS or
`earthdistance` extension was out of scope to require for this project, so
`GET /reports?latitude=&longitude=` filters/sorts by the haversine distance
in `reports_service.list_reports` instead of a spatial DB query. That means
a nearby search scans up to `NEARBY_SCAN_LIMIT` (300) of the most recent
rows matching the other filters, rather than the whole table. Fine at
city-scale; called out here as the deliberate trade-off it is, with
enabling `earthdistance` + a proper `<->` query as the natural next step if
the reports table ever grows large enough for that scan to matter.

**Search is a simple `ilike` OR across two columns, not full-text search.**
`?search=` matches against `description` or `city` with a case-insensitive
substring match (Postgres `or_("description.ilike.%x%,city.ilike.%x%")`),
not Postgres full-text search (`tsvector`/`tsquery`) — proportionate to a
civic-reports table's likely size and avoids a schema migration (a
`tsvector` column + GIN index) that wasn't asked for.

**Pagination is offset-based, not cursor-based.** `GET /reports` returns
`{items, total, limit, offset}`; `total` comes from Postgres's
`count="exact"` on the filtered query (or the post-distance-filter count
for a nearby search). Simple and sufficient for a feed/search UI with a
bounded result set; cursor pagination wasn't needed at this scale and would
have added complexity with no user-facing benefit yet.

**The Search tab, not the Home tab, owns filters.** Per the original Step 2
UI split, Home stays a simple, unfiltered "most recent reports" feed;
category/status/city/PIN/nearby/keyword filtering all live in Search,
matching the discovery requirements from the project brief without
duplicating filter UI across two tabs.

## 12. Step 9 additions (Backend, API Integration & Testing)

By Step 8 every feature was already wired to real integrations — this step
is deliberately not new features, but closing the gap between "works" and
"holds up": broader test coverage, input hardening, and a couple of latent
issues that only surface under adversarial or misconfigured conditions.

**Text fields had no upper bound.** `description` and `city` on
`POST /reports` had a minimum length but no maximum — a client could send
an arbitrarily large string through either field. Both now have a
`max_length` (2000 and 100 respectively), enforced the same way the
existing `pin_code` pattern already is (a FastAPI `Form(...)` constraint,
so it 422s before any business logic runs). The Flutter side mirrors both
as `maxLength` on the corresponding fields — `AppTextField` gained a
`maxLength` passthrough for this — so the user is stopped by the keyboard
itself rather than by a rejected submission.

**Uncaught exceptions no longer produce a raw traceback.** `app/main.py`
now registers an `@app.exception_handler(Exception)` catch-all: FastAPI
already turns `HTTPException` and validation errors into clean JSON on its
own (Starlette dispatches to the most specific registered handler for the
exception's type, so this catch-all is never consulted for those), but
anything genuinely unexpected — a bug, a downstream outage — previously
propagated as a raw 500 with no consistent shape. It's now logged
server-side via `logger.exception(...)` and returned to the client as
`{"detail": "Internal server error."}`. Testing this needed
`TestClient(app, raise_server_exceptions=False)` — the test client's
default re-raises an exception that reached this handler even though a
response was already produced, specifically so bugs aren't hidden during
testing; a real deployed server has no such re-raise step.

**A narrow, documented edge case: a malformed query param can still 500
instead of 422, but only when Supabase is also unconfigured.** FastAPI
resolves query-parameter validation and dependency calls (like
`get_supabase_service_client`) in the same pass. If Supabase credentials
are missing, that dependency raises before FastAPI finishes collecting
parameter-validation errors to report as a 422 — so in that specific
double-fault state (bad input *and* a broken deployment), the client sees
a 500 instead of the more helpful 422. Once Supabase is actually
configured (any real deployment), this dependency never raises and
ordinary validation errors come through normally as 422 — confirmed by
`tests/test_error_handling.py`, which pins valid dummy settings precisely
to test the 422 path in isolation from this. Not worth restructuring
dependency resolution to fix a case that can't occur once `.env` is filled
in; noted here so it isn't mistaken for something worse later.

**Readiness now has deterministic tests for both states.** `GET
/health/ready` already reported `supabase_configured`; Step 9 adds tests
that override `get_settings` to assert the exact "ok" and "degraded"
response bodies, rather than only checking the key's presence.

**Client-side hardening on the Flutter side is presentational, not a
security boundary.** `maxLength` on a text field stops a well-behaved
keyboard from typing further — it does nothing against a client that
skips the app and calls the API directly, which is exactly why the same
limits are enforced server-side first. The Flutter-side limits exist purely
so a real user finds out they've hit a limit before submitting, not after.

**New test coverage:** `tests/test_error_handling.py` (unhandled-exception
handling, confirming HTTPException/validation responses are untouched by
it), plus new cases in `tests/test_reports.py` (description/city
over-length rejection) and `tests/test_health.py` (deterministic
ready/degraded assertions). On the Flutter side, `test/report_parsing_test.dart`
covers `Report.fromJson`/`ReportsPage.fromJson`/`Report.statusToWire` as
pure-Dart logic (no widget pump needed), and `test/report_card_test.dart`
covers the `ReportCard`/`StatusBadge` widgets shared across the feed,
search results, profile history, and the create-report review step.

## 13. Step 10 additions (Production Deployment & Handover)

**Nothing was actually deployed.** Per this project's standing rule, Step
10 produces preparation artifacts only — templates, CI/CD workflow
definitions, and documentation — so the project owner can deploy manually
whenever they choose. No AWS CLI command was run against a real account,
no image was pushed to a real registry, and no App Runner/ECS resource
was created from this session.

**App Runner chosen as the recommended default, ECS/Fargate offered as an
alternative.** This is an implementation-detail choice within the
already-approved "prepare for deployment" scope, not a new architectural
decision needing separate sign-off. App Runner needs no VPC, load
balancer, or cluster for a single backend service — it takes a container
image and handles routing, TLS, and scaling itself. ECS/Fargate
(`infra/aws/ecs-task-definition.json`) is documented as the alternative
for teams that already run ECS with a VPC/ALB they control, or need
per-task customization App Runner doesn't offer. Both consume the same
ECR image and the same four Secrets Manager entries.

**The `_comment` key was removed from both JSON templates.** An earlier
draft embedded an explanatory `_comment` string as a top-level JSON key so
the template would be self-documenting. That's unsafe: `aws apprunner
create-service --cli-input-json` and `aws ecs register-task-definition
--cli-input-json` validate the input strictly against the operation's
shape and reject unrecognized top-level keys, which would make the
template fail exactly when run as-is. The explanation now lives entirely
in `infra/aws/README.md`, and the JSON files contain only fields AWS
actually accepts. Both were re-validated with `python -m json.tool` after
the change.

**Deploys are manual by design, not merely by default.** `backend-deploy.yml`
is the only workflow capable of touching AWS, and it triggers exclusively
on `workflow_dispatch` with a typed confirmation input — never on push,
merge, or a schedule. `backend-ci.yml` and `mobile-ci.yml` run
automatically but do nothing beyond linting, testing, and (for the
backend) a local Docker build sanity check; neither can reach AWS or push
an image anywhere. This mirrors the same "a human decides" pattern used
for every other step of this project.

**GitHub OIDC over long-lived access keys.** `backend-deploy.yml` assumes
an IAM role via `aws-actions/configure-aws-credentials`'s `role-to-assume`
rather than reading static `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`
secrets. A role scoped to trust only this repository, with credentials
minted fresh per run, doesn't leave a long-lived key sitting in GitHub
secrets as a standing target — a real (if smaller) reduction in blast
radius, at the cost of one extra one-time setup step the README covers.
A plain access-key pair is documented as a drop-in fallback if preferred.

**Secrets management mirrors the "real secret vs. plain config" split
already used in `backend/app/core/config.py`.** Only the four Supabase
values that grant real access (`SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`) go through AWS Secrets
Manager, referenced by ARN (`RuntimeEnvironmentSecrets` for App Runner,
`secrets` for ECS) so they're fetched at container start rather than
baked into the image or shown in a console's plain env-var list.
Everything else (`APP_NAME`, `ENVIRONMENT`, CORS origins, the bucket name,
the signed-URL TTL) stays a plain runtime environment variable, since none
of it grants access to anything on its own. `backend/.env.production.example`
documents the full shape without carrying real values, and is explicitly
not a file the app loads directly — only `backend/app/core/config.py`'s
local-dev `.env` loading path (unchanged from earlier steps) touches disk;
production values are injected by App Runner/ECS as real runtime env vars
and secrets.

**Verification performed on the Step 10 artifacts themselves:** both JSON
templates parsed cleanly with `python -m json.tool`; all three GitHub
Actions workflow files parsed cleanly with `yaml.safe_load`; the full
backend test suite (36 tests) and `ruff check` were re-run against a fresh
virtualenv and both pass, confirming Step 9's hardening work is undisturbed
by Step 10's additions (which touched only `infra/`, `.github/`, and
documentation — no application code).
