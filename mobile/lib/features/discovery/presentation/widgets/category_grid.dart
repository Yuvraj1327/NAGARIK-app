import 'package:flutter/material.dart';

import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
import 'package:nagarik/shared/widgets/app_card.dart';

/// Home's "Explore by Category" shortcuts — one tile per
/// [ReportCategory.values] (Roads, Streetlights, Sanitation, Water,
/// Electricity, Safety, Other), reusing that enum's existing `label`/`icon`
/// rather than a second, parallel list. Purely a navigation shortcut: no
/// new business logic, each tile just opens Search pre-filtered to its
/// category ([onCategoryTap]).
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, required this.onCategoryTap});

  final ValueChanged<ReportCategory> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.0,
      children: [
        for (final (index, category) in ReportCategory.values.indexed)
          FadeSlideIn(
            delay: Duration(milliseconds: 25 * index),
            child: _CategoryTile(category: category, onTap: () => onCategoryTap(category)),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final ReportCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imagePath = category.imagePath;

    // NAGARIK Theme upgrade: the uploaded category photo fills the top of
    // the tile via `Expanded` + `BoxFit.cover` — this fits whatever height
    // the grid cell gives it with no distortion (the source aspect ratio is
    // always preserved, excess is cropped rather than stretched) and every
    // tile stays the same consistent size regardless of category. `other`
    // has no supplied photo, so it falls back to its existing icon on a
    // tinted surface rather than leaving a blank tile.
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: imagePath != null
                ? Image.asset(imagePath, width: double.infinity, fit: BoxFit.cover)
                : Container(
                    width: double.infinity,
                    color: AppColors.primaryLight,
                    alignment: Alignment.center,
                    child: Icon(category.icon, size: 26, color: AppColors.primary),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: AppSpacing.xs),
            child: Text(
              category.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
