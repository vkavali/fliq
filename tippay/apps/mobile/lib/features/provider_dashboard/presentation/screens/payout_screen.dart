import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/provider_repository.dart';

final payoutHistoryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.read(providerRepositoryProvider);
  return repo.getPayoutHistory();
});

// Fetch tips to compute available balance
final _payoutBalanceProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.read(providerRepositoryProvider);
  final tipsData = await repo.getProviderTips(limit: 100);
  final tips = (tipsData['tips'] as List?) ?? [];

  int totalEarned = 0;
  for (final t in tips) {
    final tip = t as Map<String, dynamic>;
    totalEarned += (tip['netAmountPaise'] as int? ?? 0);
  }

  final payoutData = await repo.getPayoutHistory();
  final payouts = (payoutData['payouts'] as List?) ?? [];

  int totalPaidOut = 0;
  for (final p in payouts) {
    final payout = p as Map<String, dynamic>;
    final status = payout['status'] as String? ?? '';
    if (status == 'SETTLED' || status == 'PROCESSED' || status == 'PENDING') {
      totalPaidOut += (payout['amountPaise'] as int? ?? 0);
    }
  }

  return totalEarned - totalPaidOut;
});

class PayoutScreen extends ConsumerStatefulWidget {
  const PayoutScreen({super.key});

  @override
  ConsumerState<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends ConsumerState<PayoutScreen> {
  final _amountController = TextEditingController();
  String _selectedMode = 'UPI';
  bool _isRequesting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _requestPayout() async {
    final rupees = int.tryParse(_amountController.text);
    if (rupees == null || rupees < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum payout is \u20B9100')),
      );
      return;
    }

    setState(() => _isRequesting = true);
    try {
      final repo = ref.read(providerRepositoryProvider);
      await repo.requestPayout(
        amountPaise: rupees * 100,
        mode: _selectedMode,
      );
      _amountController.clear();
      ref.invalidate(payoutHistoryProvider);
      ref.invalidate(_payoutBalanceProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payout requested successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(payoutHistoryProvider);
    final balanceAsync = ref.watch(_payoutBalanceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Payouts')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(payoutHistoryProvider);
          ref.invalidate(_payoutBalanceProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Available balance card
              Container(
                width: double.infinity,
                margin: AppSpacing.paddingMd,
                padding: AppSpacing.paddingLg,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4CAF50),
                      Color(0xFF66BB6A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Balance',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    balanceAsync.when(
                      loading: () => const SizedBox(
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      error: (_, __) => const Text(
                        '--',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      data: (balance) => Text(
                        '\u20B9${(balance / 100).toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Min. payout: \u20B9${AppConstants.minPayoutPaise ~/ 100}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Request payout card
              Card(
                margin: AppSpacing.paddingMd,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Request Payout',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          prefixText: '\u20B9 ',
                          prefixStyle: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          hintText: '0',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Mode selector
                      Text(
                        'Payout Mode',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: AppConstants.payoutModes.map((mode) {
                          final isSelected = mode == _selectedMode;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: mode != AppConstants.payoutModes.last
                                    ? 8
                                    : 0,
                              ),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedMode = mode),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSelected
                                        ? null
                                        : Border.all(
                                            color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    mode,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: AppSpacing.lg),
                      ElevatedButton(
                        onPressed: _isRequesting ? null : _requestPayout,
                        child: _isRequesting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Request Payout'),
                      ),
                    ],
                  ),
                ),
              ),

              // Payout history
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                child: Text(
                  'Payout History',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              historyAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Padding(
                  padding: AppSpacing.paddingMd,
                  child: Center(child: Text('Error: $err')),
                ),
                data: (data) {
                  final payouts = (data['payouts'] as List?) ?? [];
                  if (payouts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.account_balance,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'No payouts yet',
                              style:
                                  TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: AppSpacing.paddingMd,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: payouts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return _PayoutHistoryTile(
                        payout: payouts[index] as Map<String, dynamic>,
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayoutHistoryTile extends StatelessWidget {
  final Map<String, dynamic> payout;

  const _PayoutHistoryTile({required this.payout});

  @override
  Widget build(BuildContext context) {
    final amount = payout['amountPaise'] as int? ?? 0;
    final status = payout['status'] as String? ?? 'UNKNOWN';
    final mode = payout['mode'] as String? ?? '';
    final createdAt =
        DateTime.tryParse(payout['createdAt'] as String? ?? '');
    final dateFormat = DateFormat('MMM d, y \u2022 h:mm a');

    final statusColor = switch (status) {
      'SETTLED' || 'PROCESSED' => AppColors.success,
      'FAILED' => AppColors.error,
      'PENDING' => AppColors.warning,
      _ => AppColors.textSecondary,
    };

    final statusIcon = switch (status) {
      'SETTLED' || 'PROCESSED' => Icons.check_circle,
      'FAILED' => Icons.cancel,
      'PENDING' => Icons.schedule,
      _ => Icons.help_outline,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u20B9${(amount / 100).toStringAsFixed(0)}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${createdAt != null ? dateFormat.format(createdAt) : ''}'
                  '${mode.isNotEmpty ? ' \u2022 $mode' : ''}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
