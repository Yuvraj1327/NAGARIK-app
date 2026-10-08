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

**UI Polish & Motion Upgrade:** purely visual — no constructor, field, or
widget behavior any existing test asserts on changed, so no test file
needed updating. See the "UI Polish & Motion Upgrade" section near the end
of this file and `docs/ARCHITECTURE.md` section 20 for what changed and how
it was verified (the same static-check approach as every prior step —
there is still no Flutter SDK in this environment).

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
│   │   ├── app_router.dart               # go_router config: shell + top-level routes (pushed routes use fadeSlidePage)
│   │   ├── page_transitions.dart         # fadeSlidePage: shared fade+slide CustomTransitionPage (UI Polish upgrade)
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
    ├── animations/
    │   ├── fade_slide_in.dart   # FadeSlideIn: one-shot fade+slide entrance, optional stagger delay (UI Polish upgrade)
    │   └── pressable_scale.dart # PressableScale: small press-down scale via Listener, used by AppCard/AppButton/the FAB
    ├── skeleton.dart            # SkeletonBox/SkeletonReportCard/SkeletonReportList/SkeletonReportRow/SkeletonStatsStrip (UI Polish upgrade)
    ├── responsive_center.dart   # ResponsiveCenter: caps content width on wide (web/macOS) viewports, no-op on phone width
    ├── app_button.dart          # AppButton (primary/secondary/outlined/text, loading state, press-scale feedback)
    ├── app_text_field.dart      # AppTextField
    ├── app_card.dart            # AppCard (brightness-aware; soft drop shadow + press-scale feedback)
    ├── status_badge.dart        # StatusBadge (colored by ReportStatus)
    ├── status_timeline.dart     # StatusTimeline (vertical progress timeline, Report Detail)
    ├── primary_app_bar.dart     # PrimaryAppBar (showLogo: true on Home's app bar)
    ├── logo.dart                # Logo: the one official NAGARIK mark, everywhere it appears
    ├── profile_avatar.dart      # ProfileAvatar: the user's photo, or an initial-letter fallback
    ├── loading_view.dart        # LoadingView
    ├── error_view.dart          # ErrorView (message + optional Retry); ErrorView.forError distinguishes network vs. API errors; soft icon backdrop + entrance fade
    ├── empty_view.dart          # EmptyView (icon + title + message + optional action); .noReports/.noSavedReports/.noNearbyReports/.searchNoResults presets; soft icon backdrop + entrance fade
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

**Onboarding redesign's `permission_handler`** reads these exact same
manifest/`Info.plist` entries, plus `android.permission.CAMERA` in
`AndroidManifest.xml` (already added) — without it `Permission.camera`
always reports denied on Android. On iOS
only, `permission_handler` additionally needs each permission group it
uses enabled via a build macro, since its iOS plugin ships every
permission type behind a compile flag to keep apps that don't need them
smaller. Once `ios/` exists, add to **`ios/Podfile`** (inside the
`post_install do |installer|` block's `installer.pods_project.targets.each
do |target|` loop, alongside any entries already there):

```ruby
target.build_configurations.each do |config|
  config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
  config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << [
    'PERMISSION_LOCATION=1',
    'PERMISSION_CAMERA=1',
  ]
end
```

Without this, the "Permissions" step's two "Allow" buttons compile fine
but the underlying iOS plugin silently reports every permission as
`denied` — again, standard `permission_handler` behavior, not a bug here.

## Google Maps setup (required for the Report Issue "Place" step map)

Report Issue redesign: the "Place" step's map (`LocationPickerMap`) uses
`google_maps_flutter`, a **different** mapping package from the
`flutter_map`/OpenStreetMap one Search/Nearby use (deliberately — see
`report_map.dart` and `pubspec.yaml`'s own comments for why that one avoids
exactly what this section is about). `google_maps_flutter` needs a
billing-enabled Google Maps API key, configured natively per platform —
none of which exists yet since this project has never been through
`flutter create` (see "Native permissions" above for the same caveat).
Once you've scaffolded `android/`/`ios/`:

1. **Create an API key** in Google Cloud Console (APIs & Services →
   Credentials → Create Credentials → API key), with the **Maps SDK for
   Android** and **Maps SDK for iOS** APIs enabled for it, and billing
   enabled on the project (Google requires billing even within the free
   monthly usage tier). Restrict the key to those two APIs and, ideally,
   to your app's Android package name/SHA-1 and iOS bundle ID once you
   have them.
2. **`android/app/src/main/AndroidManifest.xml`** — add inside
   `<application>`:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_ANDROID_API_KEY" />
   ```
3. **`ios/Runner/AppDelegate.swift`** — add the import and one line inside
   `application(_:didFinishLaunchingWithOptions:)`, before it returns:
   ```swift
   import GoogleMaps
   // ...
   GMSServices.provideAPIKey("YOUR_IOS_API_KEY")
   ```

Without this, the Place step's map renders a blank/grey tile area at
runtime (a `google_maps_flutter`/Google Maps SDK behavior, not a bug in
this app's Dart code) — everything else in report creation (category,
photos, description, City/PIN fields, submission) keeps working normally
either way, since those never depend on the map actually rendering tiles.

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

## UI Polish & Motion Upgrade

A visual/UX pass across the whole app — no color, navigation, or
backend/business-logic change. See `docs/ARCHITECTURE.md` section 20 for
the full write-up; in short:

- **New shared primitives** (`shared/widgets/animations/fade_slide_in.dart`,
  `shared/widgets/animations/pressable_scale.dart`,
  `shared/widgets/skeleton.dart`, `core/routing/page_transitions.dart`,
  `shared/widgets/responsive_center.dart`) — all dependency-free, continuing
  this project's "avoid unnecessary packages" precedent instead of adding
  an animation or shimmer package.
- **Stronger typography** — `AppTypography` gained heavier heading weights,
  tighter heading letter-spacing, more body line-height, and two new
  entries (`labelMedium`/`labelSmall`); `AppColors` is untouched.
- **Premium cards & buttons** — `AppCard` gained a soft drop shadow;
  `AppCard` (when tappable) and `AppButton` both gained a small press-down
  scale via `PressableScale`, picked up automatically everywhere those
  shared widgets are already used.
- **Motion** — every pushed route (login/signup, report create/detail, edit
  profile, saved reports, settings, help, legal, about) now fades + slides
  in via `fadeSlidePage`; Home's sections and every report-card list
  stagger in with `FadeSlideIn`; the bottom-nav tabs keep their existing
  instant `IndexedStack` switch, unchanged.
- **Skeleton loading states** — report lists and the Profile stats strip
  show shaped placeholders (`SkeletonReportList`/`SkeletonReportRow`/
  `SkeletonStatsStrip`) instead of a bare spinner while loading.
- **Responsive** — every screen's body is wrapped in `ResponsiveCenter`, so
  a browser tab or a resized macOS window gets a centered, width-capped
  column instead of text stretched edge-to-edge; phone layouts are
  unchanged (the cap is never reached at phone width).

See `docs/ARCHITECTURE.md` section 20 for the complete rationale and the
full list of touched screens.

## NAGARIK Theme Upgrade

Client-supplied photography and an exact new brand palette, Android + iOS
only, with no auth/business-logic change. See `docs/ARCHITECTURE.md`
section 21 for the full write-up; in short:

- **New brand palette** — `AppColors`' `primary`/`background`/`border`/
  `textPrimary` now use the exact given hex values, plus two new tokens
  (`primaryBright`, `accentTeal`) for colors the old palette had no field
  for. Dark theme and status colors are unchanged.
- **Category photos** — the 6 supplied photos (resized to optimized 480×480
  JPEGs in `assets/images/category_*.jpg`) now appear on Home → Explore by
  Category and Report Issue → Category selection, via a new
  `ReportCategory.imagePath` getter; `other` keeps its icon as a fallback.
- **Login/Signup hero** — both screens now open with the supplied hero
  photo (`assets/images/auth_hero.jpg`) as a fixed-height banner that never
  covers the form, with a fast fade+slide+scale entrance for the image and
  a staggered, field-by-field entrance for the form beneath it.

See `docs/ARCHITECTURE.md` section 21 for the complete rationale and the
full list of touched files.

## Auth Welcome screen & "Continue with Google"

The app now opens on a new full-screen Auth Welcome screen
(`AuthWelcomeScreen`) when signed out, with two actions: "Log In" (goes to
the existing Login screen, which still links on to Register) and
"Continue with Google". See `docs/ARCHITECTURE.md` section 22 for the full
write-up; in short:

- **New auth gate entry point** — the router's `initialLocation` is now
  `/welcome` instead of `/login`, and signing out or an expired session
  now lands back on `/welcome`. Email/Password auth is unchanged.
- **Google sign-in** uses the platform's native account picker (via the
  `google_sign_in` package), not a web-redirect/browser flow, then hands
  the result to Supabase Auth's `signInWithIdToken`.
- **Focus-blur** — Login/Signup's hero photo now smoothly blurs and dims
  while any field on that screen is focused, and restores when it isn't.

### Google sign-in setup (required for "Continue with Google" to work)

Everything else in the app (Email/Password auth, every other screen) works
with **zero** setup here — this section only matters once you actually
want "Continue with Google" to succeed instead of showing its "not
configured yet" error.

1. **Enable the Google provider in Supabase**: Supabase Dashboard →
   Authentication → Providers → Google → toggle it on.
2. **Create OAuth client IDs in Google Cloud Console** (APIs & Services →
   Credentials → Create Credentials → OAuth client ID), one of each:
   - A **Web application** client — its Client ID is what both this app's
     `GOOGLE_WEB_CLIENT_ID` and Supabase's Google provider "Client ID"
     field should be set to (they must match: it's what Supabase checks
     the Google ID token's `aud` claim against). Supabase's Google
     provider page shows the exact Authorized redirect URI to add to this
     Web client.
   - An **iOS** client — bundle ID matching whatever you set up when you
     eventually run `flutter create` for this project (see "App icons"
     above for the equivalent android/ios-folder caveat). Its Client ID
     goes in `GOOGLE_IOS_CLIENT_ID`.
   - An **Android** client — SHA-1 fingerprint of your signing key +
     applicationId. This project has no native `android/` folder yet, so
     there's nothing to put the Android client's own ID into directly;
     creating it is still required so Google will issue tokens to your
     app's package name/fingerprint, but the ID token request itself is
     authenticated via the **Web** client's ID (`GOOGLE_WEB_CLIENT_ID`,
     passed as `GoogleSignIn(serverClientId: ...)`), per `google_sign_in`'s
     own setup docs.
3. **Set both values in `mobile/.env`**:
   ```
   GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
   GOOGLE_IOS_CLIENT_ID=your-ios-client-id.apps.googleusercontent.com
   ```
4. Once this project has been through `flutter create` (see this file's
   Prerequisites section), also add the standard native wiring
   `google_sign_in` documents for a project with real platform folders:
   iOS's `Info.plist` gets a `CFBundleURLTypes` entry with the iOS
   client's *reversed* client ID as the URL scheme; Android needs no extra
   manifest entry for this flow specifically, but double-check your
   release signing SHA-1 is registered on the Android OAuth client above
   before shipping a release build.

None of this blocks running the app today — leave both `.env` values blank
and everything works except the Google button, which shows a clear error
instead of crashing anything.

## Onboarding (first-run Welcome + 7 optional steps)

A first-time, signed-out launch now opens on a new onboarding flow —
Welcome, then Language / About / Mobile Number / Age / Data & Privacy /
Permissions / Preferences, each fully optional and skippable — before
handing off to the existing Auth Welcome screen (`/welcome`, unchanged).
See `docs/ARCHITECTURE.md` section 24 for the full write-up; in short:

- **Shown once**: completing or skipping the flow (at any point) saves a
  local "onboarding done" flag (`shared_preferences`, via the new
  `OnboardingService`) so it never shows again on this device, and a
  signed-in user never sees it at all.
- **Every step is optional** — Skip always works, Back always works, and
  nothing here blocks reaching the real app.
- **Location + Camera/Photos permissions** (Step 6) use real OS prompts
  via the new `permission_handler` dependency — see "Native permissions"
  above for the one-time iOS Podfile macro this needs.
- **The optional mobile number** (Step 3) is saved locally, then written
  into the real Supabase `user_metadata` the first time the person
  actually signs up/in afterward (`AuthRepository`) — never used for
  sign-in itself; Email/Password and "Continue with Google" are unchanged
  and remain the only two ways in.
- **Nothing added**: no SOS/emergency-contact/"I'm Safe" preference, no
  push notifications, no real in-app translation — see
  `docs/ARCHITECTURE.md` for why each was deliberately left out.

Nothing above blocks running the app today — the whole flow works with
zero configuration; only Step 6's two "Allow" buttons need the iOS Podfile
macro (once this project has a real `ios/` folder) to report anything
other than "denied" on iOS specifically.
