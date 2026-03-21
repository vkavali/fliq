import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/tip_model.dart';
import '../../data/provider_repository.dart';

final providerTipsProvider = FutureProvider.autoDispose<List<TipModel>>((ref) async {
  final repo = ref.read(providerRepositoryProvider);
  final data = await repo.getProviderTips();
  return (data['tips'] as List)
      .map((e) => TipModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipsAsync = ref.watch(providerTipsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: tipsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (tips) {
          if (tips.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey),
                  SizedBox(height: AppSpacing.md),
                  Text('No tips received yet', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Calculate totals
          int totalAmount = 0;
          int totalNet = 0;
          for (final tip in tips) {
            totalAmount += tip.amountPaise;
            totalNet += tip.netAmountPaise;
          }

          return Column(
            children: [
              // Summary card
              Container(
                width: double.infinity,
                padding: AppSpacing.paddingLg,
                margin: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text('Total Earnings', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(
                      '\u20B9${(totalNet / 100).toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tips.length} tips received',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Tips list
              Expanded(
                child: ListView.separated(
                  padding: AppSpacing.paddingMd,
                  itemCount: tips.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final tip = tips[index];
                    final dateFormat = DateFormat('MMM d, h:mm a');
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        child: Text(
                          tip.customerName?.isNotEmpty == true
                              ? tip.customerName![0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      title: Text(tip.customerName ?? 'Anonymous'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateFormat.format(tip.createdAt),
                              style: const TextStyle(fontSize: 12)),
                          if (tip.message != null)
                            Text(tip.message!,
                                style: const TextStyle(
                                    fontSize: 12, fontStyle: FontStyle.italic)),
                          if (tip.rating != null)
                            Row(
                              children: List.generate(5, (i) => Icon(
                                i < tip.rating! ? Icons.star : Icons.star_border,
                                size: 14,
                                color: Colors.amber,
                              )),
                            ),
                        ],
                      ),
                      trailing: Text(
                        '\u20B9${tip.amountRupees}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
