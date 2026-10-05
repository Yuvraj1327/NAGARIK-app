import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as latlong;

import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/core/routing/app_drawer.dart';
import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/reports/data/location_service.dart';
import 'package:nagarik/features/reports/domain/report_marker.dart';
import 'package:nagarik/features/reports/domain/reports_page.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_card.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_map.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_marker_preview_sheet.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
import 'package:nagarik/shared/widgets/app_button.dart';
import 'package:nagarik/shared/widgets/app_text_field.dart';
import 'package:nagarik/shared/widgets/empty_view.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/loading_view.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';
import 'package:nagarik/shared/widgets/responsive_center.dart';
import 'package:nagarik/shared/widgets/skeleton.dart';

/// Roughly the geographic center of India — only ever used as the map's
/// starting point when a search has results but no device location to
/// center on (e.g. a category filter with no "Near me"), so the map opens
/// somewhere reasonable rather than the middle of the ocean at (0, 0).
const _fallbackMapCenter = latlong.LatLng(20.5937, 78.9629);

enum _ResultsView { list, map }

/// Search tab: keyword search plus category, status, city/PIN, and "near
/// me" filters against `GET /reports` — the one screen whose results cover
/// all three of the brief's discovery modes (nearby, city-wise, PIN-code-
/// wise), so this is also where the List/Map toggle for "nearby/discovery
/// results" lives, rather than building a second, separate results screen.
///
/// [initialCategoryName], [initialNearby], and [initialShowAll] let Home's
/// section shortcuts ("Explore by Category", Nearby Issues' "See all",
/// Recent Reports' "See all") land here pre-filtered instead of the app
/// needing a second copy of this filtering/results logic — see
/// `app_router.dart`'s `/search` route, which parses these from the URL's
/// query parameters.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.initialCategoryName,
    this.initialNearby = false,
    this.initialShowAll = false,
    this.initialView,
  });

  final String? initialCategoryName;
  final bool initialNearby;
  final bool initialShowAll;

  /// `"map"` opens straight into the Map view instead of the default List
  /// view — used by the app drawer's "Map / Nearby" entry (`?view=map`,
  /// alongside `?nearby=true`). Any other value (including null/absent)
  /// keeps the default List view.
  final String? initialView;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _cityController = TextEditingController();
  final _pinController = TextEditingController();

  ReportCategory? _category;
  ReportStatus? _status;
  bool _nearby = false;
  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;

  _ResultsView _view = _ResultsView.list;
  bool _hasSearched = false;
  Future<ReportsPage>? _resultsFuture;
  Future<List<ReportMarker>>? _markersFuture;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategoryName != null) {
      for (final candidate in ReportCategory.values) {
        if (candidate.name == widget.initialCategoryName) {
          _category = candidate;
          break;
        }
      }
    }
    if (widget.initialView == 'map') {
      _view = _ResultsView.map;
    }
    if (widget.initialNearby) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toggleNearby(true));
    } else if (_category != null || widget.initialShowAll) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch());
    }
  }

  void _runSearch() {
    setState(() {
      _hasSearched = true;
      if (_view == _ResultsView.map) {
        _markersFuture = ref.read(reportsRepositoryProvider).getReportMarkers(
              category: _category,
              status: _status,
              city: _cityController.text,
              pinCode: _pinController.text,
              search: _searchController.text,
              latitude: _nearby ? _latitude : null,
              longitude: _nearby ? _longitude : null,
            );
      } else {
        _resultsFuture = ref.read(reportsRepositoryProvider).getReports(
              category: _category,
              status: _status,
              city: _cityController.text,
              pinCode: _pinController.text,
              search: _searchController.text,
              latitude: _nearby ? _latitude : null,
              longitude: _nearby ? _longitude : null,
            );
      }
    });
  }

  /// Switching List/Map fetches the shape the newly-selected view needs
  /// (a report list was never asked for map markers, or vice versa) —
  /// exactly one fetch for the mode being switched to, not a background
  /// prefetch of both on every filter change.
  void _setView(_ResultsView view) {
    if (_view == view) return;
    setState(() => _view = view);
    if (_hasSearched) _runSearch();
  }

  Future<void> _toggleNearby(bool enabled) async {
    if (!enabled) {
      setState(() {
        _nearby = false;
        _latitude = null;
        _longitude = null;
      });
      if (_hasSearched) _runSearch();
      return;
    }

    setState(() => _isFetchingLocation = true);
    try {
      final position = await ref.read(locationServiceProvider).getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _nearby = true;
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      _runSearch();
    } on LocationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const PrimaryAppBar(title: 'Search'),
      drawer: const AppDrawer(),
      body: ResponsiveCenter(
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              // The filter panel scrolls within a cap (rather than growing
              // unbounded) so it can never overflow on a short screen or
              // with the keyboard open, and always leaves room for results.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.62),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D12213A),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm + 4,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: _buildFilters(),
                  ),
                ),
              ),
              Expanded(
                child: _SearchResults(
                  view: _view,
                  hasSearched: _hasSearched,
                  resultsFuture: _resultsFuture,
                  markersFuture: _markersFuture,
                  nearbyCenter: _nearby && _latitude != null && _longitude != null
                      ? latlong.LatLng(_latitude!, _longitude!)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Filters, top to bottom: keyword search → category → status → location
  /// (Near Me, City, PIN code) → Search action (→ List/Map toggle once
  /// there are results). Every chip filter re-runs the search on tap, as
  /// before; the Search button covers the typed City/PIN/keyword fields.
  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search by keyword, e.g. "pothole"',
            prefixIcon: Icon(Icons.search),
            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
            isDense: true,
          ),
          onSubmitted: (_) => _runSearch(),
        ),
        const _FilterSection(label: 'Category'),
        // Single scrolling row: eight chips would otherwise wrap onto three
        // lines and push the results far down the screen.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: _category == null,
                onSelected: () {
                  setState(() => _category = null);
                  _runSearch();
                },
              ),
              for (final category in ReportCategory.values) ...[
                const SizedBox(width: _chipGap),
                _FilterChip(
                  label: category.label,
                  icon: category.icon,
                  selected: _category == category,
                  onSelected: () {
                    setState(() => _category = category);
                    _runSearch();
                  },
                ),
              ],
            ],
          ),
        ),
        const _FilterSection(label: 'Status'),
        Wrap(
          spacing: _chipGap,
          runSpacing: _chipGap,
          children: [
            _FilterChip(
              label: 'Any status',
              selected: _status == null,
              onSelected: () {
                setState(() => _status = null);
                _runSearch();
              },
            ),
            for (final status in ReportStatus.values)
              _FilterChip(
                label: status.label,
                selected: _status == status,
                onSelected: () {
                  setState(() => _status = status);
                  _runSearch();
                },
              ),
          ],
        ),
        const _FilterSection(label: 'Location'),
        _FilterChip(
          label: 'Near Me',
          icon: Icons.my_location_outlined,
          loading: _isFetchingLocation,
          selected: _nearby,
          onSelected: () => _toggleNearby(!_nearby),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: AppTextField(
                label: 'City',
                controller: _cityController,
                prefixIcon: Icons.location_city_outlined,
                maxLength: 100,
                dense: true,
                showCounter: false,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: AppTextField(
                label: 'PIN code',
                controller: _pinController,
                prefixIcon: Icons.pin_drop_outlined,
                keyboardType: TextInputType.number,
                maxLength: 6,
                dense: true,
                showCounter: false,
                textInputAction: TextInputAction.search,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(label: 'Search', icon: Icons.search, onPressed: _runSearch),
        if (_hasSearched) ...[
          const SizedBox(height: AppSpacing.sm + 4),
          Align(
            alignment: Alignment.centerRight,
            child: SegmentedButton<_ResultsView>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(
                  value: _ResultsView.list,
                  label: Text('List'),
                  icon: Icon(Icons.view_list_outlined),
                ),
                ButtonSegment(
                  value: _ResultsView.map,
                  label: Text('Map'),
                  icon: Icon(Icons.map_outlined),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (selection) => _setView(selection.first),
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cityController.dispose();
    _pinController.dispose();
    super.dispose();
  }
}

const double _chipGap = AppSpacing.sm;

/// A bold section label with consistent spacing above and below, used to
/// separate the filter groups (Category / Status / Location).
class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

/// The one chip style every Search filter uses, so Category, Status, and
/// Near Me all share the same height, shape, and selected look: a filled
/// brand-blue pill when selected, a white bordered pill otherwise.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.loading = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  /// Swaps the icon for a small spinner and disables the chip (Near Me
  /// while the device location is being fetched).
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = selected
        ? AppColors.onPrimary
        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary);

    return ChoiceChip(
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      shape: const StadiumBorder(),
      side: BorderSide(
        color: selected
            ? AppColors.primary
            : (isDark ? AppColors.darkBorder : AppColors.border),
      ),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      selectedColor: AppColors.primary,
      avatar: loading
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
            )
          : (icon != null ? Icon(icon, size: 16, color: foreground) : null),
      label: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: foreground),
      ),
      selected: selected,
      onSelected: loading ? null : (_) => onSelected(),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.view,
    required this.hasSearched,
    required this.resultsFuture,
    required this.markersFuture,
    required this.nearbyCenter,
  });

  final _ResultsView view;
  final bool hasSearched;
  final Future<ReportsPage>? resultsFuture;
  final Future<List<ReportMarker>>? markersFuture;

  /// The device's location when "Near me" is active, so the map can center
  /// on it; null otherwise (the map then centers on the results themselves,
  /// or on [_fallbackMapCenter] if there are none to center on).
  final latlong.LatLng? nearbyCenter;

  @override
  Widget build(BuildContext context) {
    if (!hasSearched) {
      // Scrollable so the placeholder can't overflow when the filter panel
      // leaves only a short strip for it on a small screen.
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const EmptyView(
              icon: Icons.travel_explore_outlined,
              title: 'Search for civic reports',
              message: 'Find reports by keyword, category, status, city, PIN code, or near you.',
            ),
          ),
        ),
      );
    }

    return view == _ResultsView.map
        ? _MapResults(markersFuture: markersFuture, nearbyCenter: nearbyCenter)
        : _ListResults(resultsFuture: resultsFuture);
  }
}

class _ListResults extends StatelessWidget {
  const _ListResults({required this.resultsFuture});

  final Future<ReportsPage>? resultsFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReportsPage>(
      future: resultsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonReportList(count: 4);
        }
        if (snapshot.hasError) {
          return ErrorView.forError(
            snapshot.error!,
            fallbackMessage: 'Could not search reports. Please try again.',
          );
        }

        final page = snapshot.data!;
        if (page.items.isEmpty) {
          return const EmptyView.searchNoResults();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: page.items.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final report = page.items[index];
            return FadeSlideIn(
              delay: Duration(milliseconds: 30 * index),
              child: ReportCard(
                title: report.category.label,
                description: report.description,
                category: report.category,
                status: report.status,
                city: report.city,
                pinCode: report.pinCode,
                referenceId: report.referenceId,
                imageUrl: report.imageUrls.isNotEmpty ? report.imageUrls.first : null,
                date: report.createdAt,
                onTap: () => context.push('/report/${report.id}'),
              ),
            );
          },
        );
      },
    );
  }
}

class _MapResults extends StatelessWidget {
  const _MapResults({required this.markersFuture, required this.nearbyCenter});

  final Future<List<ReportMarker>>? markersFuture;
  final latlong.LatLng? nearbyCenter;

  latlong.LatLng _centerFor(List<ReportMarker> markers) {
    if (nearbyCenter != null) return nearbyCenter!;
    if (markers.isEmpty) return _fallbackMapCenter;
    final avgLat = markers.map((m) => m.latitude).reduce((a, b) => a + b) / markers.length;
    final avgLng = markers.map((m) => m.longitude).reduce((a, b) => a + b) / markers.length;
    return latlong.LatLng(avgLat, avgLng);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReportMarker>>(
      future: markersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading map…');
        }
        if (snapshot.hasError) {
          return ErrorView.forError(
            snapshot.error!,
            fallbackMessage: 'Could not load the map. Please try again.',
          );
        }

        final markers = snapshot.data!;
        if (markers.isEmpty) {
          return const EmptyView(
            icon: Icons.map_outlined,
            title: 'No matching reports to show on the map',
            message: 'Try a different keyword or loosen your filters.',
          );
        }

        final center = _centerFor(markers);
        return ReportMap(
          // Forces the map to recreate (and re-center) when a new search
          // resolves to a meaningfully different result set, rather than
          // silently keeping the previous camera position — flutter_map
          // otherwise manages its own camera state across rebuilds of the
          // "same" widget.
          key: ValueKey('${center.latitude},${center.longitude},${markers.length}'),
          markers: markers,
          center: center,
          onMarkerTap: (marker) => ReportMarkerPreviewSheet.show(context, marker),
        );
      },
    );
  }
}
