# NAGARIK (Flutter app)

## Prerequisites

- Flutter SDK >= 3.22. This code was authored and statically checked
  (bracket balance + internal import resolution) in an environment without
  the Flutter SDK installed — it has **not** been run through
  `flutter pub get` / `flutter create` / `flutter analyze` / `flutter test`
  yet. Running that full sequence is the first thing to do wherever this
  project is opened next (your machine or CI).

## Local setup

```bash
cd mobile
flutter pub get

cp .env.example .env
# then edit .env with your Supabase project's URL/anon key and API base URL

flutter run
```

## Run tests

```bash
flutter test
```

`test/` includes plain widget tests (`widget_test.dart`,
`shared_widgets_test.dart`, `report_card_test.dart`) and pure-Dart logic
tests with no widget pump needed (`report_parsing_test.dart`, covering
`Report.fromJson`/`ReportsPage.fromJson`/`Report.statusToWire` — the wire
parsing every screen depends on).

## Project layout

```
lib/
├── main.dart                 # entrypoint: loads env, inits Supabase, runs app
├── app.dart                  # root MaterialApp.router widget, applies AppTheme
├── core/
│   ├── config/env.dart               # typed .env access
│   ├── constants/
│   │   ├── api_endpoints.dart        # FastAPI path constants
│   │   ├── report_category.dart      # ReportCategory enum (label + icon)
│   │   └── report_status.dart        # ReportStatus enum (Submitted/In Review/Resolved)
│   ├── network/
│   │   ├── api_client.dart               # Dio client -> FastAPI, attaches Supabase JWT
│   │   ├── api_exception.dart            # normalized error type
│   │   └── supabase_client_provider.dart # Supabase Auth init (Auth only, see docs/ARCHITECTURE.md)
│   ├── routing/
│   │   ├── app_router.dart               # go_router config: shell + top-level routes
│   │   └── scaffold_with_nav_bar.dart    # bottom-nav shell (Home/Search/Profile) + Report FAB
│   ├── theme/
│   │   ├── app_colors.dart               # color palette
│   │   ├── app_spacing.dart              # spacing + radius scale
│   │   ├── app_typography.dart           # TextTheme
│   │   └── app_theme.dart                # ThemeData combining the above
│   └── utils/                        # empty
├── features/
│   ├── auth/presentation/screens/        # login_screen.dart, signup_screen.dart (Step 3: real Supabase Auth)
│   ├── discovery/presentation/screens/   # home_feed_screen.dart (Step 7 feed), search_screen.dart (Step 8 filters/search)
│   ├── profile/presentation/screens/     # profile_screen.dart — profile (Step 4) + report history (Step 7)
│   └── reports/
│       ├── domain/
│       │   ├── report_draft.dart   # in-progress report form state
│       │   ├── report.dart         # a submitted report, as the backend returns it
│       │   └── reports_page.dart   # one paginated page of GET /reports results (Step 7/8)
│       ├── data/
│       │   ├── reports_repository.dart # submitReport / getReport / getReports (Step 5-8)
│       │   └── location_service.dart   # geolocator wrapper (Step 6)
│       └── presentation/
│           ├── screens/create_report_screen.dart # Category -> Description -> Location -> Photos -> Review
│           ├── screens/report_detail_screen.dart # full report detail, images, timestamps (Step 7)
│           └── widgets/report_card.dart          # reusable report card (feed/search/profile/review)
└── shared/widgets/
    ├── app_button.dart      # AppButton (primary/secondary/outlined/text, loading state)
    ├── app_text_field.dart  # AppTextField
    ├── app_card.dart        # AppCard
    ├── status_badge.dart    # StatusBadge (colored by ReportStatus)
    ├── primary_app_bar.dart # PrimaryAppBar
    ├── loading_view.dart    # LoadingView
    ├── error_view.dart      # ErrorView (message + optional Retry)
    └── empty_view.dart      # EmptyView (icon + title + message + optional action)
```

Each feature folder follows a light clean-architecture split
(`data` / `domain` / `presentation`); `data`/`domain` stay empty until the
step that needs them is implemented.

## Native permissions (required once `flutter create .` has run)

This project has never been run through `flutter create`, so the
`android/` and `ios/` native folders don't exist yet in this environment.
`geolocator` (device location) and `image_picker` (camera capture) both
need OS-level permission declarations that only live in those native
folders. Once you scaffold them on your machine, add:

**`android/app/src/main/AndroidManifest.xml`** (inside `<manifest>`, above
`<application>`):

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
```

**`ios/Runner/Info.plist`** (inside the top-level `<dict>`):

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>NAGARIK uses your location to tag where a civic issue is happening.</string>
<key>NSCameraUsageDescription</key>
<string>NAGARIK uses your camera to attach photos of a civic issue to your report.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>NAGARIK needs access to your photo library to attach existing photos to a report.</string>
```

Without these, `LocationService.getCurrentPosition()` and the gallery/camera
pickers in the "Photos" step of report creation will fail at runtime with a
platform permission error even though the Dart code itself is correct —
this is standard Flutter behavior, not a bug in this app.

## Navigation

- Bottom tabs (`StatefulShellRoute`): **Home** (`/home`), **Search**
  (`/search`), **Profile** (`/profile`) — each keeps its own stack/scroll
  position when switching tabs.
- Pushed full-screen (no bottom nav): **Login** (`/login`), **Signup**
  (`/signup`), **Report an Issue** (`/report/create`), **Report Details**
  (`/report/:id`).
- A "Report Issue" FAB is always visible over the tabs.

Auth-gated redirects (forcing `/login` before a protected action, e.g.
`/report/create`) are wired in `core/routing/app_router.dart` (Step 3),
driven by Supabase's real auth state.

## What's real vs. deferred in this UI

Every screen is now wired to the real backend end to end: signing in/up
(Step 3), the profile view (Step 4), submitting a report with real device
location and photos (Steps 5/6), the home feed, report detail, "your
reports" history, and search/filters (Steps 7/8) all call the live
`/reports` endpoints. There is no remaining deferred discovery feature from
the original scope — what's left (analytics, admin dashboard, push
notifications, multi-language, in-app chat) is explicitly out of scope per
the project brief, not deferred work.

**Step 9 hardening:** the description (2000 chars), city (100 chars), and
PIN code (6 digits) fields on report creation — and the equivalent city/PIN
filters on Search — now cap input length via `AppTextField`'s/
`TextFormField`'s `maxLength`, mirroring the backend's own limits so the
keyboard stops you before a submission would be rejected. This is a UX
convenience only; the backend enforces the same limits independently
either way (see `backend/README.md`).

## State management, navigation, networking

- **State management:** Riverpod (`flutter_riverpod`)
- **Navigation:** `go_router` (`StatefulShellRoute.indexedStack` for the
  bottom-nav tabs)
- **HTTP:** `dio`, wrapped by `ApiClient`
- **Auth:** `supabase_flutter` (talks directly to Supabase Auth)
- **Location:** `geolocator` (Step 6) — see "Native permissions" above
- **Images:** `image_picker` (Step 6) — see "Native permissions" above
- **Image display/caching:** `cached_network_image` (Step 7) — reports'
  signed Storage URLs are loaded through this in the feed, search results,
  and report detail screen

No new dependencies were needed for Step 2 — `Stepper`, `ChoiceChip`,
`NavigationBar`, and `RefreshIndicator` are all part of the Flutter SDK.

## Search & discovery (Step 8)

The Search tab supports, per the project brief's discovery requirements:

- **Keyword search** — matches against a report's description or city
  (submit via the keyboard's search action).
- **Category** and **status** filters — chip-based, single-select, with an
  "All"/"Any" option to clear each one.
- **City** and **PIN code** filters — free-text fields, applied on the next
  search (submit via the search icon button).
- **Nearby** — the "Near me" chip requests the device's current location
  (via `LocationService`, same as report creation) and switches results to
  nearest-first within a fixed radius instead of most-recent-first.

Any combination of these can be active at once; changing a chip re-runs the
search immediately, while the keyword/city/PIN text fields wait for an
explicit submit so the app isn't searching on every keystroke.

See `docs/ARCHITECTURE.md` at the project root for the rationale behind the
auth-token flow between Flutter, FastAPI, and Supabase.
