import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/tip_model.dart';
import '../../data/tips_repository.dart';

final customerTipsProvider = FutureProvider.autoDispose<List<TipModel>>((ref) async {
  final repo = ref.read(tipsRepositoryProvider);
  final data = await repo.getCustomerTips();
  final tips = (data['tips'] as List)
      .map((e) => TipModel.fromJson(e as Map<String, dynamic>))
      .toList();
  return tips;
});

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipsAsync = ref.watch(customerTipsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tip History')),
      body: tipsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (tips) {
          if (tips.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  SizedBox(height: AppSpacing.md),
                  Text('No tips yet', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: AppSpacing.paddingMd,
            itemCount: tips.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tip = tips[index];
              return _TipTile(tip: tip);
            },
          );
        },
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  final TipModel tip;

  const _TipTile({required this.tip});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    final statusColor = switch (tip.status) {
      'PAID' || 'SETTLED' => Colors.green,
      'FAILED' => Colors.red,
      _ => Colors.orange,
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: const Icon(Icons.volunteer_activism, size: 20),
      ),
      title: Text(
        tip.providerName ?? 'Provider',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        dateFormat.format(tip.createdAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '\u20B9${tip.amountRupees}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tip.status,
              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
