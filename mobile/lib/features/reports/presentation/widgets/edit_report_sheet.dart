import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/network/api_exception.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/l10n/app_localizations.dart';
import 'package:nagarik/features/reports/data/reports_repository.dart';
import 'package:nagarik/features/reports/domain/report.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';

/// Bottom sheet for editing one of the caller's own reports (category,
/// description, city/PIN, location and photos). Status is never editable.
/// Returns true via `Navigator.pop` when the report was saved.
class EditReportSheet extends ConsumerStatefulWidget {
  const EditReportSheet({super.key, required this.report});

  final Report report;

  @override
  ConsumerState<EditReportSheet> createState() => _EditReportSheetState();
}

class _EditReportSheetState extends ConsumerState<EditReportSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _description = TextEditingController(text: widget.report.description);
  late final _city = TextEditingController(text: widget.report.city);
  late final _pin = TextEditingController(text: widget.report.pinCode);
  late ReportCategory _category = widget.report.category;
  late double? _lat = widget.report.latitude;
  late double? _lng = widget.report.longitude;
  bool _locationChanged = false;
  final _removed = <String>[];
  final _added = <XFile>[];
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    _city.dispose();
    _pin.dispose();
    super.dispose();
  }

  int get _photoCount => widget.report.imagePaths.length - _removed.length + _added.length;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addPhotos() async {
    final l10n = AppLocalizations.of(context);
    final slots = ReportsRepository.maxImages - _photoCount;
    if (slots <= 0) {
      _message(l10n.repPhotoLimit(ReportsRepository.maxImages));
      return;
    }
    try {
      final picked = await ImagePicker().pickMultiImage(limit: slots < 2 ? null : slots);
      if (picked.isNotEmpty && mounted) {
        setState(() => _added.addAll(picked.take(slots)));
      }
    } catch (_) {
      _message(l10n.repPhotoLibraryFailed);
    }
  }

  Future<void> _useCurrentLocation() async {
    final l10n = AppLocalizations.of(context);
    try {
      final position = await ref.read(locationServiceProvider).getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _locationChanged = true;
      });
    } catch (_) {
      _message(l10n.repLocationFailed);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(reportsRepositoryProvider).updateReport(
            widget.report.id,
            category: _category,
            description: _description.text.trim(),
            city: _city.text.trim(),
            pinCode: _pin.text.trim(),
            latitude: _locationChanged ? _lat : null,
            longitude: _locationChanged ? _lng : null,
            removeImagePaths: _removed,
            newImages: _added,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      _message(error is ApiException ? error.message : l10n.repUpdateFailed);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.repEditTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<ReportCategory>(
                initialValue: _category,
                decoration: InputDecoration(labelText: l10n.repCategory),
                items: [
                  for (final c in ReportCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.localizedLabel(l10n))),
                ],
                onChanged: (c) => setState(() => _category = c ?? _category),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _description,
                maxLines: 4,
                maxLength: 2000,
                decoration: InputDecoration(labelText: l10n.repDescription),
                validator: (v) => (v ?? '').trim().length < 10
                    ? l10n.repDescMin10
                    : null,
              ),
              TextFormField(
                controller: _city,
                maxLength: 100,
                decoration: InputDecoration(labelText: l10n.repCity),
                validator: (v) => (v ?? '').trim().isEmpty ? l10n.repEnterCity : null,
              ),
              TextFormField(
                controller: _pin,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(labelText: l10n.repPinCode),
                validator: (v) =>
                    RegExp(r'^[0-9]{6}$').hasMatch((v ?? '').trim()) ? null : l10n.repEnterPin,
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _lat == null
                          ? l10n.repNoMapLocation
                          : l10n.repLocationValue(
                              _lat!.toStringAsFixed(4), _lng!.toStringAsFixed(4)),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : _useCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: Text(l10n.repUseCurrent),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.repPhotosHeader(_photoCount, ReportsRepository.maxImages),
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (var i = 0; i < report.imagePaths.length; i++)
                    if (!_removed.contains(report.imagePaths[i]) && i < report.imageUrls.length)
                      _Thumb(
                        image: CachedNetworkImageProvider(report.imageUrls[i]),
                        onRemove: () => setState(() => _removed.add(report.imagePaths[i])),
                      ),
                  for (final file in _added)
                    _Thumb(
                      image: FileImage(File(file.path)),
                      onRemove: () => setState(() => _added.remove(file)),
                    ),
                  if (_photoCount < ReportsRepository.maxImages)
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _addPhotos,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(l10n.repAdd),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.repSaveChanges),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.image, required this.onRemove});

  final ImageProvider image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image(image: image, width: 72, height: 72, fit: BoxFit.cover),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: InkWell(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 10,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
