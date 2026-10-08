import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:image_picker/image_picker.dart';

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
import 'package:nagarik/features/reports/presentation/widgets/report_step_indicator.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
import 'package:nagarik/shared/widgets/animations/pressable_scale.dart';
import 'package:nagarik/shared/widgets/app_button.dart';
import 'package:nagarik/shared/widgets/app_card.dart';
import 'package:nagarik/shared/widgets/responsive_center.dart';
import 'package:nagarik/shared/widgets/status_badge.dart';

/// Report Issue redesign: the full report-submission flow, now one
/// full-screen step at a time — Type -> Photo -> Place -> Details ->
/// Review -> Send — instead of the earlier vertical accordion `Stepper`,
/// matching the quality/structure of the reference screenshots supplied
/// with this request without copying their own branding, copy, or exact
/// visuals. Every step still writes into the same [ReportDraft] as before,
/// and submitting still goes through the existing, untouched
/// `ReportsRepository.submitReport` (real FastAPI + Supabase backend, no
/// mock data).
///
/// Every step's content is fully real: location uses the device's actual
/// GPS through the existing `LocationService` (now with an explicit
/// rationale card shown before the "locate me" button can trigger the real
/// OS permission prompt), the map is driven by real reverse geocoding
/// (`GeocodingService`), and photos come from the real camera/gallery
/// (unchanged from before this redesign).
class CreateReportScreen extends ConsumerStatefulWidget {
  const CreateReportScreen({super.key});

  @override
  ConsumerState<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends ConsumerState<CreateReportScreen> {
  static const int _stepCount = 5;

  int _currentStep = 0;
  bool _isSubmitting = false;
  final ReportDraft _draft = ReportDraft();
  final _placeFormKey = GlobalKey<FormState>();
  final _descriptionFormKey = GlobalKey<FormState>();

  /// Set once `_submitDraft` actually succeeds — from then on `build()`
  /// shows [_SuccessView] instead of the step flow. Holds the real `Report`
  /// the backend returned (reference id, id, status), never a placeholder.
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
    // An if/else-if chain rather than a `switch` on purpose: each branch
    // below only needs to *validate*, never to fall through to the next
    // step's check (standard Dart `switch` statements don't allow a
    // non-empty case to fall through to the next case without an explicit
    // `continue <label>;` anyway — only one case can ever apply per call
    // since `_currentStep` is a single value), so a plain chain is both
    // correct and simpler to read than a switch would be here.
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
        return _StepScaffold(
          key: const ValueKey(0),
          title: 'What do you want to report?',
          subtitle: 'Choose the category that best matches what you saw.',
          child: _CategoryStep(
            selected: _draft.category,
            onSelected: (category) => setState(() => _draft.category = category),
          ),
        );
      case 1:
        return _StepScaffold(
          key: const ValueKey(1),
          title: 'Add a photo',
          subtitle: 'Optional, but it helps a reviewer act on this faster.',
          child: _ImagesStep(draft: _draft),
        );
      case 2:
        return _StepScaffold(
          key: const ValueKey(2),
          title: 'Where is it?',
          subtitle: 'Drag the map or use your current location, then fine-tune the city and PIN below.',
          child: _PlaceStep(
            formKey: _placeFormKey,
            draft: _draft,
            locationService: ref.read(locationServiceProvider),
            geocodingService: ref.read(geocodingServiceProvider),
          ),
        );
      case 3:
        return _StepScaffold(
          key: const ValueKey(3),
          title: 'Tell us what you see',
          subtitle: 'A short, clear description helps it get verified faster.',
          child: _DescriptionStep(formKey: _descriptionFormKey, draft: _draft),
        );
      case 4:
      default:
        return _StepScaffold(
          key: const ValueKey(4),
          title: 'Review and send',
          subtitle: 'Check everything below before you submit.',
          child: _ReviewStep(
            draft: _draft,
            onEditStep: (step) => setState(() => _currentStep = step),
          ),
        );
    }
  }

  Widget _buildBottomBar() {
    final isLastStep = _currentStep == _stepCount - 1;
    final isPhotoStep = _currentStep == 1;

    return Row(
      children: [
        if (isPhotoStep) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _isSubmitting ? null : () => setState(() => _currentStep += 1),
              child: const Text('Skip'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          flex: isPhotoStep ? 2 : 1,
          child: AppButton(
            label: isLastStep ? 'Submit report' : 'Continue',
            isLoading: isLastStep && _isSubmitting,
            onPressed: _isSubmitting ? null : _onContinue,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final submitted = _submittedReport;
    if (submitted != null) {
      return _SuccessView(report: submitted);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs, AppSpacing.lg, AppSpacing.xs),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isSubmitting ? null : _onBack,
                    icon: Icon(_currentStep == 0 ? Icons.close : Icons.arrow_back),
                  ),
                  Expanded(
                    child: ReportStepIndicator(stepCount: _stepCount, currentStep: _currentStep),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ResponsiveCenter(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.03),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              child: _buildBottomBar(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared title + subtitle header above every step's own content —
/// `AnimatedSwitcher`'s child is keyed per step index (see `CreateReportScreen`
/// above), so this whole block cross-fades/slides in together as one unit
/// when the step changes.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({super.key, required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    );
  }
}

/// NAGARIK Theme upgrade: a grid of photo cards (one per [ReportCategory])
/// — unchanged by this redesign beyond moving into the new step shell.
class _CategoryStep extends StatelessWidget {
  const _CategoryStep({required this.selected, required this.onSelected});

  final ReportCategory? selected;
  final ValueChanged<ReportCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.82,
      children: [
        for (final category in ReportCategory.values)
          _CategoryOption(
            category: category,
            isSelected: category == selected,
            onTap: () => onSelected(category),
          ),
      ],
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? const Color(0x332088E8) : const Color(0x0F12213A),
                blurRadius: isSelected ? 14 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imagePath != null
                          ? Image.asset(imagePath, fit: BoxFit.cover)
                          : Container(
                              color: AppColors.primaryLight,
                              alignment: Alignment.center,
                              child: Icon(category.icon, size: 28, color: AppColors.primary),
                            ),
                      if (isSelected)
                        Container(
                          color: AppColors.primary.withOpacity(0.16),
                          padding: const EdgeInsets.all(4),
                          alignment: Alignment.topRight,
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: AppColors.primary,
                            child: Icon(Icons.check, size: 13, color: AppColors.onPrimary),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: isSelected ? AppColors.primaryLight : AppColors.surface,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Text(
                    category.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
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

/// Unchanged from before this redesign beyond moving into the new step
/// shell and getting a step-specific subtitle (see `_StepScaffold` above).
class _DescriptionStep extends StatefulWidget {
  const _DescriptionStep({required this.formKey, required this.draft});

  final GlobalKey<FormState> formKey;
  final ReportDraft draft;

  @override
  State<_DescriptionStep> createState() => _DescriptionStepState();
}

class _DescriptionStepState extends State<_DescriptionStep> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.draft.description);

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: TextFormField(
        controller: _controller,
        maxLines: 5,
        // Mirrors the backend's max_length=2000 on this field (Step 9
        // hardening, app/api/v1/endpoints/reports.py) — stopping the user
        // here is friendlier than letting them type a long description and
        // only finding out it's too long from a 422 on submit.
        maxLength: 2000,
        onChanged: (value) => widget.draft.description = value,
        decoration: const InputDecoration(
          labelText: 'Describe the issue',
          hintText: 'e.g. Large pothole near the bus stop causing traffic issues',
        ),
        validator: (value) {
          if (value == null || value.trim().length < 10) {
            return 'Please provide at least 10 characters.';
          }
          return null;
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Report Issue redesign: the "Place" step — a real Google Map
/// ([LocationPickerMap]) with a rationale card explaining why location is
/// asked for *before* its "locate me" button can trigger the real OS
/// permission prompt, plus City/PIN fields that auto-fill from reverse
/// geocoding the map's center but stay fully editable by hand.
///
/// Never invents a position: [ReportDraft.latitude]/[longitude] are only
/// ever set from [LocationPickerMap.onPositionChanged] — which itself only
/// fires after the person actually pans the map or taps "locate me" (see
/// that widget's doc comment) — so a report submitted without touching
/// this step simply has no coordinates, exactly as before this redesign.
class _PlaceStep extends StatefulWidget {
  const _PlaceStep({
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
  /// written into the draft (see this class's doc comment above).
  static const _defaultCenter = LatLng(22.9734, 78.6569);

  late final TextEditingController _cityController =
      TextEditingController(text: widget.draft.city);
  late final TextEditingController _pinController =
      TextEditingController(text: widget.draft.pinCode);

  bool _cityEditedByUser = false;
  bool _pinEditedByUser = false;
  String? _resolvedArea;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    // Field initializers can't read `widget` (it isn't attached yet at
    // that point) — these are evaluated here instead, once it is.
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
      _resolvedArea = place.city;
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

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = widget.draft.latitude != null;

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'NAGARIK only uses your location to place this report accurately. '
                    "It's captured the moment you move the map or tap the locate "
                    'button below — never in the background.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LocationPickerMap(
            initialPosition: _initialPosition,
            onPositionChanged: _onPositionChanged,
            locationService: widget.locationService,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasCoordinates ? Icons.place : Icons.touch_app_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _isResolving
                      ? 'Finding the area name…'
                      : !hasCoordinates
                          ? 'Pan the map or tap the locate button to set the exact spot.'
                          : (_resolvedArea != null
                              ? 'Others will see: $_resolvedArea'
                              : '${widget.draft.latitude!.toStringAsFixed(5)}, '
                                  '${widget.draft.longitude!.toStringAsFixed(5)}'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _cityController,
            textInputAction: TextInputAction.next,
            // Mirrors the backend's max_length=100 on this field (Step 9).
            maxLength: 100,
            onChanged: (value) {
              _cityEditedByUser = true;
              widget.draft.city = value;
            },
            decoration: const InputDecoration(labelText: 'City'),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'City is required.' : null,
          ),
          const SizedBox(height: AppSpacing.md),
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
    super.dispose();
  }
}

/// Unchanged from before this redesign beyond moving into the new step
/// shell and a step-specific subtitle.
class _ImagesStep extends StatefulWidget {
  const _ImagesStep({required this.draft});

  final ReportDraft draft;

  @override
  State<_ImagesStep> createState() => _ImagesStepState();
}

class _ImagesStepState extends State<_ImagesStep> {
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
        if (images.isEmpty)
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 32,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('0 photos added', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          )
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final image = images[index];
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.file(
                        File(image.path),
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => _removeAt(index),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isPicking ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isPicking ? null : _takePhoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Camera'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${images.length} of ${ReportsRepository.maxImages} photos added',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Report Issue redesign: each section shows what was entered for one step
/// with its own "Edit" link that jumps straight back to that step
/// ([onEditStep]) — replaces the old single `ReportCard` preview, which had
/// no way to edit an individual section without backing all the way
/// through the stepper.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.draft, required this.onEditStep});

  final ReportDraft draft;
  final ValueChanged<int> onEditStep;

  @override
  Widget build(BuildContext context) {
    final imagePath = draft.category?.imagePath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReviewSection(
          title: 'Type',
          onEdit: () => onEditStep(0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: imagePath != null
                    ? Image.asset(imagePath, width: 44, height: 44, fit: BoxFit.cover)
                    : Container(
                        width: 44,
                        height: 44,
                        color: AppColors.primaryLight,
                        alignment: Alignment.center,
                        child: Icon(
                          draft.category?.icon ?? Icons.category_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                draft.category?.label ?? 'Not selected',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ReviewSection(
          title: 'Photos',
          onEdit: () => onEditStep(1),
          child: draft.images.isEmpty
              ? Text('No photos added.', style: Theme.of(context).textTheme.bodyMedium)
              : SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: draft.images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (context, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.file(
                        File(draft.images[index].path),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ReviewSection(
          title: 'Place',
          onEdit: () => onEditStep(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                draft.city.isEmpty ? 'City not set' : draft.city,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                draft.pinCode.isEmpty ? 'PIN not set' : 'PIN ${draft.pinCode}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (draft.latitude != null)
                Text(
                  '${draft.latitude!.toStringAsFixed(5)}, ${draft.longitude!.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ReviewSection(
          title: 'Details',
          onEdit: () => onEditStep(3),
          child: Text(
            draft.description.isEmpty ? 'No description provided.' : draft.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.title, required this.onEdit, required this.child});

  final String title;
  final VoidCallback onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              TextButton(onPressed: onEdit, child: const Text('Edit')),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          child,
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
                  child: AppButton(
                    label: 'View report',
                    onPressed: () => context.go('/report/${report.id}'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 220),
                  child: AppButton(
                    label: 'View my reports',
                    variant: AppButtonVariant.outlined,
                    onPressed: () => context.go('/my-reports'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 250),
                  child: AppButton(
                    label: 'Back to Home',
                    variant: AppButtonVariant.text,
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
