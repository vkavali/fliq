import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/recurring_tips_repository.dart';
import '../providers/recurring_tips_provider.dart';

class MyRecurringTipsScreen extends ConsumerStatefulWidget {
  const MyRecurringTipsScreen({super.key});

  @override
  ConsumerState<MyRecurringTipsScreen> createState() =>
      _MyRecurringTipsScreenState();
}

class _MyRecurringTipsScreenState
    extends ConsumerState<MyRecurringTipsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(recurringTipsProvider.notifier).loadMyTips());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recurringTipsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Recurring Tips')),
      body: Builder(
        builder: (_) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      color: AppColors.error, size: 40),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Failed to load recurring tips'),
                  TextButton(
                    onPressed: () =>
                        ref.read(recurringTipsProvider.notifier).loadMyTips(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (state.tips.isEmpty) {
            return _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(recurringTipsProvider.notifier).loadMyTips(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: state.tips.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final tip = state.tips[index];
                return _RecurringTipCard(
                  tip: tip,
                  onTap: () => context.push(
                    '/recurring-tips/${tip.id}',
                    extra: tip,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.autorenew_rounded,
                size: 64, color: AppColors.divider),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No recurring tips yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Set up a monthly or weekly auto-tip after paying a service provider.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _RecurringTipCard extends StatelessWidget {
  final RecurringTip tip;
  final VoidCallback onTap;

  const _RecurringTipCard({required this.tip, required this.onTap});

  Color get _statusColor {
    switch (tip.status) {
      case RecurringTipStatus.active:
        return AppColors.success;
      case RecurringTipStatus.paused:
        return Colors.orange;
      case RecurringTipStatus.pendingAuthorization:
        return Colors.blue;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rupees = '₹${(tip.amountPaise / 100).toStringAsFixed(0)}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.autorenew_rounded,
                    color: AppColors.primary, size: 24),
              ),

              const SizedBox(width: AppSpacing.md),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.providerName ?? 'Service Provider',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$rupees / ${tip.frequencyLabel.toLowerCase()}',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tip.statusLabel,
                          style: TextStyle(
                              color: _statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                        if (tip.totalCharges > 0) ...[
                          Text(' · ', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text(
                            '${tip.totalCharges} paid',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
