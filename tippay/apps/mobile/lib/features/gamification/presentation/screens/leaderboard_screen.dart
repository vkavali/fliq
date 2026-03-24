import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/gamification_repository.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

final _leaderboardTypeProvider = StateProvider<String>((ref) => 'tippers');
final _leaderboardPeriodProvider = StateProvider<String>((ref) => 'week');

final _leaderboardProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final type = ref.watch(_leaderboardTypeProvider);
  final period = ref.watch(_leaderboardPeriodProvider);
  final repo = ref.read(gamificationRepositoryProvider);
  return repo.getLeaderboard(type: type, period: period);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(_leaderboardTypeProvider);
    final period = ref.watch(_leaderboardPeriodProvider);
    final dataAsync = ref.watch(_leaderboardProvider);
    final currentUserId = ref.watch(authProvider).user?.id;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
      ),
      body: Column(
        children: [
          // ── Type toggle ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _ToggleButton(
                    label: 'Tippers',
                    isSelected: type == 'tippers',
                    onTap: () => ref
                        .read(_leaderboardTypeProvider.notifier)
                        .state = 'tippers',
                  ),
                  _ToggleButton(
                    label: 'Providers',
                    isSelected: type == 'providers',
                    onTap: () => ref
                        .read(_leaderboardTypeProvider.notifier)
                        .state = 'providers',
                  ),
                ],
              ),
            ),
          ),

          // ── Period toggle ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _ToggleButton(
                    label: 'This Week',
                    isSelected: period == 'week',
                    onTap: () => ref
                        .read(_leaderboardPeriodProvider.notifier)
                        .state = 'week',
                  ),
                  _ToggleButton(
                    label: 'This Month',
                    isSelected: period == 'month',
                    onTap: () => ref
                        .read(_leaderboardPeriodProvider.notifier)
                        .state = 'month',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── List ─────────────────────────────────────────────────────
          Expanded(
            child: dataAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error: $err'),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'No data yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(_leaderboardProvider);
                    await ref.read(_leaderboardProvider.future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final rank = entry['rank'] as int? ?? index + 1;
                      final name = entry['name'] as String? ?? 'Unknown';
                      final userId = entry['userId'] as String?;
                      final tipCount =
                          (entry['tipCount'] as num?)?.toInt() ?? 0;
                      final amountPaise = type == 'tippers'
                          ? (entry['totalAmountPaise'] as num?)
                                  ?.toInt() ??
                              0
                          : (entry['totalEarnedPaise'] as num?)
                                  ?.toInt() ??
                              0;
                      final isCurrentUser =
                          currentUserId != null && userId == currentUserId;

                      return _LeaderboardTile(
                        rank: rank,
                        name: name,
                        tipCount: tipCount,
                        amountPaise: amountPaise,
                        isCurrentUser: isCurrentUser,
                        isTipper: type == 'tippers',
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toggle Button
// ---------------------------------------------------------------------------

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leaderboard Tile
// ---------------------------------------------------------------------------

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final String name;
  final int tipCount;
  final int amountPaise;
  final bool isCurrentUser;
  final bool isTipper;

  const _LeaderboardTile({
    required this.rank,
    required this.name,
    required this.tipCount,
    required this.amountPaise,
    required this.isCurrentUser,
    required this.isTipper,
  });

  Color? get _rankColor {
    return switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => null,
    };
  }

  IconData get _rankIcon {
    return switch (rank) {
      1 => Icons.emoji_events,
      2 => Icons.emoji_events,
      3 => Icons.emoji_events,
      _ => Icons.person,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountRupees = (amountPaise / 100).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.divider,
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 36,
            child: rank <= 3
                ? Icon(_rankIcon, color: _rankColor, size: 28)
                : Text(
                    '#$rank',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: (rank <= 3
                    ? _rankColor
                    : AppColors.primary)
                ?.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: rank <= 3 ? _rankColor : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Name + tip count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$tipCount tips',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Amount
          Text(
            '\u20B9$amountRupees',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
