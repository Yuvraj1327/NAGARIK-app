import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/network/api_exception.dart';
import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:nagarik/features/reports/data/geocoding_service.dart';
import 'package:nagarik/features/reports/data/location_service.dart';
import 'package:nagarik/features/reports/data/reports_repository.dart';
import 'package:nagarik/features/reports/domain/report.dart';
import 'package:nagarik/features/reports/domain/report_draft.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/features/reports/presentation/widgets/location_picker_map.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_stepper.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
import 'package:nagarik/shared/widgets/animations/pressable_scale.dart';
import 'package:nagarik/shared/widgets/pill_button.dart';
import 'package:nagarik/shared/widgets/responsive_center.dart';
import 'package:nagarik/shared/widgets/status_badge.dart';

/// Report Issue flow, recreated from the supplied reference screens: a
/// numbered Type / Photo / Place / Details / Review stepper above one
/// full-width step at a time, pill buttons pinned to a bottom bar, and a
/// success screen with the real report reference. Every step still writes
/// into the same [ReportDraft] and submission still goes through the
/// existing `ReportsRepository.submitReport` (real FastAPI + Supabase —
/// no mock data).
class CreateReportScreen extends ConsumerStatefulWidget {
  const CreateReportScreen({super.key, this.initialCategoryName});

  /// Optional `ReportCategory.name` to preselect on the Type step — set by
  /// Home's category cards (`/report/create?category=road`). Unknown or
  /// absent values leave the step with nothing selected, as before.
  final String? initialCategoryName;

  @override
  ConsumerState<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends ConsumerState<CreateReportScreen> {
  static const int _stepCount = 5;
  static const List<String> _stepLabels = ['Type', 'Photo', 'Place', 'Details', 'Review'];

  int _currentStep = 0;
  bool _isSubmitting = false;
  final ReportDraft _draft = ReportDraft();

  @override
  void initState() {
    super.initState();
    final name = widget.initialCategoryName;
    if (name != null) {
      for (final candidate in ReportCategory.values) {
        if (candidate.name == name) {
          _draft.category = candidate;
          break;
        }
      }
    }
  }

  final _placeFormKey = GlobalKey<FormState>();
  final _descriptionFormKey = GlobalKey<FormState>();

  /// Set once `_submitDraft` succeeds — from then on `build()` shows
  /// [_SuccessView]. Holds the real `Report` the backend returned.
  Report? _submittedReport;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onBack() {
    if (_currentStep == 0) {
      context.pop();
      return;
    }
    setState(() => _currentStep -= 1);
  }

  void _onContinue() {
    // if-chain, not `switch`: a non-empty Dart `switch` case can't fall
    // through, and only one step is ever active per call anyway.
    if (_currentStep == 0 && _draft.category == null) {
      _showMessage('Please select a category to continue.');
      return;
    }
    if (_currentStep == 2 && !(_placeFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_currentStep == 3 && !(_descriptionFormKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_currentStep < _stepCount - 1) {
      setState(() => _currentStep += 1);
    } else {
      _submitDraft();
    }
  }

  Future<void> _submitDraft() async {
    setState(() => _isSubmitting = true);
    try {
      final submitted = await ref.read(reportsRepositoryProvider).submitReport(_draft);
      if (!mounted) return;
      setState(() => _submittedReport = submitted);
    } on DioException catch (error) {
      if (!mounted) return;
      final apiError = error.error;
      _showMessage(
        apiError is ApiException
            ? apiError.message
            : 'Could not submit your report. Please try again.',
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not submit your report. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildStepBody() {
    switch (_currentStep) {
      case 0:
        return _TypeStep(
          key: const ValueKey(0),
          selected: _draft.category,
          onSelected: (category) => setState(() => _draft.category = category),
        );
      case 1:
        return _PhotoStep(key: const ValueKey(1), draft: _draft);
      case 2:
        return _PlaceStep(
          key: const ValueKey(2),
          formKey: _placeFormKey,
          draft: _draft,
          locationService: ref.read(locationServiceProvider),
          geocodingService: ref.read(geocodingServiceProvider),
        );
      case 3:
        return _DetailsStep(key: const ValueKey(3), formKey: _descriptionFormKey, draft: _draft);
      case 4:
      default:
        return _ReviewStep(
          key: const ValueKey(4),
          draft: _draft,
          onEditStep: (step) => setState(() => _currentStep = step),
        );
    }
  }

  Widget _buildBottomBar() {
    final label = switch (_currentStep) {
      2 => 'Confirm place',
      4 => 'Send report',
      _ => 'Continue',
    };
    final primary = PillButton(
      label: label,
      isLoading: _currentStep == 4 && _isSubmitting,
      onPressed: _isSubmitting ? null : _onContinue,
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      child: _currentStep == 1
          ? Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: 'Skip',
                    variant: PillButtonVariant.outlined,
                    onPressed: () => setState(() => _currentStep += 1),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(flex: 2, child: primary),
              ],
            )
          : primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final submitted = _submittedReport;
    if (submitted != null) {
      return _SuccessView(report: submitted);
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs, AppSpacing.xs, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isSubmitting ? null : _onBack,
                    icon: Icon(_currentStep == 0 ? Icons.close : Icons.arrow_back_ios_new, size: 22),
                  ),
                  Expanded(
                    child: Text(
                      _currentStep == _stepCount - 1 ? 'Review and send' : 'Report an issue',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
              child: ReportStepper(labels: _stepLabels, currentStep: _currentStep),
            ),
            Expanded(
              child: ResponsiveCenter(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _buildStepBody(),
                  ),
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }
}

/// Bold step heading + optional subtitle used at the top of steps 2-4.
class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Step 1 — Type. A "Someone in danger? Call 112 first." notice, then the
/// category photo tiles with the label over the photo and a check badge on
/// the selected one.
class _TypeStep extends StatelessWidget {
  const _TypeStep({super.key, required this.selected, required this.onSelected});

  final ReportCategory? selected;
  final ValueChanged<ReportCategory> onSelected;

  Future<void> _call112() async {
    await launchUrl(Uri(scheme: 'tel', path: '112'));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.phone_outlined, size: 22, color: AppColors.textPrimary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                    children: const [
                      TextSpan(
                        text: 'Someone in danger? ',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: 'Call 112 first.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PressableScale(
                child: FilledButton(
                  onPressed: _call112,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  child: const Text('Call 112', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('What do you want to report?', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.0,
          children: [
            for (final category in ReportCategory.values)
              _TypeTile(
                category: category,
                isSelected: category == selected,
                onTap: () => onSelected(category),
              ),
          ],
        ),
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.category, required this.isSelected, required this.onTap});

  final ReportCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imagePath = category.imagePath;

    return PressableScale(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 3 : 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imagePath != null) ...[
                  Image.asset(imagePath, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x0012213A), Color(0x1A12213A), Color(0xCC12213A)],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ] else
                  Container(
                    color: AppColors.primaryLight,
                    alignment: Alignment.topLeft,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Icon(category.icon, size: 30, color: AppColors.primary),
                  ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: Text(
                    category.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: imagePath != null ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isSelected)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.check, size: 17, color: AppColors.onPrimary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Step 2 — Photo. A dark capture panel (shutter opens the real device
/// camera through `image_picker`; the thumbnail button opens the gallery)
/// plus the photos added so far. A live in-app viewfinder would need the
/// separate `camera` package; the system camera is used instead so no new
/// dependency is needed.
class _PhotoStep extends StatefulWidget {
  const _PhotoStep({super.key, required this.draft});

  final ReportDraft draft;

  @override
  State<_PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends State<_PhotoStep> {
  final _picker = ImagePicker();
  bool _isPicking = false;

  int get _remainingSlots => ReportsRepository.maxImages - widget.draft.images.length;

  Future<void> _pickFromGallery() async {
    if (_remainingSlots <= 0) {
      _showMessage('You can attach up to ${ReportsRepository.maxImages} photos.');
      return;
    }
    setState(() => _isPicking = true);
    try {
      final picked = await _picker.pickMultiImage(limit: _remainingSlots);
      if (picked.isNotEmpty && mounted) {
        setState(() => widget.draft.images.addAll(picked));
      }
    } catch (_) {
      _showMessage('Could not open the photo library. Please try again.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _takePhoto() async {
    if (_remainingSlots <= 0) {
      _showMessage('You can attach up to ${ReportsRepository.maxImages} photos.');
      return;
    }
    setState(() => _isPicking = true);
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null && mounted) {
        setState(() => widget.draft.images.add(photo));
      }
    } catch (_) {
      _showMessage('Could not open the camera. Please try again.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _removeAt(int index) {
    setState(() => widget.draft.images.removeAt(index));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.draft.images;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeading(
          title: 'Add a photo',
          subtitle: 'Optional, but it helps reviewers check faster. Keep a safe distance.',
        ),
        Container(
          height: 320,
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.photo_camera_outlined, size: 44, color: Color(0xFFCBD5E1)),
              const SizedBox(height: AppSpacing.sm),
              const Text('Camera', style: TextStyle(fontSize: 17, color: Color(0xFFCBD5E1))),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _isPicking ? null : _pickFromGallery,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white, width: 2),
                          color: const Color(0xFF1E2F4D),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: images.isEmpty
                            ? const Icon(Icons.photo_library_outlined, color: Colors.white, size: 24)
                            : Image.file(File(images.last.path), fit: BoxFit.cover),
                      ),
                    ),
                    PressableScale(
                      child: GestureDetector(
                        onTap: _isPicking ? null : _takePhoto,
                        child: Container(
                          width: 76,
                          height: 76,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: _isPicking
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 56, height: 56),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (images.isNotEmpty) ...[
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(images[index].path),
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeAt(index),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.textPrimary,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          '${images.length} of ${ReportsRepository.maxImages} added.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// Step 3 — Place. Search field, a Google Map with a fixed center pin
/// ("Drag the map to adjust"), a locate button, and an "Others will see"
/// card — plus the City/PIN fields the backend requires, auto-filled from
/// reverse geocoding but always editable.
///
/// Never invents a position: [ReportDraft.latitude]/[longitude] are only
/// set from [LocationPickerMap.onPositionChanged], which only fires after
/// a real pan or "locate me" tap.
class _PlaceStep extends StatefulWidget {
  const _PlaceStep({
    super.key,
    required this.formKey,
    required this.draft,
    required this.locationService,
    required this.geocodingService,
  });

  final GlobalKey<FormState> formKey;
  final ReportDraft draft;
  final LocationService locationService;
  final GeocodingService geocodingService;

  @override
  State<_PlaceStep> createState() => _PlaceStepState();
}

class _PlaceStepState extends State<_PlaceStep> {
  /// Geographic center of India — a neutral starting view only, never
  /// written into the draft.
  static const _defaultCenter = LatLng(22.9734, 78.6569);

  late final TextEditingController _cityController =
      TextEditingController(text: widget.draft.city);
  late final TextEditingController _pinController =
      TextEditingController(text: widget.draft.pinCode);
  final TextEditingController _searchController = TextEditingController();
  final LocationPickerController _mapController = LocationPickerController();

  // Plain field initializers can't read `widget`; set in initState.
  bool _cityEditedByUser = false;
  bool _pinEditedByUser = false;
  bool _isResolving = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _cityEditedByUser = widget.draft.city.isNotEmpty;
    _pinEditedByUser = widget.draft.pinCode.isNotEmpty;
  }

  LatLng get _initialPosition {
    final lat = widget.draft.latitude;
    final lng = widget.draft.longitude;
    return (lat != null && lng != null) ? LatLng(lat, lng) : _defaultCenter;
  }

  Future<void> _onPositionChanged(LatLng position) async {
    widget.draft.latitude = position.latitude;
    widget.draft.longitude = position.longitude;

    setState(() => _isResolving = true);
    final place = await widget.geocodingService.placeFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (!mounted) return;
    setState(() {
      _isResolving = false;
      if (place.city != null && !_cityEditedByUser) {
        _cityController.text = place.city!;
        widget.draft.city = place.city!;
      }
      if (place.postalCode != null && !_pinEditedByUser) {
        _pinController.text = place.postalCode!;
        widget.draft.pinCode = place.postalCode!;
      }
    });
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);
    final result = await widget.geocodingService.coordinatesFromQuery(trimmed);
    if (!mounted) return;
    setState(() => _isSearching = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't find that place. Try a nearby landmark or area.")),
      );
      return;
    }
    await _mapController.moveTo(LatLng(result.latitude, result.longitude));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final city = widget.draft.city.trim();
    final hasCoordinates = widget.draft.latitude != null;

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepHeading(title: 'Where is it?'),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Search an area or landmark',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: AppColors.border, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: AppColors.border, width: 2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LocationPickerMap(
            initialPosition: _initialPosition,
            onPositionChanged: _onPositionChanged,
            locationService: widget.locationService,
            controller: _mapController,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.55),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Others will see', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  _isResolving
                      ? 'Finding the area…'
                      : (city.isNotEmpty ? city : 'Move the map to set the area'),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  hasCoordinates
                      ? 'Pin set at ${widget.draft.latitude!.toStringAsFixed(5)}, '
                          '${widget.draft.longitude!.toStringAsFixed(5)}.'
                      : 'Drag the map or tap the locate button — your location is only '
                          'used when you ask for it.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _cityController,
            textInputAction: TextInputAction.next,
            // Mirrors the backend's max_length=100 on this field.
            maxLength: 100,
            onChanged: (value) {
              _cityEditedByUser = true;
              setState(() => widget.draft.city = value);
            },
            decoration: const InputDecoration(labelText: 'City / area'),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'City is required.' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            onChanged: (value) {
              _pinEditedByUser = true;
              widget.draft.pinCode = value;
            },
            decoration: const InputDecoration(labelText: 'PIN code'),
            validator: (value) {
              final pin = value?.trim() ?? '';
              if (pin.isEmpty) return 'PIN code is required.';
              if (!RegExp(r'^[0-9]{6}$').hasMatch(pin)) return 'Enter a valid 6-digit PIN code.';
              return null;
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cityController.dispose();
    _pinController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

/// Step 4 — Details. Description with a live counter, plus the two quick
/// optional questions (answers are appended to the description — see
/// [ReportDraft.submissionDescription]).
class _DetailsStep extends StatefulWidget {
  const _DetailsStep({super.key, required this.formKey, required this.draft});

  final GlobalKey<FormState> formKey;
  final ReportDraft draft;

  @override
  State<_DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends State<_DetailsStep> {
  static const int _maxLength = 500;

  late final TextEditingController _controller =
      TextEditingController(text: widget.draft.description);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeading(title: 'Tell us what you see'),
        Text('Short description', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Form(
          key: widget.formKey,
          child: TextFormField(
            controller: _controller,
            minLines: 5,
            maxLines: 5,
            maxLength: _maxLength,
            onChanged: (value) => widget.draft.description = value,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                Row(
              children: [
                Expanded(
                  child: Text(
                    "Don't include names or phone numbers",
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Text('$currentLength / $maxLength', style: theme.textTheme.bodySmall),
              ],
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Large pothole near the bus stop causing traffic issues',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: AppColors.border, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: AppColors.border, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().length < 10) {
                return 'Please provide at least 10 characters.';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Is anyone hurt or in danger?', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        _ChoiceRow(
          options: const ['No', 'Yes'],
          selected: widget.draft.anyoneHurt,
          onChanged: (value) => setState(() => widget.draft.anyoneHurt = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Is it still happening?', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        _ChoiceRow(
          options: const ['Yes', 'No', 'Not sure'],
          selected: widget.draft.stillHappening,
          onChanged: (value) => setState(() => widget.draft.stillHappening = value),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// A row of pill-shaped single-choice buttons. Tapping the selected one
/// again clears the answer (both questions are optional).
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.options, required this.selected, required this.onChanged});

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(options[i] == selected ? null : options[i]),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: options[i] == selected ? AppColors.primaryLight : AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: options[i] == selected ? AppColors.primary : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Text(
                  options[i],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          if (i != options.length - 1) const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// Step 5 — Review. One bordered card of sections, each with its own
/// "Edit" link back to the step that owns it.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep({super.key, required this.draft, required this.onEditStep});

  final ReportDraft draft;
  final ValueChanged<int> onEditStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = draft.category;
    final imagePath = category?.imagePath;
    final photoCount = draft.images.length;
    final extras = <String>[
      if (draft.anyoneHurt != null) (draft.anyoneHurt == 'No' ? 'No one hurt' : 'Someone hurt or in danger'),
      if (draft.stillHappening != null)
        (draft.stillHappening == 'Yes'
            ? 'Still happening'
            : draft.stillHappening == 'No'
                ? 'No longer happening'
                : 'Not sure if still happening'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 2),
          ),
          child: Column(
            children: [
              _ReviewRow(
                onEdit: () => onEditStep(0),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: imagePath != null
                      ? Image.asset(imagePath, width: 64, height: 64, fit: BoxFit.cover)
                      : Container(
                          width: 64,
                          height: 64,
                          color: AppColors.primaryLight,
                          alignment: Alignment.center,
                          child: Icon(category?.icon ?? Icons.category_outlined, color: AppColors.primary),
                        ),
                ),
                label: 'Type',
                value: category?.label ?? 'Not selected',
                valueIsLarge: true,
              ),
              const Divider(height: 1),
              _ReviewRow(
                onEdit: () => onEditStep(1),
                label: 'Photos',
                value: photoCount == 0 ? 'None added' : '$photoCount photo${photoCount == 1 ? '' : 's'}',
                footer: photoCount == 0
                    ? null
                    : SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: photoCount,
                          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
                          itemBuilder: (context, index) => ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(draft.images[index].path),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
              ),
              const Divider(height: 1),
              _ReviewRow(
                onEdit: () => onEditStep(2),
                label: 'Place shown to others',
                value: draft.city.isEmpty ? 'City not set' : draft.city,
                valueIsLarge: true,
                footerText: draft.pinCode.isEmpty ? null : 'PIN ${draft.pinCode}',
              ),
              const Divider(height: 1),
              _ReviewRow(
                onEdit: () => onEditStep(3),
                label: 'Description',
                value: draft.description.trim().isEmpty ? 'No description provided.' : draft.description.trim(),
                footerText: extras.isEmpty ? null : extras.join(' · '),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.55),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const Icon(Icons.fact_check_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Check the details above — you can edit any section before sending.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Please only report real issues.', style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.onEdit,
    required this.label,
    required this.value,
    this.leading,
    this.valueIsLarge = false,
    this.footer,
    this.footerText,
  });

  final VoidCallback onEdit;
  final String label;
  final String value;
  final Widget? leading;
  final bool valueIsLarge;
  final Widget? footer;
  final String? footerText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: valueIsLarge
                      ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)
                      : theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (footer != null) ...[const SizedBox(height: AppSpacing.sm), footer!],
                if (footerText != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(footerText!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            child: const Text('Edit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Report Issue redesign: shown in place of the step flow once
/// `_submitDraft` actually succeeds — a dedicated success screen (not the
/// old `AlertDialog`) with the real reference id the backend assigned and
/// clear next steps, per the brief's explicit "show the real generated
/// Report ID" and "provide navigation to My Reports / report details".
/// Reuses the existing `/report/:id`, `/my-reports`, and `/home` routes —
/// no new route was added for this.
class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveCenter(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: AppSpacing.xl),
                FadeSlideIn(
                  duration: const Duration(milliseconds: 420),
                  beginScale: 0.88,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.check_circle, color: AppColors.success, size: 56),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 90),
                  child: Text(
                    'Report submitted',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: Text(
                    "Thank you — we've received it and it's now marked as "
                    'Submitted. Keep your reference ID to track its progress.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Text('Reference ID', style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: AppSpacing.xs),
                        SelectableText(
                          report.referenceId,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: AppColors.primary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        StatusBadge(status: report.status),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 190),
                  child: PillButton(
                    label: 'View report',
                    onPressed: () => context.go('/report/${report.id}'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 220),
                  child: PillButton(
                    label: 'View my reports',
                    variant: PillButtonVariant.outlined,
                    onPressed: () => context.go('/my-reports'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 250),
                  child: PillButton(
                    label: 'Back to Home',
                    variant: PillButtonVariant.soft,
                    onPressed: () => context.go('/home'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
