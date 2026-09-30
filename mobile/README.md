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
`shared_widgets_test.dart`, `report_card_test.dart` — including the report
reference id/thumbnail/date footer) and pure-Dart logic tests with no
widget pump needed (`report_parsing_test.dart`, covering
`Report.fromJson`/`ReportsPage.fromJson`/`Report.statusToWire`, including
`reference_id`; `profile_settings_test.dart`, covering `ReportStats.fromJson`
and the `AppThemePreference` <-> `ThemeMode` mapping; `report_timeline_test.dart`,
covering `timelineStagesForStatus`'s mapping from a report's status onto
the status timeline's completed/current/upcoming stages).

**Location Discovery & Home upgrade:** `discovery_test.dart` covers
`ReportMarker.fromJson` (including the unknown-status `FormatException`),
`LocationIndicator`'s loading/data/error rendering (by overriding
`homeLocationProvider` with `ProviderScope`), `CategoryGrid`'s tap-to-category
callback, and `ReportMap` rendering one `Icons.location_on` pin per marker.

**Report Sharing, Saved Reports & Final Feature Polish:**
`report_share_test.dart` covers `buildReportShareText` (pure Dart: the
NAGARIK/reference id/category/description/city/status fields are present,
`user_id` and exact coordinates never are, and a long description is
truncated); `error_empty_states_test.dart` covers `ErrorView.forError`'s
network/API/fallback branches and every `EmptyView` named-constructor
preset; `app_drawer_test.dart` pins that every item the hybrid navigation
brief calls for is actually present in `AppDrawer`, plus its profile header.

**Official Logo & User Profile Photo upgrade:** `logo_test.dart` covers
`Logo` (the correct asset path, default/custom square sizing, optional
corner-radius clipping) and that `SplashScreen` renders it; `profile_avatar_test.dart`
covers `ProfileAvatar`'s initial-letter fallback (no photo, an empty-string
URL, and an empty display name) and custom radius; two cases added to
`profile_settings_test.dart` cover `UserProfile.fromJson` parsing the new
`avatar_url` field.

## Project layout

```
lib/
├── main.dart                 # entrypoint: runs the app immediately (splash shows first)
├── app.dart                  # root widget: shows SplashScreen while env/Supabase init, then MaterialApp.router
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
│   │   ├── scaffold_with_nav_bar.dart    # bottom-nav shell (Home/Search/My Reports/Profile) + Report FAB
│   │   └── app_drawer.dart               # AppDrawer: the full feature menu, on every bottom-nav tab
│   ├── startup/splash_screen.dart    # SplashScreen: the logo, shown while app.dart loads env/Supabase
│   ├── theme/
│   │   ├── app_colors.dart               # color palette (light + dark tokens)
│   │   ├── app_spacing.dart              # spacing + radius scale
│   │   ├── app_typography.dart           # TextTheme (light + dark)
│   │   ├── app_theme.dart                # ThemeData: AppTheme.light + AppTheme.dark
│   │   └── theme_preference.dart         # System/Light/Dark choice, persisted via shared_preferences
│   └── utils/                        # empty
├── features/
│   ├── auth/
│   │   ├── data/auth_repository.dart         # signUp/signIn/signOut/updateFullName/updateAvatarPath (merges user_metadata)
│   │   └── presentation/
│   │       ├── screens/                      # login_screen.dart, signup_screen.dart (both show Logo)
│   │       └── widgets/confirm_logout.dart   # shared logout confirmation (Profile + Settings)
│   ├── discovery/
│   │   ├── domain/home_location.dart                          # current device position + reverse-geocoded city
│   │   └── presentation/
│   │       ├── screens/home_feed_screen.dart                  # NAGARIK header, location, Nearby Issues, category shortcuts, Recent Reports, Report CTA
│   │       ├── screens/search_screen.dart                      # keyword/category/status/city/PIN/nearby filters + List/Map toggle
│   │       ├── providers/discovery_providers.dart              # homeLocationProvider, nearbyReportsProvider, geocodingServiceProvider
│   │       └── widgets/                                        # discovery_section_header.dart, location_indicator.dart, category_grid.dart
│   ├── profile/
│   │   ├── domain/avatar_upload_result.dart      # POST /users/me/avatar's response (avatar_path + signed avatar_url)
│   │   ├── data/profile_repository.dart          # fetchCurrentUser / uploadAvatar / removeAvatar
│   │   └── presentation/screens/
│   │       ├── profile_screen.dart       # identity header (real photo via ProfileAvatar) + stats + MY ACTIVITY/SETTINGS/LEGAL/ACCOUNT sections
│   │       └── edit_profile_screen.dart  # editable full name + profile photo (upload/replace/remove via a bottom sheet); email is read-only
│   ├── settings/presentation/screens/
│   │   ├── settings_screen.dart        # account info, theme preference, help/legal/logout
│   │   ├── help_support_screen.dart
│   │   ├── privacy_policy_screen.dart  # placeholder copy — see file header
│   │   ├── terms_screen.dart           # placeholder copy — see file header
│   │   └── about_screen.dart
│   └── reports/
│       ├── domain/
│       │   ├── report_draft.dart   # in-progress report form state
│       │   ├── report.dart         # a submitted report, as the backend returns it (incl. reference_id, is_saved)
│       │   ├── report_marker.dart  # lean pin data for the map (id/category/status/city/lat/lng only)
│       │   ├── report_share.dart   # buildReportShareText: the plain-text message for Report Detail's Share action
│       │   ├── report_stats.dart   # per-status counts, GET /reports/stats
│       │   ├── report_timeline.dart # maps a ReportStatus onto the status timeline's stages
│       │   └── reports_page.dart   # one paginated page of GET /reports results (Step 7/8)
│       ├── data/
│       │   ├── reports_repository.dart # submitReport / getReport / getReports / getReportMarkers / getReportStats / saveReport / unsaveReport / getSavedReports
│       │   ├── location_service.dart   # geolocator wrapper (Step 6)
│       │   └── geocoding_service.dart  # reverse-geocodes a position into a city name (native OS geocoder, no API key)
│       └── presentation/
│           ├── screens/create_report_screen.dart # Category -> Description -> Location -> Photos -> Review
│           ├── screens/report_detail_screen.dart # full detail: reference id, city/PIN/coords, timeline, Share + Save/Unsave app-bar actions
│           ├── screens/my_reports_screen.dart    # bottom-nav tab: My Reports (All/Submitted/In Review/Resolved chips)
│           ├── screens/saved_reports_screen.dart # Profile/drawer -> Saved Reports (real data; swipe to remove)
│           └── widgets/
│               ├── report_card.dart               # reusable report card (feed/search/My Reports/Saved Reports; optional thumbnail/reference id/date)
│               ├── report_map.dart                # OpenStreetMap-tiled map, pins colored by status (Search's Map view)
│               └── report_marker_preview_sheet.dart # compact preview on marker tap; lazily fetches full detail, links to Report Detail
└── shared/widgets/
    ├── app_button.dart          # AppButton (primary/secondary/outlined/text, loading state)
    ├── app_text_field.dart      # AppTextField
    ├── app_card.dart            # AppCard (brightness-aware: light mode unchanged, adds dark support)
    ├── status_badge.dart        # StatusBadge (colored by ReportStatus)
    ├── status_timeline.dart     # StatusTimeline (vertical progress timeline, Report Detail)
    ├── primary_app_bar.dart     # PrimaryAppBar (showLogo: true on Home's app bar)
    ├── logo.dart                # Logo: the one official NAGARIK mark, everywhere it appears
    ├── profile_avatar.dart      # ProfileAvatar: the user's photo, or an initial-letter fallback
    ├── loading_view.dart        # LoadingView
    ├── error_view.dart          # ErrorView (message + optional Retry); ErrorView.forError distinguishes network vs. API errors
    ├── empty_view.dart          # EmptyView (icon + title + message + optional action); .noReports/.noSavedReports/.noNearbyReports/.searchNoResults presets
    ├── section_header.dart      # SectionHeader (all-caps group label)
    ├── settings_list_tile.dart  # SettingsListTile (icon + title + trailing chevron/checkmark)
    ├── settings_section.dart    # SettingsSection (grouped SettingsListTiles in one card)
    ├── stat_tile.dart           # StatTile (big number + label, Profile's stats strip)
    └── static_content_screen.dart # StaticContentScreen (shared layout for Privacy/Terms/About/Help; optional `header` slot, used by About for the Logo)
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
this is standard Flutter behavior, not a bug in this app. The same camera/
photo-library permissions also cover Edit Profile's photo picker (Official
Logo & User Profile Photo upgrade) — no separate declaration needed.

## App icons

`pubspec.yaml` has a `flutter_launcher_icons:` block already pointing at
`assets/images/nagarik_logo.png`, covering Android, iOS, web, macOS, and
Windows. Like the native permissions above, there's nothing for it to
generate into yet — this repository has never been through `flutter
create` and has no `android/`/`ios/`/`web/`/`macos/`/`windows/` folders for
it to write icons into. Once you've run `flutter create .` (see
"Prerequisites" above), generate the icons with:

```bash
dart run flutter_launcher_icons
```

Re-run it any time `assets/images/nagarik_logo.png` changes — it's a
one-shot generator, not something that stays in sync automatically.

## Navigation (hybrid bottom nav + drawer)

- **Bottom tabs** (`StatefulShellRoute`, four only — Report Sharing, Saved
  Reports & Final Feature Polish upgrade): **Home** (`/home`), **Search**
  (`/search`), **My Reports** (`/my-reports`), **Profile** (`/profile`) —
  each keeps its own stack/scroll position when switching tabs. My Reports
  moved here from a screen previously pushed off Profile
  (`/profile/my-reports`, now removed) — same screen and data, just
  promoted to a primary tab; Profile's own "My Reports" tile now switches
  tabs (`context.go('/my-reports')`) instead of pushing a second copy.
- **App drawer** (`core/routing/app_drawer.dart`, opened via the hamburger
  icon on each of the four tabs above): the complete feature menu — Home,
  Search/Discover, My Reports, Saved Reports, Report Issue, Map/Nearby,
  Settings, Help & Support, Privacy Policy, Terms & Conditions, About
  NAGARIK, Logout. Every entry reuses an existing route (nothing here is a
  screen built only for the drawer); "Map / Nearby" opens Search
  pre-switched to "Near me" + the Map view (`/search?nearby=true&view=map`)
  rather than being a screen of its own.
- Pushed full-screen (no bottom nav): **Login** (`/login`), **Signup**
  (`/signup`), **Report an Issue** (`/report/create`), **Report Details**
  (`/report/:id`), **Edit Profile** (`/profile/edit`), **Saved Reports**
  (`/profile/saved-reports`), **Settings** (`/settings`), **Help & Support**
  (`/help`), **Privacy Policy** (`/legal/privacy`), **Terms & Conditions**
  (`/legal/terms`), **About NAGARIK** (`/about`).
- A "Report Issue" FAB is always visible over the tabs — kept as a FAB
  rather than a fifth bottom-nav destination, per the brief's "do not
  overcrowd the bottom navigation."

The whole app is auth-gated: every route above except `/login`/`/signup`
requires a signed-in user, enforced by a single `redirect` callback in
`core/routing/app_router.dart`, driven by Supabase's real auth state (its
`onAuthStateChange` stream feeds a `refreshListenable`, so sign-in and
sign-out both re-run the check immediately, with no extra navigation code
at either call site). The app therefore always opens to Login/Signup for a
signed-out user, and a "Log out" action anywhere lands back on `/login`
automatically.

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
- **Map (Location Discovery & Home upgrade):** `flutter_map` + `latlong2` —
  renders OpenStreetMap tiles with no API key or native platform
  configuration, used for Search's Map view
- **Reverse geocoding (Location Discovery & Home upgrade):** `geocoding` —
  wraps the native OS geocoder to turn the device's current coordinates
  into a city name ("📍 Bhopal") for Home's location indicator; no API key,
  no new backend call
- **Sharing (Report Sharing, Saved Reports & Final Feature Polish
  upgrade):** `share_plus` — the platform's native share sheet for Report
  Detail's Share action; pinned to its 7.x line for its simple, stable
  `Share.share(text)` static API

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

## Home & Location Discovery upgrade

- **Home** (`home_feed_screen.dart`) now shows, top to bottom: a greeting +
  current-location indicator, a tappable search shortcut, a horizontally
  scrolling **Nearby Issues** section (real device GPS + backend data — no
  mock coordinates or reports), an **Explore by Category** grid (Roads,
  Streetlights, Sanitation, Water, Electricity, Safety, Other), a **Recent
  Reports** list, and a **Report Issue** CTA. Each section's "See all" /
  category tile navigates to `/search` with a query parameter
  (`?nearby=true`, `?category=road`, `?all=true`), which `SearchScreen`
  picks up to run the matching search automatically.
- **Location states** — permission request, permission denied, location
  unavailable, loading, and retry — are all just `homeLocationProvider`'s
  `AsyncValue` (loading/data/error) rendered by `LocationIndicator`; "Retry"
  invalidates that provider. If location fails or permission is denied, only
  the Nearby Issues section is affected — the rest of Home (including Recent
  Reports) keeps working normally.
- **List/Map toggle** — once a search has run, Search shows a segmented
  List/Map control. List renders the existing report cards. Map
  (`ReportMap`, via `flutter_map`) plots real report coordinates as pins
  colored by status; tapping a pin opens `ReportMarkerPreviewSheet`, a
  compact preview that lazily fetches the full report and can push through
  to Report Detail. Map markers come from the new lean `GET /reports/markers`
  endpoint (id/category/status/city/coordinates only — no description or
  images), so switching to Map doesn't pull down data the map doesn't need.

See `docs/ARCHITECTURE.md` at the project root for the rationale behind the
auth-token flow between Flutter, FastAPI, and Supabase, and section 17 for
the full set of decisions behind this upgrade.

## Report Sharing, Saved Reports & Final Feature Polish

- **Share** — Report Detail's app bar gained a Share icon that opens the
  platform's native share sheet with a plain-text message: NAGARIK's name,
  the report's reference id, category, a trimmed description, city, and
  status. Deliberately excludes anything that could identify or locate
  whoever filed the report (no `user_id`, no exact GPS coordinates).
- **Save/Unsave** — Report Detail's app bar also gained a bookmark
  icon (outline = not saved, filled = saved) backed by real
  `POST`/`DELETE /reports/{id}/save` calls. Saving/unsaving is idempotent
  on the backend, so the button never needs to check state before acting.
  **Saved Reports** (Profile -> My Activity -> Saved Reports, also in the
  app drawer) now lists real bookmarked reports via `GET /reports/saved`,
  using the same `ReportCard` as every other list, with swipe-to-remove.
- **Error states** — `ErrorView.forError(error, ...)` distinguishes a
  network failure (no response reached the server) from a server-returned
  error, with a different icon and message for each, used across Report
  Detail, My Reports, Saved Reports, Search, Profile, Edit Profile, and
  Settings.
- **Empty states** — `EmptyView.noReports()`, `.noSavedReports()`,
  `.noNearbyReports()`, and `.searchNoResults()` give each of those
  situations one consistent icon/title/message instead of every screen
  writing its own.
- **Navigation** — see "Navigation (hybrid bottom nav + drawer)" above.

See `docs/ARCHITECTURE.md` section 18 for the full set of decisions behind
this upgrade, including why each backend addition was (or wasn't) needed.

## Official Logo & User Profile Photo upgrade

- **Logo** — the real NAGARIK mark (`assets/images/nagarik_logo.png`)
  replaces every placeholder, through one reusable `Logo` widget: Login,
  Signup, the startup splash (`SplashScreen`, shown while `app.dart` loads
  `.env`/Supabase), the Home app bar (`PrimaryAppBar(showLogo: true)`), the
  navigation drawer's header, and About NAGARIK.
- **Profile photo** — Edit Profile's avatar has a small camera-badge button
  opening Take Photo / Choose from Gallery / Remove Photo (the last only
  when a photo exists). Photos upload to a new private `avatars` Storage
  bucket via `POST /users/me/avatar`, downscaled client-side first
  (`maxWidth: 1024, imageQuality: 85`). `ProfileAvatar` shows the real photo
  everywhere the user's identity appears (Edit Profile, the Profile tab,
  the drawer header) and falls back to an initial-letter avatar when
  there's no photo, it's still loading, or its signed URL has expired.
- **`AuthRepository`'s metadata-merge fix** — the same `user_metadata` that
  stores `full_name` now also stores `avatar_path`, and Supabase Auth's
  `updateUser(data: ...)` *replaces* that object rather than merging it
  (see `docs/ARCHITECTURE.md` section 19 for the confirming source). Both
  `updateFullName` and the new `updateAvatarPath` now go through one
  private helper that merges the change into the user's existing metadata
  first, so setting one field never silently erases the other.
- **App icons** — see "App icons" above.

See `docs/ARCHITECTURE.md` section 19 for the full set of decisions behind
this upgrade, including the Storage bucket/RLS design and why the backend
never writes `user_metadata` itself.
