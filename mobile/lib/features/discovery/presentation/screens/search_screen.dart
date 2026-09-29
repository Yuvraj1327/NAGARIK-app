import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/reports/data/location_service.dart';
import 'package:nagarik/features/reports/domain/reports_page.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_card.dart';
import 'package:nagarik/shared/widgets/app_text_field.dart';
import 'package:nagarik/shared/widgets/empty_view.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/loading_view.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';

/// Search tab (Step 8): keyword search plus category, status, city/PIN, and
/// "near me" filters against `GET /reports`, matching the discovery
/// requirements from the project brief. A search runs when the keyword
/// field is submitted, a chip filter changes, or the "Nearby" toggle
/// resolves a location — never on every keystroke.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

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

  bool _hasSearched = false;
  Future<ReportsPage>? _resultsFuture;

  void _runSearch() {
    setState(() {
      _hasSearched = true;
      _resultsFuture = ref.read(reportsRepositoryProvider).getReports(
            category: _category,
            status: _status,
            city: _cityController.text,
            pinCode: _pinController.text,
            search: _searchController.text,
            latitude: _nearby ? _latitude : null,
            longitude: _nearby ? _longitude : null,
          );
    });
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
      body: Column(
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
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _SearchResults(hasSearched: _hasSearched, resultsFuture: _resultsFuture)),
        ],
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
  const _SearchResults({required this.hasSearched, required this.resultsFuture});

  final bool hasSearched;
  final Future<ReportsPage>? resultsFuture;

  @override
  Widget build(BuildContext context) {
    if (!hasSearched || resultsFuture == null) {
      return const EmptyView(
        icon: Icons.travel_explore_outlined,
        title: 'Search for civic reports',
        message: 'Find reports by keyword, category, status, city, PIN code, or near you.',
      );
    }

    return FutureBuilder<ReportsPage>(
      future: resultsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Searching…');
        }
        if (snapshot.hasError) {
          return const ErrorView(message: 'Could not search reports. Please try again.');
        }

        final page = snapshot.data!;
        if (page.items.isEmpty) {
          return const EmptyView(
            icon: Icons.search_off_outlined,
            title: 'No matching reports',
            message: 'Try a different keyword or loosen your filters.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: page.items.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final report = page.items[index];
            return ReportCard(
              title: report.category.label,
              description: report.description,
              category: report.category,
              status: report.status,
              city: report.city,
              pinCode: report.pinCode,
              onTap: () => context.push('/report/${report.id}'),
            );
          },
        );
      },
    );
  }
}
