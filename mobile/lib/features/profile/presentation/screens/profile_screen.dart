import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/auth/presentation/providers/auth_providers.dart';
import 'package:nagarik/features/profile/presentation/providers/profile_providers.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_card.dart';
import 'package:nagarik/shared/widgets/app_button.dart';
import 'package:nagarik/shared/widgets/empty_view.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/loading_view.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';

/// Profile tab. Branches on real auth state (Step 3): signed out shows the
/// login/signup prompt built in Step 2; signed in fetches and shows the
/// user's real profile from the backend (Step 4), with loading/error
/// handling and a "Log out" action.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: const PrimaryAppBar(title: 'Profile'),
      body: user == null ? const _SignedOutView() : const _SignedInView(),
    );
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_outlined, size: 64),
            const SizedBox(height: AppSpacing.md),
            Text("You're not logged in", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Log in to submit reports and track their status.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: 'Log in', onPressed: () => context.push('/login')),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Create account',
              variant: AppButtonVariant.outlined,
              onPressed: () => context.push('/signup'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInView extends ConsumerWidget {
  const _SignedInView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return profileAsync.when(
      loading: () => const LoadingView(message: 'Loading your profile…'),
      error: (error, stackTrace) => ErrorView(
        message: 'Could not load your profile. Please try again.',
        onRetry: () => ref.invalidate(currentUserProfileProvider),
      ),
      data: (profile) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                child: Text(
                  profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : '?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.displayName, style: Theme.of(context).textTheme.titleMedium),
                    if (profile.email != null)
                      Text(profile.email!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Text('Your reports', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const _MyReports(),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Log out',
            variant: AppButtonVariant.outlined,
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }
}

/// The signed-in user's own report history (Step 7). A small, self-
/// contained `ConsumerWidget` rather than inlining `ref.watch` into
/// `_SignedInView`'s `ListView` — its own loading/error/empty/data states
/// don't have to fight with the profile header around it for layout.
class _MyReports extends ConsumerWidget {
  const _MyReports();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myReportsAsync = ref.watch(myReportsProvider);

    return myReportsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: LoadingView(),
      ),
      error: (error, stackTrace) => ErrorView(
        message: 'Could not load your reports.',
        onRetry: () => ref.invalidate(myReportsProvider),
      ),
      data: (page) => page.items.isEmpty
          ? const EmptyView(
              icon: Icons.history_outlined,
              title: 'No reports yet',
              message: 'Reports you submit will show up here with their status.',
            )
          : Column(
              children: [
                for (final report in page.items) ...[
                  ReportCard(
                    title: report.category.label,
                    description: report.description,
                    category: report.category,
                    status: report.status,
                    city: report.city,
                    pinCode: report.pinCode,
                    onTap: () => context.push('/report/${report.id}'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
    );
  }
}
