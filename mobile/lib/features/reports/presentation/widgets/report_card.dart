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
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    // Premium card layout (Home / Search / My Reports redesign): a rounded
    // leading tile — the report's real first photo when it has one, the
    // category icon on a light-blue tile otherwise — then the category
    // title with the status pill (and a chevron when tappable) on the
    // right, the description, the "city · PIN" line, and a divider-separated
    // footer with the reference id and date.
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                _Thumbnail(imageUrl: imageUrl!)
              else
                _CategoryTile(category: category),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        StatusBadge(status: status),
                        if (onTap != null)
                          const Padding(
                            padding: EdgeInsets.only(left: 2),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppColors.textDisabled,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
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
                            style: secondary,
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
            const SizedBox(height: AppSpacing.sm + 4),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (referenceId != null) ...[
                  const Icon(
                    Icons.description_outlined,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      referenceId!,
                      style: secondary?.copyWith(letterSpacing: 0.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const Spacer(),
                if (date != null) ...[
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(formatReportDate(date!), style: secondary),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Light-blue rounded tile with the category's icon — the leading visual
/// when a report has no photo.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final ReportCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _Thumbnail._size,
      height: _Thumbnail._size,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      alignment: Alignment.center,
      child: Icon(category.icon, size: 26, color: AppColors.primary),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl});

  final String imageUrl;

  static const double _size = 60;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
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
