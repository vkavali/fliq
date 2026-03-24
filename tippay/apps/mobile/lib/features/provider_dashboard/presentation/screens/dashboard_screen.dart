import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/badge_model.dart';
import '../../../../shared/models/tip_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../gamification/data/gamification_repository.dart';
import '../../data/provider_repository.dart';

enum _EarningsPeriod { today, week, month }

final _providerBadgesProvider =
    FutureProvider.autoDispose<List<BadgeModel>>((ref) async {
  final repo = ref.read(gamificationRepositoryProvider);
  return repo.getBadges();
});

final dashboardDataProvider =
    FutureProvider.autoDispose<_DashboardData>((ref) async {
  final repo = ref.read(providerRepositoryProvider);
  final data = await repo.getProviderTips(limit: 20);
  final allTips = ((data['tips'] as List?) ?? [])
      .map((e) => TipModel.fromJson(e as Map<String, dynamic>))
      .toList();
  final total = data['total'] as int? ?? 0;

  // Get payout data for wallet balance
  final payoutData = await repo.getPayoutHistory();
  final payouts = (payoutData['payouts'] as List?) ?? [];

  int totalEarned = 0;
  int totalPaidOut = 0;
  int todayEarnings = 0;
  int weekEarnings = 0;
  int monthEarnings = 0;
  double ratingSum = 0;
  int ratingCount = 0;

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
  final monthStart = DateTime(now.year, now.month, 1);

  for (final tip in allTips) {
    totalEarned += tip.netAmountPaise;
    if (tip.createdAt.isAfter(todayStart)) {
      todayEarnings += tip.netAmountPaise;
    }
    if (tip.createdAt.isAfter(weekStart)) {
      weekEarnings += tip.netAmountPaise;
    }
    if (tip.createdAt.isAfter(monthStart)) {
      monthEarnings += tip.netAmountPaise;
    }
    if (tip.rating != null) {
      ratingSum += tip.rating!;
      ratingCount++;
    }
  }

  for (final p in payouts) {
    final payout = p as Map<String, dynamic>;
    final status = payout['status'] as String? ?? '';
    if (status == 'SETTLED' || status == 'PROCESSED') {
      totalPaidOut += (payout['amountPaise'] as int? ?? 0);
    }
  }

  return _DashboardData(
    tips: allTips,
    totalTips: total,
    walletBalance: totalEarned - totalPaidOut,
    todayEarnings: todayEarnings,
    weekEarnings: weekEarnings,
    monthEarnings: monthEarnings,
    avgRating: ratingCount > 0 ? ratingSum / ratingCount : 0,
    ratingCount: ratingCount,
  );
});

class _DashboardData {
  final List<TipModel> tips;
  final int totalTips;
  final int walletBalance;
  final int todayEarnings;
  final int weekEarnings;
  final int monthEarnings;
  final double avgRating;
  final int ratingCount;

  _DashboardData({
    required this.tips,
    required this.totalTips,
    required this.walletBalance,
    required this.todayEarnings,
    required this.weekEarnings,
    required this.monthEarnings,
    required this.avgRating,
    required this.ratingCount,
  });

  int earningsFor(_EarningsPeriod period) {
    return switch (period) {
      _EarningsPeriod.today => todayEarnings,
      _EarningsPeriod.week => weekEarnings,
      _EarningsPeriod.month => monthEarnings,
    };
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  _EarningsPeriod _selectedPeriod = _EarningsPeriod.today;

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final dashAsync = ref.watch(dashboardDataProvider);
    final userName = authState.user?.name ?? 'Provider';
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardDataProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.horizontalLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),

                // Header
                Text(
                  'Hi, $userName!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here\'s your overview',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                dashAsync.when(
                  loading: () => const SizedBox(
                    height: 400,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: AppColors.error),
                          const SizedBox(height: AppSpacing.md),
                          Text('Error: $err',
                              textAlign: TextAlign.center),
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton(
                            onPressed: () =>
                                ref.invalidate(dashboardDataProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (data) => _buildDashboardContent(context, data),
                ),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, _DashboardData data) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wallet balance card
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF6C63FF),
                Color(0xFF8B83FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Balance',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance_wallet,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Wallet',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '\u20B9${(data.walletBalance / 100).toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${data.totalTips} total tips received',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Earnings period toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Earnings',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: _EarningsPeriod.values.map((period) {
              final isSelected = period == _selectedPeriod;
              final label = switch (period) {
                _EarningsPeriod.today => 'Today',
                _EarningsPeriod.week => 'This Week',
                _EarningsPeriod.month => 'This Month',
              };
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPeriod = period),
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
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_up,
                    color: AppColors.success, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u20B9${(data.earningsFor(_selectedPeriod) / 100).toStringAsFixed(0)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  Text(
                    switch (_selectedPeriod) {
                      _EarningsPeriod.today => 'earned today',
                      _EarningsPeriod.week => 'earned this week',
                      _EarningsPeriod.month => 'earned this month',
                    },
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Rating display
        if (data.ratingCount > 0) ...[
          Container(
            width: double.infinity,
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                ...List.generate(5, (i) {
                  final filled = i < data.avgRating.round();
                  return Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 24,
                  );
                }),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  data.avgRating.toStringAsFixed(1),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '(${data.ratingCount} ratings)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Quick actions
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.qr_code,
                label: 'Generate QR',
                color: AppColors.primary,
                onTap: () => context.go('/my-qr'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.account_balance,
                label: 'Request Payout',
                color: AppColors.success,
                onTap: () => context.go('/payouts'),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // Tip Pools button
        _QuickActionButton(
          icon: Icons.groups,
          label: 'Tip Pools',
          color: const Color(0xFF9C27B0),
          onTap: () => context.push('/tip-pools'),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Share via WhatsApp button
        _ShareWhatsAppButton(ref: ref),

        const SizedBox(height: AppSpacing.lg),

        // Provider Badges
        _ProviderBadgesSection(),

        const SizedBox(height: AppSpacing.lg),

        // Recent tips
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Tips',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => context.go('/earnings'),
              child: const Text('See All'),
            ),
          ],
        ),

        if (data.tips.isEmpty)
          Container(
            width: double.infinity,
            padding: AppSpacing.paddingLg,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.volunteer_activism,
                    size: 40, color: Colors.grey.shade400),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'No tips yet',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        else
          ...data.tips.take(5).map((tip) => _RecentTipTile(
                tip: tip,
                timeAgo: _timeAgo(tip.createdAt),
              )),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTipTile extends StatelessWidget {
  final TipModel tip;
  final String timeAgo;

  const _RecentTipTile({required this.tip, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                (tip.customerName ?? '?').isNotEmpty
                    ? (tip.customerName ?? '?')[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.customerName ?? 'Anonymous',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        timeAgo,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (tip.rating != null) ...[
                        const SizedBox(width: 8),
                        ...List.generate(
                          tip.rating!.clamp(0, 5),
                          (_) => const Icon(Icons.star,
                              size: 12, color: Colors.amber),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '\u20B9${tip.amountRupees}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareWhatsAppButton extends StatefulWidget {
  final WidgetRef ref;

  const _ShareWhatsAppButton({required this.ref});

  @override
  State<_ShareWhatsAppButton> createState() => _ShareWhatsAppButtonState();
}

class _ShareWhatsAppButtonState extends State<_ShareWhatsAppButton> {
  bool _isLoading = false;

  Future<void> _shareViaWhatsApp() async {
    setState(() => _isLoading = true);

    try {
      final repo = widget.ref.read(providerRepositoryProvider);
      final result = await repo.createPaymentLink();
      final shareableUrl = result['shareableUrl'] as String?;

      if (shareableUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create tip link')),
          );
        }
        return;
      }

      final message = Uri.encodeComponent(
        'Tip me on Fliq! $shareableUrl',
      );
      final whatsappUrl = Uri.parse('whatsapp://send?text=$message');

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: open web WhatsApp
        final webUrl = Uri.parse('https://wa.me/?text=$message');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF25D366).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _isLoading ? null : _shareViaWhatsApp,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF25D366),
                  ),
                )
              else
                const Icon(Icons.share, color: Color(0xFF25D366), size: 22),
              const SizedBox(width: 10),
              Text(
                _isLoading ? 'Creating link...' : 'Share Tip Link via WhatsApp',
                style: const TextStyle(
                  color: Color(0xFF25D366),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider Badges Section
// ---------------------------------------------------------------------------

class _ProviderBadgesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(_providerBadgesProvider);
    final theme = Theme.of(context);

    return badgesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (badges) {
        final earned = badges.where((b) => b.earned).toList();
        if (earned.isEmpty) return const SizedBox.shrink();

        final recent = earned.take(4).toList();
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
            Row(
              children: recent.map((badge) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('/badges'),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(badge.emoji,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(
                            badge.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
