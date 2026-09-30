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

## 14. Post-Step-10 fixes: hard auth gate, Supabase schema errors, and CORS

Three issues reported after Step 10 (an unauthenticated app shell, a
Supabase `PGRST205` error on `/api/v1/reports`, and browser preflight
requests returning `405`) turned out to be three independent problems, not
one — each is described here with what was actually wrong and why the fix
is what it is.

**1. Auth gate (`mobile/lib/core/routing/app_router.dart`).** Since Step 3,
only `/report/create` bounced a signed-out user to `/login`; Home, Search,
and Profile were always reachable (Profile branched on auth state
internally rather than being gated by the router). This is a deliberate
change in direction, not a bug fix: the router's `redirect` callback now
gates *every* route except `/login`/`/signup` themselves —
`if (!isLoggedIn && !isGoingToAuth) return '/login';` — so the app opens
straight to Login/Signup and nothing else is reachable without a session.
Signing in (or up) continues straight on to `/home` automatically, the
same as before, via the existing `refreshListenable`/`GoRouterRefreshStream`
wiring off Supabase's own auth-state stream — no new navigation code
needed for that direction, and none needed for sign-out either: signing
out fires the same stream, and the very next redirect check finds
`isLoggedIn == false` on a non-auth route and sends the user back to
`/login` from wherever they were.

This does **not** change what the backend API itself requires — `GET
/api/v1/reports` and `GET /api/v1/reports/{id}` are still optional-auth at
the HTTP layer (see the updated docstring in
`app/api/v1/endpoints/reports.py`). The distinction is deliberate: the
*app's* screens are now fully gated, but the *API* stays open for a
possible future non-app client (a public read-only website, an open-data
export) without needing to touch backend auth to get there — today, in
practice, every call to those endpoints comes from an already-signed-in
app session anyway, since there's no way to reach the screens that call
them without one.

**2. `PGRST205: Could not find the table 'public.reports' in the schema
cache'`.** This is Supabase/PostgREST's error for "this table doesn't
exist in what I have cached" — inspecting `backend/migrations/0001_reports.sql`
and `0002_report_images_bucket.sql` found nothing wrong with the SQL
itself (both were already correct and already idempotent, contrary to
what `backend/README.md` used to claim — that claim is now fixed too).
The actual problem is operational, not a code bug: **this backend has no
way to run DDL against your Supabase project on its own** (documented in
the migration files' own header comments since Step 5) — it only holds
your service-role key at runtime for ordinary queries. If the SQL in
`backend/migrations/` was never pasted into the Supabase SQL Editor and
run (or was run against a different project than the one `SUPABASE_URL`
now points at, or ran but the PostgREST schema cache hasn't reloaded
since), every reports query fails with exactly this error. New
`backend/migrations/README.md` walks through applying both files and
specifically troubleshooting `PGRST205` (checking Table Editor, forcing a
schema-cache reload, checking for a mismatched project URL).

Since this class of error is also easy to run into again in normal
operation (a fresh Supabase project the migrations haven't been applied to
yet, or a stale cache right after applying them), `reports_service.py`
now catches it specifically: `_raise_for_supabase_error` inspects the
Supabase/PostgREST exception's `.code` for `PGRST205`/`PGRST204`/`PGRST202`
(table/column/function not found in schema cache) or `42P01` (Postgres'
own "undefined_table"), and returns a `503` naming the real cause and
pointing at the migrations, instead of the generic "failed, try again"
`502`/`500` a retry can't actually fix. Covered by six new tests in
`tests/test_reports.py` (insert, single-fetch, plain browse, and the
nearby-search branch, which runs a different query chain) using a new
`_FakeAPIError` that mimics the real `postgrest.exceptions.APIError`
shape (confirmed by installing `supabase==2.11.0` into a scratch venv and
reading `postgrest.exceptions.APIError`'s source directly — it's a plain
`Exception` subclass with `.code`/`.message`/`.hint`/`.details` set from
the response body).

**3. CORS preflight `OPTIONS` returning `405`.** Root cause:
`app/main.py` only called `app.add_middleware(CORSMiddleware, ...)` `if
settings.cors_origins` — and the documented default for local dev
(`BACKEND_CORS_ORIGINS` left empty in `.env.example`) is exactly the case
where that's false. With no CORS middleware registered at all, Starlette
has no handler for a bare `OPTIONS` request on a route that only declares
`GET`/`POST`, so it fell through to its default "method not allowed" `405`
— confirmed by reading Starlette's actual `CORSMiddleware` source (a
correctly-configured-but-*rejecting* preflight returns `400` with an
explanatory body, never `405`; `405` only happens with no CORS middleware
in the stack at all).

The fix has two parts:
- `CORSMiddleware` is now **always** registered (`app/main.py`), so a
  preflight always gets a real CORS decision instead of falling through to
  Starlette's default.
- Flutter's web dev server (`flutter run -d chrome` / `-d web-server`)
  binds a different, unpredictable `localhost` port on every run, so it
  can't be listed as a fixed origin in `BACKEND_CORS_ORIGINS` the way a
  real deployed domain can. `Settings.cors_local_dev_origin_regex`
  (`app/core/config.py`) adds `allow_origin_regex` matching any
  `http(s)://localhost:<port>` or `127.0.0.1:<port>` origin, but **only
  outside `ENVIRONMENT=production`** — production still requires an
  explicit entry in `BACKEND_CORS_ORIGINS`, same as before. Native
  Android/iOS builds don't send an `Origin` header at all, so none of this
  affects them either way — this was always and only a web-dev-server
  problem.

Five new tests in `tests/test_cors.py` cover: a `localhost`/`127.0.0.1`
preflight is allowed in local dev, an arbitrary unconfigured origin is
rejected with something other than `405`, the `localhost` auto-allow does
*not* apply once `ENVIRONMENT=production`, and an explicitly configured
production origin still works. Because `CORSMiddleware` is configured
once inside `create_app()` from whatever `get_settings()` returns at that
moment — not re-resolved per request the way a route's
`Depends(get_settings)` is — the production-environment tests build a
fresh app with `create_app()` under a monkeypatched `get_settings` rather
than using `app.dependency_overrides` (which has no effect on middleware
already constructed at app-creation time).

**Verification:** full backend suite is 45 tests, all passing
(`pytest`), `ruff check` clean. The Dart changes (`app_router.dart`,
`profile_screen.dart`) were checked with the same brace/import-resolution
script used throughout this project in place of `flutter analyze` (no
Flutter SDK in this environment — see `mobile/README.md`); real
`flutter analyze`/`flutter test` runs happen the first time
`mobile-ci.yml` (Step 10) runs in CI.

## 15. Profile & Settings upgrade

A full rework of the Profile tab plus a new dedicated Settings screen.
Backend changes were kept to the one thing that actually needed a database
query (report counts); everything else reuses what already existed.

**New backend: `GET /reports/stats`.** The Profile screen's four stat
tiles (Total / Resolved / In Review / Submitted) need per-status counts of
the caller's own reports — nothing existing returned that, so
`reports_service.get_report_stats()` fetches just the `status` column for
the caller's rows and counts them in Python, the same trade-off already
made for "nearby" search (`STATS_SCAN_LIMIT` is a generous safety cap, not
a real limitation — see its comment). **Route ordering matters here**: the
new `GET /reports/stats` is registered *before* `GET /{report_id}` in
`app/api/v1/endpoints/reports.py`, because both are a bare `GET` one path
segment past `/reports`, and FastAPI/Starlette matches routes in
registration order — declared the other way round, `/reports/stats` would
be swallowed by `/{report_id}` with `report_id="stats"`. A regression test
(`test_report_stats_route_does_not_shadow_get_report_detail`) pins this.
Reuses `_raise_for_supabase_error` from the CORS/schema-errors fix, so a
missing-table error here gets the same clear `503` as everywhere else.
**No migration needed** — this reads the existing `reports` table's
`status` column, nothing new to create.

**Edit Profile updates Supabase Auth directly — no new `profiles` table,
no new backend endpoint.** This app's only mutable, DB-backed profile field
is `full_name`, which has lived in Supabase Auth's `user_metadata` since
Step 3 (`GET /users/me` already reads it straight from the JWT, no
database round-trip). Adding a `profiles` table just to hold one field
Supabase Auth already stores would be a duplicate system for the same
data — exactly what the project brief says to avoid. `AuthRepository.
updateFullName()` calls `updateUser(UserAttributes(data: {...}))` on the
Supabase client directly, the same client the app already talks to for
sign-in/sign-up.

**A subtlety worth flagging: `updateUser()` alone doesn't make the change
visible immediately.** Supabase embeds `user_metadata` in the JWT at
token-mint time; `updateUser()` updates the stored value but doesn't
proactively re-mint the *current* access token — that only happens on its
next natural refresh (which could be up to an hour away). Since the
backend's `GET /users/me` reads `full_name` straight out of the JWT,
without an explicit refresh the Profile screen would keep showing the old
name for up to that long after a successful edit. `updateFullName()`
therefore calls `refreshSession()` immediately afterward, forcing a new
JWT that embeds the just-updated metadata. The registered email is
intentionally read-only in `EditProfileScreen` — changing it requires
Supabase's own email-confirmation flow, which is a separate, larger
feature than this step's "edit appropriate profile information" scope.

**Saved Reports is a real screen with a stub data path, not a fake one.**
There is no `saved_reports` table and no save/unsave endpoint yet — this
step only prepares the navigation (`/profile/saved-reports`) and the
repository seam (`ReportsRepository.getSavedReports()`), which always
returns an empty page today. The screen's empty state ("Saved reports
coming soon") is therefore accurate rather than a spinner that never
resolves or a broken call to an endpoint that doesn't exist. A later step
adding real saving needs: a `saved_reports(user_id, report_id)` join table
+ migration, `POST`/`DELETE` endpoints, a "Save" action on the report
detail screen, and swapping `getSavedReports()`'s stub for a real call.

**Dark mode was added deliberately narrowly.** Most of this app's shared
widgets already read colors from `Theme.of(context)` (buttons, text
fields, scaffolds), so `AppTheme.dark` "just works" for them once it
exists. The one widget that didn't was `AppCard` — it hardcoded
`AppColors.surface`/`AppColors.border` (pure white / light gray)
regardless of theme, which would make every card in the app unreadable in
dark mode (light text from the new dark `TextTheme` on a white card).
Rather than switching it to `Theme.of(context).colorScheme.surface` (which
would also have subtly shifted *light* mode's appearance — Material 3's
seeded surface color is a faint tint, not pure white, and light mode is
supposed to stay pixel-identical to what it already was), `AppCard` now
branches on `Theme.of(context).brightness` and picks between the existing
light constants and new dark ones. Icon-only colors elsewhere
(`EmptyView`'s disabled-gray icon, `ErrorView`'s red icon, `StatusBadge`'s
status colors) were left as-is — they're mid-tone/saturated enough to
stay legible on a dark background without needing the same treatment.

**Theme preference defaults to Light, not System.** The project brief is
explicit that light stays the primary/default visual design; defaulting a
fresh install to "System Default" would mean a phone in dark mode never
sees that design until the user finds the setting and changes it. Stored
via `shared_preferences` (a new, minimal dependency — the standard
Flutter-team package for exactly this) so the choice survives app
restarts; read/write failures fall back to the in-memory value rather than
crashing over a non-critical setting.

**Layout reuse.** Four new shared widgets — `SectionHeader`,
`SettingsListTile`, `SettingsSection`, `StatTile` — are what both the
Profile screen's four grouped sections and the Settings screen's grouped
rows are built from, so "MY ACTIVITY"/"SETTINGS"/"LEGAL"/"ACCOUNT" and
Settings' own groups look identical without either screen re-specifying
card/divider/spacing details. `StaticContentScreen` does the same for the
four long-form text screens (Privacy Policy, Terms & Conditions, About
NAGARIK, Help & Support) — each of those files is just its content, not
layout code.

**Privacy Policy / Terms & Conditions copy is a placeholder**, written to
be factually accurate to what this app actually does (Supabase Auth
accounts, the `reports` table, a private Storage bucket, no data sold to
third parties) but explicitly **not** reviewed legal text — replace it
before a real release, same as any other template legal copy.

**New test coverage:** backend — `test_report_stats_requires_authentication`,
`test_report_stats_counts_only_the_callers_own_reports_by_status`,
`test_report_stats_is_all_zero_for_a_user_with_no_reports`,
`test_report_stats_returns_503_when_reports_table_is_missing`,
`test_report_stats_route_does_not_shadow_get_report_detail` (all in
`tests/test_reports.py`). Mobile — `test/profile_settings_test.dart`
covers `ReportStats.fromJson`, the `AppThemePreference` <-> `ThemeMode`
mapping, and `UserProfile.displayName`'s fallback chain.

## 16. My Reports & Report Tracking upgrade

Every report now has a stable, human-readable reference id (e.g.
`NGR-2026-00001`), My Reports gained status tabs and richer cards, and
Report Detail gained a visual status timeline. One new migration; no new
tables, no new endpoints.

**Reference ids are assigned by a database trigger, not by this backend's
Python code.** `backend/migrations/0003_report_reference_id.sql` adds a
`reference_id` column plus a `BEFORE INSERT` trigger that fills it in from
a small `report_reference_counters(year, last_value)` table — one row per
calendar year, so the number resets to `00001` each January. The counter
increment and the id assignment happen inside a single
`INSERT ... ON CONFLICT ... DO UPDATE ... RETURNING` statement, which
Postgres executes atomically; two citizens submitting a report at the same
instant still get two different, correctly-ordered numbers, with no
"read the counter, then write it back" gap a race condition could land in.
Doing this with a trigger (not, say, counting existing rows in
`create_report()` before inserting) was the deliberate choice, for the same
reason the project already uses one for `updated_at`: a trigger is
transactional with the insert itself, and Python-side counting would be
racy under concurrent submissions. The trigger only fills in `reference_id`
when it's still null and never runs on `UPDATE`, which is what makes the
id **stable after creation** — nothing in this schema, including a future
status-transition feature, can change it once assigned. Existing rows (if
any) are backfilled by the same migration, in `created_at` order, using the
same per-year counter, so backfilled and newly-created ids share one
continuous sequence. A unique index (`reports_reference_id_key`) enforces
uniqueness and doubles as the lookup index. **Run
`0003_report_reference_id.sql` before using this feature** — the
`ReportResponse` schema now requires `reference_id` on every report, so an
un-migrated database would fail every `/reports` response with a Pydantic
validation error, the same way a missing `reports` table itself would.

**The reference id is a display/identification field, not a routing key.**
Navigation (`/report/:id`) still uses the internal UUID, unchanged — adding
a second way to look up a report by `reference_id` wasn't asked for and
isn't needed for this step's goals (showing citizens a stable id they can
read, save, or quote), so it wasn't built, in line with not introducing
duplicate systems for the same job.

**The status timeline shows three stages, not the four in the original
design sketch, and that's a deliberate call, not an oversight.** The
requested visual was Report Submitted -> Under Review -> Action Taken ->
Resolved, but `ReportStatus` (backend and mobile) only has three values:
`submitted`, `in_review`, `resolved` — there is no `action_taken` status
anywhere in the schema. A fourth "Action Taken" stage on screen would
either sit permanently unlit for every report (implying a step that no
report can ever actually reach) or have to be marked complete at the exact
same moment as "Resolved" with no real timestamp or data behind it —
exactly the "don't invent fake status history" the brief warned against.
`mobile/lib/features/reports/domain/report_timeline.dart`'s
`timelineStagesForStatus()` maps a `ReportStatus` onto exactly the three
real stages instead. This is built to extend cleanly, per the brief's own
"structure the UI so additional stages can be supported later": `
StatusTimeline` (the widget) and `TimelineStage`/`TimelineStageState` (the
data it's driven by) already accept an arbitrary ordered list of stages —
the day the backend adds a genuine intermediate status, only
`timelineStagesForStatus()` needs to change to insert it; no widget or
screen needs touching.

**My Reports filters client-side against one fetch, not one API call per
tab.** `myReportsProvider` now requests up to the backend's `MAX_PAGE_SIZE`
(50, up from 20) in a single `GET /reports?mine=true` call; the All/
Submitted/In Review/Resolved chip row (reusing the same `ChoiceChip`
pattern the Search tab already established for status filtering, rather
than introducing a new tab-bar paradigm) filters that one result in Dart
and shows a live count per chip. This means switching tabs is instant and
costs no extra network round trip, at the cost of only surfacing a user's
most recent 50 reports — not a realistic limit for a civic-reporting app,
and `ReportsPage.hasMore` already carries what a future "load more" would
need if it ever becomes one. User isolation itself is unchanged and was
already correct: `GET /reports?mine=true` requires authentication and is
filtered server-side by the caller's own `user_id`
(`test_browse_reports_mine_returns_only_the_callers_reports` and the new
`test_browse_reports_mine_does_not_leak_another_users_reference_id` both
pin this).

**Report cards gained an optional thumbnail, reference id, and date
footer** (`ReportCard`'s `imageUrl`/`referenceId`/`date` parameters, all
nullable) — used everywhere a real `Report` is available (Home feed,
Search, My Reports) so the reference id requirement ("displayed across
report cards and report details") is met consistently rather than only on
one screen. The create-report review step's card intentionally leaves all
three null: a draft has no reference id (none is assigned until the report
actually exists), no signed image URL yet, and no creation date yet.

**Report Detail** now shows the reference id (next to the category, always
visible without scrolling), City and PIN code as their own rows (previously
combined into one "Location" row), an always-shown "Updated" row (previously
only shown when it differed from "Created"), and the status timeline at the
bottom under a reused `SectionHeader`.

**No Supabase migration is needed beyond `0003_report_reference_id.sql`** —
everything else in this step (the tab filter, the card footer, the
timeline) is presentation logic over data the API already returns.

**New test coverage:** backend —
`test_submit_report_response_includes_a_well_formed_reference_id`,
`test_submitting_two_reports_gives_each_a_different_reference_id`,
`test_get_report_detail_includes_the_reference_id`,
`test_browse_reports_includes_reference_id_for_every_item`,
`test_browse_reports_mine_does_not_leak_another_users_reference_id` (all in
`tests/test_reports.py`; `_FakeTable`/`_make_report_row` were updated to
simulate the reference-id trigger so every existing test kept working
unchanged). Mobile — `test/report_timeline_test.dart` covers
`timelineStagesForStatus` for every status; `test/report_card_test.dart`
gained cases for the new footer and thumbnail; `test/report_parsing_test.dart`
now asserts `Report.fromJson` parses `reference_id`.

## 17. Location Discovery & Home Experience upgrade

Home is no longer just a plain recent-reports feed: it gained a location
indicator, a "Nearby Issues" section using real device GPS, category
shortcuts, and a "Recent Reports" section — and Search gained a List/Map
toggle. No new tables; one new lean backend endpoint.

**A new endpoint exists only because markers need a fundamentally different
payload shape, not different filtering.** `GET /reports/markers` reuses
exactly the same filter semantics as `GET /reports` (category, status,
city, pin_code, search, nearby) — both now call a shared
`_build_reports_query()` / `_nearby_filter_and_sort()` extracted from the
original `list_reports()` — but requests only
`id,reference_id,category,status,city,latitude,longitude` from Postgres via
the `select()` column list itself, not `"*"` filtered down in Python
afterward. A map may render dozens of pins; none of them need a
description or a signed image URL until the citizen actually taps one, at
which point the existing `GET /reports/{report_id}` (which My Reports and
Search already use) fetches the full record lazily. This is the concrete
form "do not load unnecessary report fields/images for map markers" takes.
Registered before `GET /{report_id}` for the same route-ordering reason as
`/reports/stats` in section 15 — pinned by
`test_report_markers_route_does_not_shadow_get_report_detail`.

**flutter_map (OpenStreetMap tiles), not google_maps_flutter.** The brief
asks for real report coordinates shown on a map — nothing about Google's
specific styling or Places integration. `google_maps_flutter` would require
a billing-enabled Google Cloud API key plus native Android/iOS manifest
configuration this project doesn't otherwise need; `flutter_map` renders
OSM tiles with neither. Chosen specifically to avoid imposing setup burden
the brief didn't ask for. Production traffic should review OpenStreetMap's
tile-usage policy (a custom `userAgentPackageName` is already set, as OSM's
policy requires) and consider a paid tile provider if usage grows —
noted here as a known follow-up, not a blocker for this step.

**The `geocoding` package turns coordinates into "📍 Bhopal" client-side —
no new backend surface.** `GeocodingService.cityFromCoordinates()` wraps
the native OS geocoder (Android `Geocoder`/iOS `CLGeocoder`, the same
mechanism `geolocator`'s maintainers publish this package for) and returns
`null` on any failure rather than throwing — reverse-geocoding is a nicety
layered on top of a real position, not something the location experience
should be able to fail over. If it returns `null`, the UI still has the
real position and simply doesn't show a city name.

**Five location UI states (permission request / denied / unavailable /
loading / retry) needed no new state-machine class.** `LocationService`
(built in Step 6) already throws a `LocationException` carrying a
directly-showable message for every failure mode. `homeLocationProvider`
is a plain Riverpod `FutureProvider`, so its `AsyncValue.loading/data/error`
*is* the state machine the brief asked for, and "Retry" is just
`ref.invalidate(homeLocationProvider)`. Avoided per "do not create
unnecessary business logic just for decoration."

**"If location permission is unavailable, the normal feed should still
work" is structural, not a guard clause.** Home's "Recent Reports"
(`homeFeedProvider`, unchanged since Step 7) has zero dependency on
`homeLocationProvider`. "Nearby Issues" (`nearbyReportsProvider`) is the
only section that awaits `homeLocationProvider.future`; if that rejects,
only the Nearby section shows a compact inline error with its own retry —
Home's greeting, search shortcut, category grid, recent reports, and
report CTA all render normally regardless.

**The List/Map toggle lives on the Search screen, not a new "Nearby"
screen.** Search is already the one screen that unifies nearby, city-wise,
and PIN-code-wise discovery against the same backend filters (Step 7/8).
Home's "Nearby Issues" → "See all", category tiles, and "Recent Reports" →
"See all" all navigate to `/search` with a query param
(`?nearby=true`, `?category=road`, `?all=true`), parsed once in
`app_router.dart` into `SearchScreen`'s constructor and run automatically
on first frame — reusing Search's existing filter/result pipeline entirely
instead of duplicating it for a second screen, per the same
"don't build unnecessary business logic" instruction.

**Switching List↔Map fetches only the newly-selected shape, once.**
`SearchScreen` holds `_resultsFuture` (`getReports`, full `Report` objects
for cards) and `_markersFuture` (`getReportMarkers`, lean pins) separately;
selecting a view re-fetches only if that view hasn't been fetched for the
current filters yet — never both eagerly, never re-fetched on every
rebuild.

**No Supabase migration needed.** This step is entirely additive on top of
the `reports` table's existing `latitude`/`longitude` columns (Step 6) —
same coordinates already used for `GET /reports?latitude=&longitude=`'s
nearby search, now also served through the new lean marker shape.

**Bottom navigation is unchanged**, per explicit instruction —
`scaffold_with_nav_bar.dart` was inspected but not modified; Home's new
in-body "Report Issue" button is additive to the always-visible FAB, not a
replacement for it.

**New test coverage:** backend — 8 new tests in `tests/test_reports.py`
covering the route-shadow regression, lean-fields-only assertion (no
`description`/`image_paths` keys in the response), coordinates-required
filtering, category filtering, nearby-radius filtering, the 400 on
mismatched lat/long, the 503 on a missing table, and no-auth-required
(63 total, all passing; `ruff check` clean). Mobile —
`test/discovery_test.dart` covers `ReportMarker.fromJson` (including the
unknown-status `FormatException`), `LocationIndicator`'s success and error
`AsyncValue` states (via `homeLocationProvider.overrideWith`), `CategoryGrid`
tap routing, and `ReportMap` rendering one pin per marker.

## 18. Report Sharing, Saved Reports & Final Feature Polish

Report Detail gained native Share and Save/Unsave actions, Saved Reports is
now backed by a real table and endpoints instead of an always-empty stub,
error/empty states were consolidated into reusable presets, and the app's
navigation moved from three flat tabs to a hybrid bottom-nav-plus-drawer
structure. One new migration; three new endpoints; no other schema changes.

**Share is a plain-text message built entirely client-side — no new
backend endpoint.** There's nothing to look up or compute server-side that
`GET /reports/{id}` doesn't already return, so `buildReportShareText()`
(`mobile/lib/features/reports/domain/report_share.dart`) is a pure function
over a `Report` already in memory, invoked from Report Detail's app-bar
Share icon via `share_plus`'s `Share.share()` (the platform share sheet —
Android/iOS's native sheet, with web/desktop fallbacks `share_plus` itself
provides). It deliberately includes only NAGARIK's name, the reference id,
category, a trimmed description, city, and status — never `user_id`, exact
GPS coordinates, or anything else that could identify or locate whoever
filed the report, per the brief's "do not expose private user information."
`share_plus` is pinned to its 7.x line specifically for its simple, stable
static `Share.share(text)` API (later majors moved to a `SharePlus.instance`
builder API); either works, 7.x just needed no call-site changes to add.

**Saved Reports needed exactly one new table.** `backend/migrations/
0004_saved_reports.sql` adds `saved_reports(user_id, report_id)` with a
`unique (user_id, report_id)` constraint — that constraint *is* the
duplicate-save guard the brief asks for ("duplicate saves must be
prevented"), not application-level logic re-checking before every insert.
`save_report()` (`reports_service.py`) catches the resulting Postgres
`23505` and treats it as success rather than an error: saving an
already-saved report should end up in the same state either way, so the
second attempt isn't a failure from the caller's point of view. A
`report_id` that doesn't exist trips the table's foreign key constraint
(`23503`) instead, which *is* a real error, surfaced as the same 404
`GET /reports/{id}` already gives for a bad id. RLS policies scope
select/insert/delete to `auth.uid() = user_id`, the same defense-in-depth
posture as every other table — "users can only manage their own saved
records" is actually enforced by the backend's own `user_id = current_user.id`
filtering on every saved-reports call (all three require
`Depends(get_current_user)`), with RLS as a second line of defense if this
table is ever queried outside the service-role client.

**`GET /reports/saved` returns full reports, not just saved rows.**
`saved_reports` only stores the `(user_id, report_id)` pair; the endpoint
fetches the matching `reports` rows in a second query
(`.in_("id", [...])`) so the response is an ordinary `ReportListResponse` —
the same shape, and the same `ReportCard` widget, that Home/Search/My
Reports already use. This is what "Report Card Polish" meant for Saved
Reports in practice: there was no separate saved-report card to build,
because the existing card already renders every field the brief asked for
(image, category, short text, location, status, reference id, date) — the
work was making sure Saved Reports actually populates one, not designing a
new one. Its one addition, a swipe-to-remove `Dismissible` per card, is
scoped to that screen rather than added to the shared `ReportCard` itself,
since "remove from saved" is a saved-reports-specific action, not something
Home or Search's cards need.

**`is_saved` is computed for real in exactly one place: `GET /reports/{id}`.**
It's a new field on `ReportResponse`, defaulting to `false`. A plain browse/
search list (`GET /reports`) leaves it at that default rather than joining
against `saved_reports` for every row — no card outside Report Detail shows
a saved indicator, so computing it there would be a real per-row query cost
for a value nothing reads. `GET /reports/saved` sets it to `true` directly
(true by definition, no query needed). `GET /reports/{id}` is the one
endpoint whose caller — Report Detail's Save/Unsave button — actually needs
to know the current caller's own saved state, so it alone calls
`_is_report_saved()`, using `get_optional_current_user` (not
`get_current_user`) so the endpoint stays public for an anonymous viewer
(who simply always sees `is_saved: false`, same as before this field
existed). The Flutter app never reaches this screen signed out anyway (the
router gates every screen), but the API itself stays exactly as public as
it already was.

**Save/Unsave re-fetches rather than updating state optimistically.** After
a successful save or unsave, `report_detail_screen.dart` invalidates both
`reportByIdProvider(id)` and `savedReportsProvider` and lets them refetch,
rather than flipping a local `isSaved` flag immediately. One extra request
for a tap this infrequent is a fair trade for the saved state shown always
being what the backend actually confirmed, not what the UI assumed would
happen.

**Network vs. API errors are now visually distinct, in one place.**
`ErrorView.forError(error, ...)` (`shared/widgets/error_view.dart`) is a
factory that inspects the caught error: `ApiException.isNetworkError`
(true when `ApiClient`'s Dio interceptor never got a response at all —
no connectivity, DNS failure, timeout) gets a "check your connection" copy
and a Wi-Fi-off icon; any other `ApiException` shows the backend's own
message (already human-readable — a 404's "Report not found.", a 503's
migration-pointing message, etc.) with a generic cloud-off icon; anything
else falls back to a caller-supplied message. Screens that previously
constructed `ErrorView` with a hand-written, one-size-fits-all message
(Report Detail, My Reports, Saved Reports, Search, Profile, Edit Profile,
Settings) now pass the actual caught error through this factory instead —
one factory function is what makes "API error" and "Network error" a
real, consistent distinction app-wide rather than a state each screen would
otherwise have to detect and word on its own.

**Reusable empty states are named constructors on the existing `EmptyView`,
not a new widget.** `EmptyView.noReports()`, `.noSavedReports()`,
`.noNearbyReports()`, and `.searchNoResults()` each fix one screen
situation's icon/title/message in one place (`shared/widgets/
empty_view.dart`) instead of every call site re-writing similar copy —
`EmptyView` itself is unchanged, these are just presets over its existing
fields. `.noReports()` also accepts an optional `actionLabel`/`onAction`,
used by Home's "Recent Reports" empty state to offer "Report an Issue"
directly (reusing the existing `/report/create` route) rather than a dead
end. A couple of situations stayed intentionally custom rather than reusing
a preset — My Reports' filtered-empty-tab message and Search's map-specific
"no matching reports to show on the map" — because their wording depends on
context a shared preset can't express without becoming vaguer for every
other caller.

**Hybrid navigation: four bottom-nav tabs, everything else in one drawer.**
Per the brief, the bottom bar was reduced to Home, Search, **My Reports**,
and Profile — My Reports moved here from a screen previously pushed off
Profile (`/profile/my-reports`), because it's used often enough to be one
of the "4-5 most important primary features," not a Profile setting. It
kept its existing route's screen and provider entirely; only its route
changed (`/my-reports`, now a `StatefulShellBranch` alongside the other
three tabs), and Profile's own "My Reports" tile now switches to that tab
(`context.go('/my-reports')`) instead of pushing a second copy of the
screen — this is what the brief's "do not create duplicate screens/routes
for sidebar and bottom navigation" rules out, and the fix is the same
one-route-many-entry-points pattern Home's category shortcuts already
established for Search in the Location Discovery upgrade. "Report Issue"
stays a FAB rather than becoming a fifth bottom-nav destination — it
already has one-tap access from every tab, and adding it as a sixth
icon+label would be the "overcrowded bottom navigation" the brief warns
against for the sake of a feature that already has prime placement.

`AppDrawer` (`core/routing/app_drawer.dart`) is the single full feature
menu: Home, Search/Discover, My Reports, Saved Reports, Report Issue,
Map/Nearby, Settings, Help & Support, Privacy Policy, Terms & Conditions,
About NAGARIK, and Logout — every single one of these reuses an existing
route (Saved Reports/Settings/Report Issue/the legal pages/About are
pushed exactly as Profile's own tiles already push them; Home/Search/My
Reports switch tabs exactly as Profile's tiles now do). "Map / Nearby" is
the one drawer entry with no screen of its own even conceptually: it opens
Search pre-switched to both "Near me" and the Map view
(`/search?nearby=true&view=map`), a small, additive `initialView`
constructor parameter on `SearchScreen` alongside the Location Discovery
upgrade's existing `initialCategoryName`/`initialNearby`/`initialShowAll` —
not a new "Nearby Map" screen, which would have duplicated Search's
existing List/Map toggle for no reason. A `UserAccountsDrawerHeader`
showing the signed-in citizen's name/email stands in for a dedicated
"Profile" drawer entry (the brief's list doesn't include one, since Profile
is already one of the four bottom-nav tabs).

**The drawer is wired to each tab's own `Scaffold`, not the outer shell
scaffold.** `ScaffoldWithNavBar` (the `StatefulShellRoute`'s shared
scaffold) has no `AppBar` of its own — each tab (`HomeFeedScreen`,
`SearchScreen`, `MyReportsScreen`, `ProfileScreen`) renders its own nested
`Scaffold` with its own `PrimaryAppBar`. Flutter only auto-shows the
hamburger menu icon on an `AppBar` that's a direct child of the `Scaffold`
carrying the `drawer:`, so `AppDrawer` is declared on each of those four
screens' own `Scaffold` instead of the shell's — the technically correct
place for it to actually produce a hamburger icon, not an arbitrary choice.

**Verification:** backend — `tests/test_saved_reports.py` (13 new tests:
save/unsave, idempotent duplicate save, 404 on a nonexistent report,
per-caller isolation on `GET /reports/saved`, the `/saved` route-shadow
regression, and `is_saved` reflecting anonymous vs. the correct
authenticated caller on `GET /reports/{id}`) plus the existing suite,
76 total, all passing, `ruff check` clean. Mobile — `test/
report_share_test.dart` (pure-Dart: required fields present, `user_id`/
exact coordinates never present, long descriptions truncated),
`test/error_empty_states_test.dart` (`ErrorView.forError`'s network/API/
fallback branches and each `EmptyView` preset), and `test/
app_drawer_test.dart` (every hybrid-nav menu item is present, plus the
profile header) — all passing the same brace/import static check used
throughout this project (no Flutter SDK in this environment; see
`mobile/README.md`).

## 19. Official Logo & User Profile Photo upgrade

The app's real logo replaces every placeholder brand mark, and users can
now upload, replace, and remove a profile photo. One new migration
(a private `avatars` Storage bucket), two new endpoints, and one new field
on `GET /users/me`'s response; no changes to any existing endpoint's
behavior beyond that added field.

**The logo is one asset, wrapped in one widget.** `mobile/assets/images/
nagarik_logo.png` is the exact file provided, registered in `pubspec.yaml`
and never re-encoded or re-sized on disk — `Logo` (`shared/widgets/
logo.dart`) is the single place every screen renders it from, always via
`Image.asset(..., fit: BoxFit.contain)` in a square `size x size` box, so
no caller can accidentally stretch or crop it regardless of what size they
ask for. It's used on Login, Signup, the startup splash, the Home app bar
(`PrimaryAppBar`'s new `showLogo` flag — Home only, not every screen, so
the mark doesn't compete with each screen's own title), the drawer header,
and About NAGARIK (via a new optional `header` slot on
`StaticContentScreen`).

**Splash/startup needed a real gap to fill.** Before this upgrade, `main()`
awaited `Env.load()` and `initSupabase()` *before* calling `runApp` at
all — so the very first frame Flutter ever drew was already the signed-in/
signed-out router redirect; there was no moment to show a splash in.
`main()` now calls `runApp` immediately with `NagarikApp`, which itself
becomes a small state machine: it shows `SplashScreen` (just the logo,
centered, on `AppColors.background`) while its own `initState` runs those
same two awaits, then swaps to the real `MaterialApp.router` once both
finish. `SplashScreen` deliberately depends on nothing but `Logo` and a
static color — no theme, no router, no Supabase client — since it has to
render correctly in the one window where none of those exist yet.

**Profile photos live in Storage, not a database column — same pattern as
`full_name`.** There is still no `profiles` table (see section 9). A photo
is stored in a new private bucket, `avatars`
(`backend/migrations/0005_avatars_bucket.sql`, RLS-scoped to
`(storage.foldername(name))[1] = auth.uid()::text`, same convention as
`report-images`), at a single fixed path per user —
`<user_id>/avatar.<ext>` — because a profile photo is one slot that gets
replaced or removed, not a growing list like report images. The
*reference* to that path is kept in Supabase Auth's `user_metadata`
(`avatar_path`), exactly where `full_name` already lives, because the
backend has no other place to persist it and no way to write
`user_metadata` itself (see the next point). `GET /users/me` signs that
path fresh on every call (`profile_service.sign_avatar_url`) into the new
`avatar_url` response field — best-effort, same philosophy as report image
signing: a broken Storage call degrades to no photo, never a broken
profile screen.

**The backend only ever touches Storage bytes; the Flutter client owns
`user_metadata`.** `POST /users/me/avatar` (multipart upload) and
`DELETE /users/me/avatar` (`app/services/profile_service.py`) upload to and
remove from the `avatars` bucket and return the new path — they cannot
write `user_metadata` themselves, since that requires the *user's own*
session, which the backend never holds (it only ever sees a bearer token,
verified locally). So the Flutter client is the one that calls
`AuthRepository.updateAvatarPath(path)` right after either call succeeds,
mirroring `updateFullName`'s existing pattern exactly — including its
`refreshSession()` follow-up, needed for the *current* JWT to carry the new
claim immediately rather than on its next natural refresh.

**A real bug this upgrade would otherwise have introduced: `updateUser`
replaces `user_metadata`, it doesn't merge it.** Supabase Auth's `data`
parameter on `updateUser()` overwrites the whole `user_metadata` object
server-side rather than merging keys into it (confirmed against
[supabase-py#1644](https://github.com/supabase/supabase-py/issues/1644),
where the maintainers confirm this isn't client-specific). `updateFullName`
had gotten away with calling `updateUser(data: {'full_name': ...})`
directly only because `full_name` was the *only* key ever stored — adding
`avatar_path` as a second key would have made every full-name edit
silently erase the user's saved photo (and vice versa) the moment both
existed. `AuthRepository` now routes both through one private
`_updateMetadata()` that reads `currentUser?.userMetadata`, merges the
requested change into a copy of it (removing a key entirely when the new
value is `null`, so `updateAvatarPath(null)` actually clears
`avatar_path` rather than storing a literal `null`), and pushes the merged
map — `updateFullName` and `updateAvatarPath` are both now just one-line
callers of that shared, correct implementation.

**Replacing a photo cleans up the old one, including across a format
change.** `profile_service.upload_avatar` lists whatever's already stored
for the user before uploading (Storage has no "overwrite regardless of
name" primitive across different extensions), uploads the new file with
`upsert` (so replacing a `.jpg` with another `.jpg` overwrites cleanly),
and only afterwards removes any leftover object under a *different*
extension (a `.jpg` replaced by a `.png`, say) — ordered this way, and
best-effort on the cleanup step, so a failed cleanup never costs the user
their just-uploaded photo. `delete_avatar` is the same "list, then remove"
shape and is idempotent, same philosophy as `unsave_report`: removing a
photo that was never there is a no-op, not a 404.

**Edit Profile is the one place to change it; Profile and the drawer just
display it.** A small camera-badge button on Edit Profile's avatar opens a
bottom sheet — Take Photo / Choose from Gallery / Remove Photo (the last
only shown when a photo exists) — backed by the same `image_picker` already
used for report photos, downscaled client-side (`maxWidth: 1024,
imageQuality: 85`) to stay comfortably under the backend's 5 MB cap without
a separate compression step. `ProfileAvatar` (`shared/widgets/
profile_avatar.dart`) is the one widget that decides "photo or initial
fallback" — used on Edit Profile, the Profile tab (tapping it also opens
Edit Profile, rather than duplicating the picker sheet there), and the
drawer header — so a missing photo, a still-loading one, and a broken
signed URL all resolve to the same initial-letter avatar everywhere, never
a broken-image icon.

**The drawer header changed shape: brand row on top, account info below,
one `DrawerHeader` instead of `UserAccountsDrawerHeader`.** Section 18's
drawer used Flutter's built-in `UserAccountsDrawerHeader` for the
signed-in citizen's name/email. That widget has exactly one picture slot,
which this upgrade needs for the user's own photo (`ProfileAvatar`) — so
the NAGARIK brand mark (`Logo` + wordmark) needed a place of its own rather
than competing for that slot. The header is now a plain `DrawerHeader`
with a small brand row at the top and the avatar/name/email row below it;
every menu item below is unchanged.

**App icons: configured, not generated — this repository has no platform
folders yet.** `pubspec.yaml` gains a `flutter_launcher_icons:` block
pointing at the same `nagarik_logo.png`, covering Android, iOS, web,
macOS, and Windows. `flutter_launcher_icons` writes generated icons into
each platform's own folder (`android/`, `ios/`, etc.) — this repository has
never been through `flutter create` and has none of them, so there's
nothing yet for the tool to write into. Running `flutter create .` once
(needed before this project can be built for any platform regardless of
this upgrade) followed by `dart run flutter_launcher_icons` is a one-time
step left for whoever first builds a real app binary — see
`mobile/README.md`'s "App icons" section.

**Verification:** backend — `tests/test_profile_avatar.py` (12 new tests:
upload, replace under the same extension, replace under a different
extension with old-file cleanup, unsupported type, over-size, empty file,
storage-failure 502, unauthenticated upload/delete, delete with/without a
prior upload, per-user isolation) and two new tests added to
`tests/test_users.py` (`avatar_url` absent/null by default, signed
correctly when `avatar_path` is set) plus the existing suite, 90 total, all passing,
`ruff check` clean. Mobile — `test/logo_test.dart` (asset path, default and
custom sizing, optional corner clipping, the splash screen), `test/
profile_avatar_test.dart` (initial-letter fallback, empty-URL and
empty-name edge cases, custom radius), and two new cases in `test/
profile_settings_test.dart` (`UserProfile.fromJson` parsing `avatar_url`)
— all passing the same brace/import static check used throughout this
project (no Flutter SDK in this environment; see `mobile/README.md`).
`AuthRepository`'s metadata-merge fix has no automated test — this
codebase has no precedent for mocking the Supabase Auth SDK itself (every
existing `AuthRepository` method is a thin, untested pass-through to it),
so this was verified by code review instead; it's called out here so a
future change to `_updateMetadata` gets the same scrutiny.
