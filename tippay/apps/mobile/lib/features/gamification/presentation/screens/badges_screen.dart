import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/badge_model.dart';
import '../../data/gamification_repository.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _badgesProvider =
    FutureProvider.autoDispose<List<BadgeModel>>((ref) async {
  final repo = ref.read(gamificationRepositoryProvider);
  return repo.getBadges();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(_badgesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Badges'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(_badgesProvider);
          await ref.read(_badgesProvider.future);
        },
        child: badgesAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.error),
                const SizedBox(height: AppSpacing.sm),
                Text('Could not load badges: $err'),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: () => ref.invalidate(_badgesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (badges) => _BadgesGrid(badges: badges),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid
// ---------------------------------------------------------------------------

class _BadgesGrid extends StatelessWidget {
  final List<BadgeModel> badges;
  const _BadgesGrid({required this.badges});

  @override
  Widget build(BuildContext context) {
    final earned = badges.where((b) => b.earned).toList();
    final unearned = badges.where((b) => !b.earned).toList();
    final sorted = [...earned, ...unearned];

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.8,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final badge = sorted[index];
        return _BadgeCard(badge: badge);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Badge Card
// ---------------------------------------------------------------------------

class _BadgeCard extends StatelessWidget {
  final BadgeModel badge;
  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _showBadgeDetails(context, badge),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: badge.earned ? 1.0 : 0.4,
        child: Container(
          decoration: BoxDecoration(
            color: badge.earned
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: badge.earned
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.divider,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                badge.emoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(
                  badge.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: badge.earned
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              if (badge.earned && badge.earnedAt != null) ...[
                const SizedBox(height: 2),
                Text(
                  _formatDate(badge.earnedAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ---------------------------------------------------------------------------
// Badge Details Modal
// ---------------------------------------------------------------------------

void _showBadgeDetails(BuildContext context, BadgeModel badge) {
  final theme = Theme.of(context);

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              badge.emoji,
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              badge.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: badge.earned
                    ? AppColors.success.withValues(alpha: 0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge.earned
                    ? 'Earned on ${_BadgeCard._formatDate(badge.earnedAt!)}'
                    : 'Not yet earned',
                style: TextStyle(
                  color: badge.earned
                      ? AppColors.success
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Category: ${badge.category}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      );
    },
  );
}
