import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/core/routing/app_drawer.dart';
import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/discovery/presentation/widgets/discovery_section_header.dart';
import 'package:nagarik/features/reports/data/location_service.dart';
import 'package:nagarik/features/reports/domain/report_marker.dart';
import 'package:nagarik/features/reports/domain/reports_page.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_card.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_map.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_marker_preview_sheet.dart';
import 'package:nagarik/l10n/app_localizations.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
import 'package:nagarik/shared/widgets/app_search_field.dart';
import 'package:nagarik/shared/widgets/empty_view.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/loading_view.dart';
import 'package:nagarik/shared/widgets/pill_button.dart';
import 'package:nagarik/shared/widgets/selectable_chip.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';
import 'package:nagarik/shared/widgets/responsive_center.dart';
import 'package:nagarik/shared/widgets/skeleton.dart';

/// Roughly the geographic center of India — only ever used as the map's
/// starting point when a search has results but no device location to
/// center on (e.g. a category filter with no "Near me"), so the map opens
/// somewhere reasonable rather than the middle of the ocean at (0, 0).
const _fallbackMapCenter = LatLng(20.5937, 78.9629);

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

  /// Filters are always visible in List view; in Map view they collapse
  /// behind a "Filters" toggle so the map keeps most of the screen.
  bool _filtersExpanded = false;

  void _selectCategory(ReportCategory? category) {
    setState(() => _category = category);
    _runSearch();
  }

  void _selectStatus(ReportStatus? status) {
    setState(() => _status = status);
    _runSearch();
  }

  void _clearKeyword() {
    _searchController.clear();
    if (_hasSearched) _runSearch();
  }

  Widget _buildFilters(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSearchField(
          controller: _searchController,
          hintText: l10n.searchKeywordHint,
          onSubmitted: (_) => _runSearch(),
          onClear: _clearKeyword,
        ),
        const SizedBox(height: AppSpacing.md),
        DiscoverySectionHeader(title: l10n.searchCategory),
        _ChipRow(
          children: [
            SelectableChip(
              label: l10n.searchAll,
              icon: Icons.grid_view_rounded,
              selected: _category == null,
              onTap: () => _selectCategory(null),
            ),
            for (final category in ReportCategory.values)
              SelectableChip(
                label: category.localizedLabel(l10n),
                icon: category.icon,
                selected: _category == category,
                onTap: () => _selectCategory(category),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        DiscoverySectionHeader(title: l10n.searchStatus),
        _ChipRow(
          children: [
            SelectableChip(
              label: l10n.searchAnyStatus,
              selected: _status == null,
              onTap: () => _selectStatus(null),
            ),
            for (final status in ReportStatus.values)
              SelectableChip(
                label: status.localizedLabel(l10n),
                selected: _status == status,
                onTap: () => _selectStatus(status),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Text(l10n.searchLocation, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableChip(
            label: l10n.searchNearMe,
            icon: Icons.my_location_outlined,
            selected: _nearby,
            isLoading: _isFetchingLocation,
            onTap: _isFetchingLocation ? null : () => _toggleNearby(!_nearby),
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Row(
          children: [
            Expanded(
              child: _LocationField(
                controller: _cityController,
                hintText: l10n.searchCity,
                icon: Icons.location_city_outlined,
                maxLength: 100,
                onSubmitted: _runSearch,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: _LocationField(
                controller: _pinController,
                hintText: l10n.searchPinCode,
                icon: Icons.pin_drop_outlined,
                maxLength: 6,
                keyboardType: TextInputType.number,
                onSubmitted: _runSearch,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        PillButton(label: l10n.searchSearchButton, onPressed: _runSearch),
      ],
    );
  }

  Widget _buildViewToggle() {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<_ResultsView>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: _ResultsView.list,
          label: Text(l10n.searchViewList),
          icon: const Icon(Icons.view_list_outlined),
        ),
        ButtonSegment(
          value: _ResultsView.map,
          label: Text(l10n.searchViewMap),
          icon: const Icon(Icons.map_outlined),
        ),
      ],
      selected: {_view},
      onSelectionChanged: (selection) => _setView(selection.first),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nearbyCenter = _nearby && _latitude != null && _longitude != null
        ? LatLng(_latitude!, _longitude!)
        : null;
    const pagePadding = EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0);

    Widget body;
    if (_view == _ResultsView.map) {
      final showFilters = _filtersExpanded || !_hasSearched;
      body = Column(
        children: [
          Padding(
            padding: pagePadding,
            child: Row(
              children: [
                Expanded(child: _buildViewToggle()),
                const SizedBox(width: AppSpacing.sm),
                SelectableChip(
                  label: l10n.searchFilters,
                  icon: Icons.tune_rounded,
                  selected: showFilters,
                  onTap: _hasSearched
                      ? () => setState(() => _filtersExpanded = !_filtersExpanded)
                      : null,
                ),
              ],
            ),
          ),
          if (showFilters)
            Flexible(
              flex: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _buildFilters(context),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            flex: 4,
            child: _SearchResults(
              view: _view,
              hasSearched: _hasSearched,
              resultsFuture: _resultsFuture,
              markersFuture: _markersFuture,
              nearbyCenter: nearbyCenter,
            ),
          ),
        ],
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: [
          _buildFilters(context),
          if (_hasSearched) ...[
            const SizedBox(height: AppSpacing.md),
            _buildViewToggle(),
          ],
          const SizedBox(height: AppSpacing.md),
          _SearchResults(
            view: _view,
            hasSearched: _hasSearched,
            resultsFuture: _resultsFuture,
            markersFuture: _markersFuture,
            nearbyCenter: nearbyCenter,
          ),
        ],
      );
    }

    return Scaffold(
      appBar: PrimaryAppBar(title: l10n.navSearch),
      drawer: const AppDrawer(activeRoute: '/search'),
      body: ResponsiveCenter(child: body),
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

/// A horizontally scrolling row of filter chips.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final child in children) ...[child, const SizedBox(width: AppSpacing.sm)],
        ],
      ),
    );
  }
}

/// A rounded text field with a leading icon, used for the City / PIN code
/// filters. No character counter — the limit is still enforced.
class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.maxLength,
    required this.onSubmitted,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final int maxLength;
  final TextInputType? keyboardType;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    OutlineInputBorder outline(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmitted(),
      decoration: InputDecoration(
        hintText: hintText,
        counterText: '',
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: AppSpacing.md),
        border: outline(border),
        enabledBorder: outline(border),
        focusedBorder: outline(AppColors.primary, 1.5),
      ),
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
  final LatLng? nearbyCenter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!hasSearched) {
      return SizedBox(
        height: 260,
        child: EmptyView(
          icon: Icons.travel_explore_outlined,
          title: l10n.searchPromptTitle,
          message: l10n.searchPromptMessage,
        ),
      );
    }

    return view == _ResultsView.map
        ? _MapResults(markersFuture: markersFuture, nearbyCenter: nearbyCenter)
        : _ListResults(resultsFuture: resultsFuture);
  }
}

/// List results are laid out inline (no nested scroll view) because they
/// live inside the Search screen's single scrolling column, beneath the
/// filters.
class _ListResults extends StatelessWidget {
  const _ListResults({required this.resultsFuture});

  final Future<ReportsPage>? resultsFuture;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<ReportsPage>(
      future: resultsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonReportList(count: 3, padding: EdgeInsets.zero);
        }
        if (snapshot.hasError) {
          return SizedBox(
            height: 260,
            child: ErrorView.forError(
              snapshot.error!,
              fallbackMessage: l10n.searchError,
            ),
          );
        }

        final page = snapshot.data!;
        if (page.items.isEmpty) {
          return const SizedBox(height: 260, child: EmptyView.searchNoResults());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.searchReportsFound(page.total),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            for (var index = 0; index < page.items.length; index++) ...[
              FadeSlideIn(
                delay: Duration(milliseconds: 30 * index),
                child: ReportCard(
                  title: page.items[index].category.localizedLabel(l10n),
                  description: page.items[index].description,
                  category: page.items[index].category,
                  status: page.items[index].status,
                  city: page.items[index].city,
                  pinCode: page.items[index].pinCode,
                  referenceId: page.items[index].referenceId,
                  imageUrl: page.items[index].imageUrls.isNotEmpty
                      ? page.items[index].imageUrls.first
                      : null,
                  date: page.items[index].createdAt,
                  onTap: () => context.push('/report/${page.items[index].id}'),
                ),
              ),
              if (index != page.items.length - 1) const SizedBox(height: AppSpacing.sm + 4),
            ],
          ],
        );
      },
    );
  }
}

class _MapResults extends StatelessWidget {
  const _MapResults({required this.markersFuture, required this.nearbyCenter});

  final Future<List<ReportMarker>>? markersFuture;
  final LatLng? nearbyCenter;

  LatLng _centerFor(List<ReportMarker> markers) {
    if (nearbyCenter != null) return nearbyCenter!;
    if (markers.isEmpty) return _fallbackMapCenter;
    final avgLat = markers.map((m) => m.latitude).reduce((a, b) => a + b) / markers.length;
    final avgLng = markers.map((m) => m.longitude).reduce((a, b) => a + b) / markers.length;
    return LatLng(avgLat, avgLng);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<ReportMarker>>(
      future: markersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingView(message: l10n.searchLoadingMap);
        }
        if (snapshot.hasError) {
          return ErrorView.forError(
            snapshot.error!,
            fallbackMessage: l10n.searchMapError,
          );
        }

        final markers = snapshot.data!;
        if (markers.isEmpty) {
          return EmptyView(
            icon: Icons.map_outlined,
            title: l10n.searchMapEmptyTitle,
            message: l10n.searchMapEmptyMessage,
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
