import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/core/utils/date_format.dart';
import 'package:nagarik/shared/widgets/app_card.dart';
import 'package:nagarik/shared/widgets/status_badge.dart';

/// A single report's card, used in the home feed, search results, "My
/// Reports", and the create-report review step.
///
/// [referenceId], [imageUrl], and [date] are optional because the
/// create-report review step shows a not-yet-submitted draft, which has
/// none of the three yet (no reference id is assigned — and none should be
/// implied — until the report actually exists in the database).
class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.city,
    required this.pinCode,
    this.referenceId,
    this.imageUrl,
    this.date,
    this.onTap,
  });

  final String title;
  final String description;
  final ReportCategory category;
  final ReportStatus status;
  final String city;
  final String pinCode;

  /// Human-readable report reference (e.g. "NGR-2026-00001"), shown in the
  /// card's footer when available.
  final String? referenceId;

  /// A signed thumbnail URL for the report's first photo, if it has one.
  /// When null, the card shows the category icon only, same as before this
  /// field existed.
  final String? imageUrl;

  /// Shown, date-only, in the card's footer alongside [referenceId] when
  /// given (typically the report's created date).
  final DateTime? date;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasFooter = referenceId != null || date != null;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null) ...[
                _Thumbnail(imageUrl: imageUrl!),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(category.icon, size: 20, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            '$city · $pinCode',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasFooter) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  referenceId ?? '',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary, letterSpacing: 0.3),
                ),
                if (date != null)
                  Text(
                    formatReportDate(date!),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl});

  final String imageUrl;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: _size,
          height: _size,
          color: AppColors.border,
        ),
        errorWidget: (context, url, error) => Container(
          width: _size,
          height: _size,
          color: AppColors.border,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
