import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';

/// A pulsing placeholder block (UI Polish upgrade) — the app's
/// dependency-free stand-in for a `shimmer` package, in keeping with the
/// project's standing "avoid unnecessary packages" precedent. Used to shape
/// a loading state like the real content it's about to become, instead of
/// a plain spinner.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.borderRadius});

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.45,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.darkBorder : AppColors.border;
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }
}

/// Mimics [ReportCard]'s layout (shared/widgets/../reports/.../report_card.dart)
/// while a report list is loading, so the loading state already hints at
/// the shape of what's coming rather than a generic blank spinner.
class SkeletonReportCard extends StatelessWidget {
  const SkeletonReportCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 56, height: 56, borderRadius: BorderRadius.circular(AppRadius.sm)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 140, height: 16),
                const SizedBox(height: AppSpacing.sm),
                const SkeletonBox(height: 12),
                const SizedBox(height: AppSpacing.xs),
                const SkeletonBox(width: 200, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A vertical stack of [SkeletonReportCard]s, for a report list that's
/// loading (My Reports, Search results, Home's Recent Reports).
class SkeletonReportList extends StatelessWidget {
  const SkeletonReportList({super.key, this.count = 3, this.padding});

  final int count;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => const SkeletonReportCard(),
    );
  }
}

/// A horizontal row of [SkeletonReportCard]s, for the Home feed's "Nearby
/// Issues" strip while it loads.
class SkeletonReportRow extends StatelessWidget {
  const SkeletonReportRow({super.key, this.count = 2, this.itemWidth = 280});

  final int count;
  final double itemWidth;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: count,
      separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
      itemBuilder: (context, index) => SizedBox(width: itemWidth, child: const SkeletonReportCard()),
    );
  }
}

/// Mimics the Profile screen's 4-up stats strip while `GET /reports/stats`
/// is loading.
class SkeletonStatsStrip extends StatelessWidget {
  const SkeletonStatsStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i != 0) const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SkeletonBox(width: 32, height: 22),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(height: 10),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
