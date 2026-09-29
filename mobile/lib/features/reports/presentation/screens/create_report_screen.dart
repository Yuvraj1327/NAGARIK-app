import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/core/network/api_exception.dart';
import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/reports/data/location_service.dart';
import 'package:nagarik/features/reports/data/reports_repository.dart';
import 'package:nagarik/features/reports/domain/report_draft.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_card.dart';
import 'package:nagarik/shared/widgets/app_button.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';

/// The full report-submission flow: Category -> Description -> Location ->
/// Photos -> Review -> Submit.
///
/// As of Step 5/6, every step is fully real: location uses the device's
/// actual GPS (with proper permission handling), photos come from the
/// real camera/gallery, and submitting actually creates the report on the
/// backend (uploading images to Supabase Storage and inserting the row).
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
  final _descriptionFormKey = GlobalKey<FormState>();
  final _locationFormKey = GlobalKey<FormState>();

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onStepContinue() {
    if (_currentStep == 0 && _draft.category == null) {
      _showMessage('Please select a category to continue.');
      return;
    }
    if (_currentStep == 1 && !(_descriptionFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_currentStep == 2 && !(_locationFormKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_currentStep < _stepCount - 1) {
      setState(() => _currentStep += 1);
    } else {
      _submitDraft();
    }
  }

  void _onStepCancel() {
    if (_isSubmitting) return;
    if (_currentStep == 0) {
      context.pop();
      return;
    }
    setState(() => _currentStep -= 1);
  }

  Future<void> _submitDraft() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(reportsRepositoryProvider).submitReport(_draft);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Report submitted'),
          content: const Text(
            'Thank you — your report has been submitted and is now marked as Submitted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      context.go('/home');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PrimaryAppBar(title: 'Report an Issue'),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: _isSubmitting ? null : _onStepContinue,
        onStepCancel: _onStepCancel,
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: _currentStep == _stepCount - 1 ? 'Submit Report' : 'Continue',
                  isLoading: _currentStep == _stepCount - 1 && _isSubmitting,
                  onPressed: details.onStepContinue,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: _isSubmitting ? null : details.onStepCancel,
                child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
              ),
            ],
          ),
        ),
        steps: [
          Step(
            title: const Text('Category'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _CategoryStep(
              selected: _draft.category,
              onSelected: (category) => setState(() => _draft.category = category),
            ),
          ),
          Step(
            title: const Text('Description'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _DescriptionStep(formKey: _descriptionFormKey, draft: _draft),
          ),
          Step(
            title: const Text('Location'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: _LocationStep(
              formKey: _locationFormKey,
              draft: _draft,
              locationService: ref.read(locationServiceProvider),
            ),
          ),
          Step(
            title: const Text('Photos'),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.indexed,
            content: _ImagesStep(draft: _draft),
          ),
          Step(
            title: const Text('Review'),
            isActive: _currentStep >= 4,
            state: StepState.indexed,
            content: _ReviewStep(draft: _draft),
          ),
        ],
      ),
    );
  }
}

class _CategoryStep extends StatelessWidget {
  const _CategoryStep({required this.selected, required this.onSelected});

  final ReportCategory? selected;
  final ValueChanged<ReportCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: ReportCategory.values.map((category) {
        final isSelected = category == selected;
        return ChoiceChip(
          label: Text(category.label),
          avatar: Icon(
            category.icon,
            size: 18,
            color: isSelected ? AppColors.onPrimary : AppColors.textSecondary,
          ),
          selected: isSelected,
          onSelected: (_) => onSelected(category),
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(color: isSelected ? AppColors.onPrimary : AppColors.textPrimary),
        );
      }).toList(),
    );
  }
}

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

class _LocationStep extends StatefulWidget {
  const _LocationStep({
    required this.formKey,
    required this.draft,
    required this.locationService,
  });

  final GlobalKey<FormState> formKey;
  final ReportDraft draft;
  final LocationService locationService;

  @override
  State<_LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<_LocationStep> {
  late final TextEditingController _cityController =
      TextEditingController(text: widget.draft.city);
  late final TextEditingController _pinController =
      TextEditingController(text: widget.draft.pinCode);
  bool _isFetchingLocation = false;

  Future<void> _useCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      final position = await widget.locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        widget.draft.latitude = position.latitude;
        widget.draft.longitude = position.longitude;
      });
    } on LocationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = widget.draft.latitude != null && widget.draft.longitude != null;

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _cityController,
            textInputAction: TextInputAction.next,
            // Mirrors the backend's max_length=100 on this field (Step 9).
            maxLength: 100,
            onChanged: (value) => widget.draft.city = value,
            decoration: const InputDecoration(labelText: 'City'),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'City is required.' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            onChanged: (value) => widget.draft.pinCode = value,
            decoration: const InputDecoration(labelText: 'PIN code'),
            validator: (value) {
              final pin = value?.trim() ?? '';
              if (pin.isEmpty) return 'PIN code is required.';
              if (!RegExp(r'^[0-9]{6}$').hasMatch(pin)) return 'Enter a valid 6-digit PIN code.';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _isFetchingLocation ? null : _useCurrentLocation,
            icon: _isFetchingLocation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_outlined),
            label: Text(_isFetchingLocation ? 'Getting location…' : 'Use current location'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasCoordinates
                ? 'Coordinates: ${widget.draft.latitude!.toStringAsFixed(5)}, '
                    '${widget.draft.longitude!.toStringAsFixed(5)}'
                : 'Coordinates: not set (optional)',
            style: Theme.of(context).textTheme.bodySmall,
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

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.draft});

  final ReportDraft draft;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Review your report before submitting.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        ReportCard(
          title: draft.category?.label ?? 'Uncategorized',
          description: draft.description.isEmpty ? 'No description provided.' : draft.description,
          category: draft.category ?? ReportCategory.other,
          status: ReportStatus.submitted,
          city: draft.city.isEmpty ? '—' : draft.city,
          pinCode: draft.pinCode.isEmpty ? '—' : draft.pinCode,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            const Icon(Icons.photo_outlined, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '${draft.images.length} photo(s) attached',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            const Icon(Icons.my_location_outlined, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              draft.latitude != null
                  ? '${draft.latitude!.toStringAsFixed(5)}, ${draft.longitude!.toStringAsFixed(5)}'
                  : 'No coordinates captured',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}
