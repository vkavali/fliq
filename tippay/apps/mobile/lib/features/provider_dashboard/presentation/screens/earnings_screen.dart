import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/tip_model.dart';
import '../../data/provider_repository.dart';

final providerTipsProvider =
    FutureProvider.autoDispose<List<TipModel>>((ref) async {
  final repo = ref.read(providerRepositoryProvider);
  final data = await repo.getProviderTips();
  return (data['tips'] as List)
      .map((e) => TipModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  DateTimeRange? _dateRange;

  void _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  void _clearFilter() {
    setState(() => _dateRange = null);
  }

  List<TipModel> _filterTips(List<TipModel> tips) {
    if (_dateRange == null) return tips;
    return tips.where((t) {
      return t.createdAt.isAfter(_dateRange!.start) &&
          t.createdAt.isBefore(_dateRange!.end.add(const Duration(days: 1)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tipsAsync = ref.watch(providerTipsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        actions: [
          IconButton(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range),
            tooltip: 'Filter by date',
          ),
          if (_dateRange != null)
            IconButton(
              onPressed: _clearFilter,
              icon: const Icon(Icons.clear),
              tooltip: 'Clear filter',
            ),
        ],
      ),
      body: tipsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text('Error: $err', textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => ref.invalidate(providerTipsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (allTips) {
          final tips = _filterTips(allTips);

          if (allTips.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet,
                      size: 64, color: AppColors.divider),
                  SizedBox(height: AppSpacing.md),
                  Text('No tips received yet',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          // Calculate totals for filtered tips
          int totalAmount = 0;
          int totalCommission = 0;
          int totalNet = 0;
          for (final tip in tips) {
            totalAmount += tip.amountPaise;
            totalNet += tip.netAmountPaise;
            totalCommission += (tip.amountPaise - tip.netAmountPaise);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(providerTipsProvider);
            },
            child: Column(
              children: [
                // Date range indicator
                if (_dateRange != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    color: AppColors.primary.withValues(alpha: 0.05),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${tips.length} tips',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Summary card
                Container(
                  width: double.infinity,
                  margin: AppSpacing.paddingMd,
                  padding: AppSpacing.paddingLg,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryItem(
                              label: 'Total Earnings',
                              value:
                                  '\u20B9${(totalAmount / 100).toStringAsFixed(0)}',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          Expanded(
                            child: _SummaryItem(
                              label: 'Commission',
                              value:
                                  '\u20B9${(totalCommission / 100).toStringAsFixed(0)}',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          Expanded(
                            child: _SummaryItem(
                              label: 'Net Earnings',
                              value:
                                  '\u20B9${(totalNet / 100).toStringAsFixed(0)}',
                              isBold: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tips list
                Expanded(
                  child: tips.isEmpty
                      ? Center(
                          child: Text(
                            'No tips in selected range',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: AppSpacing.paddingMd,
                          itemCount: tips.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return _EarningsTipTile(tip: tips[index]);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _SummaryItem({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: isBold ? 20 : 18,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _EarningsTipTile extends StatelessWidget {
  final TipModel tip;

  const _EarningsTipTile({required this.tip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, h:mm a');
    final commission = tip.amountPaise - tip.netAmountPaise;

    final statusColor = switch (tip.status) {
      'PAID' || 'SETTLED' => AppColors.success,
      'FAILED' => AppColors.error,
      _ => AppColors.warning,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  (tip.customerName ?? '?').isNotEmpty
                      ? (tip.customerName ?? '?')[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.customerName ?? 'Anonymous',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      dateFormat.format(tip.createdAt),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\u20B9${tip.amountRupees}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tip.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Commission and net row
          Row(
            children: [
              _DetailChip(
                label: 'Commission',
                value: '\u20B9${(commission / 100).toStringAsFixed(0)}',
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              _DetailChip(
                label: 'Net',
                value:
                    '\u20B9${(tip.netAmountPaise / 100).toStringAsFixed(0)}',
                color: AppColors.success,
              ),
              const Spacer(),
              if (tip.rating != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    return Icon(
                      i < tip.rating! ? Icons.star : Icons.star_border,
                      size: 14,
                      color: Colors.amber,
                    );
                  }),
                ),
            ],
          ),
          if (tip.message != null && tip.message!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.format_quote,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tip.message!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
