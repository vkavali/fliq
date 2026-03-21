import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/provider_repository.dart';

final payoutHistoryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.read(providerRepositoryProvider);
  return repo.getPayoutHistory();
});

class PayoutScreen extends ConsumerStatefulWidget {
  const PayoutScreen({super.key});

  @override
  ConsumerState<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends ConsumerState<PayoutScreen> {
  final _amountController = TextEditingController();
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
      await repo.requestPayout(amountPaise: rupees * 100);
      _amountController.clear();
      ref.invalidate(payoutHistoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payout requested successfully!')),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Payouts')),
      body: Column(
        children: [
          // Request payout card
          Card(
            margin: AppSpacing.paddingMd,
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Request Payout',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixText: '\u20B9 ',
                      hintText: 'Enter amount (min \u20B9100)',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: _isRequesting ? null : _requestPayout,
                    child: _isRequesting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Request Payout'),
                  ),
                ],
              ),
            ),
          ),

          // History
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('History',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
            ),
          ),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (data) {
                final payouts = (data['payouts'] as List?) ?? [];
                if (payouts.isEmpty) {
                  return const Center(
                    child: Text('No payouts yet', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.separated(
                  padding: AppSpacing.paddingMd,
                  itemCount: payouts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = payouts[index] as Map<String, dynamic>;
                    final amount = p['amountPaise'] as int? ?? 0;
                    final status = p['status'] as String? ?? 'UNKNOWN';
                    final createdAt = DateTime.tryParse(p['createdAt'] as String? ?? '');
                    final dateFormat = DateFormat('MMM d, y');

                    final statusColor = switch (status) {
                      'SETTLED' || 'PROCESSED' => Colors.green,
                      'FAILED' => Colors.red,
                      _ => Colors.orange,
                    };

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: Icon(
                        Icons.account_balance,
                        color: statusColor,
                      ),
                      title: Text('\u20B9${(amount / 100).toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        createdAt != null ? dateFormat.format(createdAt) : '',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
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
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
