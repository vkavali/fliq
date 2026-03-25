import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/badge_model.dart';
import '../../../../shared/models/streak_model.dart';
import '../../../../shared/models/tip_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../gamification/data/gamification_repository.dart';
import '../../data/tips_repository.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _customerTipsProvider =
    FutureProvider.autoDispose<List<TipModel>>((ref) async {
  final repo = ref.read(tipsRepositoryProvider);
  final data = await repo.getCustomerTips(limit: 50);
  final tips = (data['tips'] as List)
      .map((e) => TipModel.fromJson(e as Map<String, dynamic>))
      .toList();
  return tips;
});

final _homeStreakProvider =
    FutureProvider.autoDispose<StreakModel>((ref) async {
  final repo = ref.read(gamificationRepositoryProvider);
  return repo.getStreak();
});

final _homeBadgesProvider =
    FutureProvider.autoDispose<List<BadgeModel>>((ref) async {
  final repo = ref.read(gamificationRepositoryProvider);
  return repo.getBadges();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userName = authState.user?.name ?? 'there';
    final tipsAsync = ref.watch(_customerTipsProvider);
    final streakAsync = ref.watch(_homeStreakProvider);
    final badgesAsync = ref.watch(_homeBadgesProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(_customerTipsProvider);
            ref.invalidate(_homeStreakProvider);
            ref.invalidate(_homeBadgesProvider);
            await ref.read(_customerTipsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: AppSpacing.lg),

              // ── Greeting row ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, $userName!',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reward great service',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () => context.push('/search'),
                          icon: const Icon(Icons.search,
                              color: AppColors.primary),
                          tooltip: 'Search providers',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () => context.push('/history'),
                          icon: const Icon(Icons.receipt_long,
                              color: AppColors.primary),
                          tooltip: 'History',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Streak widget ──────────────────────────────────────────
              streakAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (streak) => streak.currentStreak > 0
                    ? _StreakBanner(streak: streak)
                    : const SizedBox.shrink(),
              ),

              // ── Hero card — Scan to Tip ────────────────────────────────
              _HeroScanCard(onTap: () => context.push('/scan')),

              const SizedBox(height: AppSpacing.md),

              // ── Quick stats ────────────────────────────────────────────
              tipsAsync.when(
                loading: () => const _StatsCardShimmer(),
                error: (_, __) => const SizedBox.shrink(),
                data: (tips) => _QuickStatsCard(tips: tips),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Your Badges ──────────────────────────────────────────
              badgesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (badges) {
                  final earned = badges.where((b) => b.earned).toList();
                  if (earned.isEmpty) return const SizedBox.shrink();
                  return _RecentBadges(badges: earned);
                },
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Recent Tips ────────────────────────────────────────────
              tipsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text('Could not load tips',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                data: (tips) {
                  if (tips.isEmpty) {
                    return _EmptyRecentTips();
                  }
                  final recent = tips.take(5).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recent Tips',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          if (tips.length > 5)
                            TextButton(
                              onPressed: () => context.push('/history'),
                              child: const Text('See all'),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...recent.map((tip) => _RecentTipItem(tip: tip)),
                    ],
                  );
                },
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Browse categories ──────────────────────────────────────
              Text('Browse Categories',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.md),
              const _CategoriesGrid(),

              const SizedBox(height: AppSpacing.xl),

              // ── Become a Provider banner ───────────────────────────────
              _BecomeProviderBanner(),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero Scan Card
// ---------------------------------------------------------------------------

class _HeroScanCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroScanCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Text side
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scan to Tip',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          )),
                  const SizedBox(height: 8),
                  Text(
                    'Point your camera at a\nFliq QR code',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                  ),
                ],
              ),
            ),
            // Icon side
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.qr_code_scanner,
                  size: 40, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick Stats Card
// ---------------------------------------------------------------------------

class _QuickStatsCard extends StatelessWidget {
  final List<TipModel> tips;
  const _QuickStatsCard({required this.tips});

  @override
  Widget build(BuildContext context) {
    final paidTips =
        tips.where((t) => t.status == 'PAID' || t.status == 'SETTLED').toList();
    final totalPaise =
        paidTips.fold<int>(0, (sum, t) => sum + t.amountPaise);
    final totalRupees = (totalPaise / 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.volunteer_activism,
              label: 'Tips Given',
              value: '${paidTips.length}',
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.divider),
          Expanded(
            child: _StatItem(
              icon: Icons.currency_rupee,
              label: 'Total',
              value: '\u20B9$totalRupees',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(height: 6),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _StatsCardShimmer extends StatelessWidget {
  const _StatsCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Tip Item
// ---------------------------------------------------------------------------

class _RecentTipItem extends StatelessWidget {
  final TipModel tip;
  const _RecentTipItem({required this.tip});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (tip.status) {
      'SETTLED' => AppColors.success,
      'PAID' => AppColors.warning,
      'FAILED' => AppColors.error,
      _ => Colors.grey,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              (tip.providerName ?? 'P')[0].toUpperCase(),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.providerName ?? 'Provider',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  _timeAgo(tip.createdAt),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\u20B9${tip.amountRupees}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tip.status,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty recent tips
// ---------------------------------------------------------------------------

class _EmptyRecentTips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(Icons.volunteer_activism, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No tips yet',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan a QR code to send your first tip!',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Categories grid
// ---------------------------------------------------------------------------

class _CategoriesGrid extends StatelessWidget {
  const _CategoriesGrid();

  static const _categories = <_CategoryItem>[
    _CategoryItem(Icons.delivery_dining, 'Delivery'),
    _CategoryItem(Icons.content_cut, 'Salon'),
    _CategoryItem(Icons.restaurant, 'Restaurant'),
    _CategoryItem(Icons.hotel, 'Hotel'),
    _CategoryItem(Icons.home_repair_service, 'Household'),
    _CategoryItem(Icons.more_horiz, 'Other'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.1,
      children: _categories
          .map((c) => _CategoryCard(
                icon: c.icon,
                label: c.label,
                onTap: () => context.push('/search', extra: {
                  'category': c.label.toUpperCase(),
                }),
              ))
          .toList(),
    );
  }
}

class _CategoryItem {
  final IconData icon;
  final String label;
  const _CategoryItem(this.icon, this.label);
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _CategoryCard({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Streak Banner
// ---------------------------------------------------------------------------

class _StreakBanner extends StatelessWidget {
  final StreakModel streak;
  const _StreakBanner({required this.streak});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/streak'),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF9F1C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Text('\u{1F525}', style: TextStyle(fontSize: 24)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${streak.currentStreak}-day streak!',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (streak.isAtRisk)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tip today!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Badges
// ---------------------------------------------------------------------------

class _RecentBadges extends StatelessWidget {
  final List<BadgeModel> badges;
  const _RecentBadges({required this.badges});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Show last 6 earned badges
    final recent = badges.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Badges',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/badges'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final badge = recent[index];
              return GestureDetector(
                onTap: () => context.push('/badges'),
                child: Container(
                  width: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(badge.emoji,
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 2),
                      Text(
                        badge.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Become a Provider Banner
// ---------------------------------------------------------------------------

class _BecomeProviderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/onboarding/registration'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront_outlined,
                  color: AppColors.secondary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Are you a service provider?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Register to receive tips from customers',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

String _timeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}
