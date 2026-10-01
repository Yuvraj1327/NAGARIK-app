import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as latlong;

import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/core/routing/app_drawer.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/reports/data/location_service.dart';
import 'package:nagarik/features/reports/domain/report_marker.dart';
import 'package:nagarik/features/reports/domain/reports_page.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_card.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_map.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_marker_preview_sheet.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
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
    return Scaffold(
      appBar: const PrimaryAppBar(title: 'Search'),
      drawer: const AppDrawer(),
      body: ResponsiveCenter(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search by keyword, e.g. "pothole"',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _runSearch(),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('All categories'),
                      selected: _category == null,
                      onSelected: (_) {
                        setState(() => _category = null);
                        _runSearch();
                      },
                    ),
                    for (final category in ReportCategory.values)
                      ChoiceChip(
                        label: Text(category.label),
                        avatar: Icon(category.icon, size: 16),
                        selected: _category == category,
                        onSelected: (_) {
                          setState(() => _category = category);
                          _runSearch();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Any status'),
                      selected: _status == null,
                      onSelected: (_) {
                        setState(() => _status = null);
                        _runSearch();
                      },
                    ),
                    for (final status in ReportStatus.values)
                      ChoiceChip(
                        label: Text(status.label),
                        selected: _status == status,
                        onSelected: (_) {
                          setState(() => _status = status);
                          _runSearch();
                        },
                      ),
                    ChoiceChip(
                      label: _isFetchingLocation
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Near me'),
                      avatar: _isFetchingLocation
                          ? null
                          : const Icon(Icons.my_location_outlined, size: 16),
                      selected: _nearby,
                      onSelected: _isFetchingLocation ? null : _toggleNearby,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'City',
                        controller: _cityController,
                        maxLength: 100,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppTextField(
                        label: 'PIN code',
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.filled(
                      onPressed: _runSearch,
                      icon: const Icon(Icons.search),
                      tooltip: 'Search',
                    ),
                  ],
                ),
                if (_hasSearched) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SegmentedButton<_ResultsView>(
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
            ),
          ),
          const Divider(height: 1),
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
      return const EmptyView(
        icon: Icons.travel_explore_outlined,
        title: 'Search for civic reports',
        message: 'Find reports by keyword, category, status, city, PIN code, or near you.',
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
