import 'package:flutter/material.dart';

import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/shared/widgets/app_card.dart';
import 'package:nagarik/shared/widgets/status_badge.dart';

/// A single report's card, used in the home feed (Step 7), the create-report
/// review step, and eventually search results (Step 8).
class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.city,
    required this.pinCode,
    this.onTap,
  });

  final String title;
  final String description;
  final ReportCategory category;
  final ReportStatus status;
  final String city;
  final String pinCode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
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
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text('$city · $pinCode', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
