import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/badge_model.dart';
import '../../../../shared/models/streak_model.dart';
import '../../data/gamification_repository.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _streakProvider =
    FutureProvider.autoDispose<StreakModel>((ref) async {
  final repo = ref.read(gamificationRepositoryProvider);
  return repo.getStreak();
});

final _streakBadgesProvider =
    FutureProvider.autoDispose<List<BadgeModel>>((ref) async {
  final repo = ref.read(gamificationRepositoryProvider);
  final badges = await repo.getBadges();
  return badges.where((b) => b.category == 'STREAK').toList();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(_streakProvider);
    final badgesAsync = ref.watch(_streakBadgesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tip Streak'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(_streakProvider);
          ref.invalidate(_streakBadgesProvider);
          await Future.wait([
            ref.read(_streakProvider.future),
            ref.read(_streakBadgesProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ── Streak counter ─────────────────────────────────────────
            streakAsync.when(
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (streak) => _StreakHero(streak: streak),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Calendar hint ──────────────────────────────────────────
            streakAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (streak) => _StreakCalendar(streak: streak),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Streak badges / milestones ─────────────────────────────
            Text(
              'Streak Milestones',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            badgesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Text('Error: $err'),
              data: (badges) => _MilestonesList(badges: badges),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Streak Hero
// ---------------------------------------------------------------------------

class _StreakHero extends StatelessWidget {
  final StreakModel streak;
  const _StreakHero({required this.streak});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: streak.currentStreak > 0
              ? [const Color(0xFFFF6B35), const Color(0xFFFF9F1C)]
              : [Colors.grey.shade400, Colors.grey.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (streak.currentStreak > 0
                    ? const Color(0xFFFF6B35)
                    : Colors.grey)
                .withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            streak.currentStreak > 0 ? '\u{1F525}' : '\u{1F9CA}',
            style: const TextStyle(fontSize: 56),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${streak.currentStreak}',
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            streak.currentStreak == 1 ? 'day streak' : 'day streak',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StreakStat(
                label: 'Longest',
                value: '${streak.longestStreak} days',
              ),
              const SizedBox(width: AppSpacing.xl),
              _StreakStat(
                label: 'Status',
                value: streak.tippedToday
                    ? 'Tipped today'
                    : streak.isAtRisk
                        ? 'Tip to keep!'
                        : 'Start tipping',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakStat extends StatelessWidget {
  final String label;
  final String value;
  const _StreakStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar (last 14 days)
// ---------------------------------------------------------------------------

class _StreakCalendar extends StatelessWidget {
  final StreakModel streak;
  const _StreakCalendar({required this.streak});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate which days had tips based on streak
    final tipDays = <DateTime>{};
    if (streak.lastTipDate != null && streak.currentStreak > 0) {
      final lastDay = DateTime(
        streak.lastTipDate!.year,
        streak.lastTipDate!.month,
        streak.lastTipDate!.day,
      );
      for (int i = 0; i < streak.currentStreak; i++) {
        tipDays.add(lastDay.subtract(Duration(days: i)));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last 14 Days',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: List.generate(14, (index) {
            final day = today.subtract(Duration(days: 13 - index));
            final hasTip = tipDays.contains(day);
            final isToday = day == today;

            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasTip
                    ? const Color(0xFFFF6B35)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: isToday
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        hasTip ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Milestones List
// ---------------------------------------------------------------------------

class _MilestonesList extends StatelessWidget {
  final List<BadgeModel> badges;
  const _MilestonesList({required this.badges});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: badges.map((badge) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: badge.earned
                ? AppColors.success.withValues(alpha: 0.08)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: badge.earned
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.divider,
            ),
          ),
          child: Row(
            children: [
              Text(
                badge.emoji,
                style: TextStyle(
                  fontSize: 28,
                  color: badge.earned ? null : Colors.grey,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${badge.threshold}-day streak',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge.earned)
                const Icon(Icons.check_circle,
                    color: AppColors.success, size: 24)
              else
                Icon(Icons.circle_outlined,
                    color: Colors.grey.shade300, size: 24),
            ],
          ),
        );
      }).toList(),
    );
  }
}
